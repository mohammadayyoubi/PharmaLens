package com.codepeakstudio.pharmalens

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The tone medicine alarms ring with (channel "pharmalens/alarm_sound"):
 *
 * - pickTone: the phone's own alarm-tone picker.
 * - pickFile: any audio file. It is copied into the shared Alarms folder,
 *   because the notification system plays sounds as another app and cannot
 *   read a file the user only granted to PharmaLens.
 * - play / stop: preview, and the ringing dose screen. An empty uri plays the
 *   PharmaLens tone (res/raw/pharmalens_alarm).
 *
 * Results are {"uri", "title"} maps, or null when the user backs out.
 */
class AlarmSound(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null
    private var player: MediaPlayer? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickTone" -> pickTone(call.argument<String>("current") ?: "", call.argument<String>("title") ?: "", result)
            "pickFile" -> pickFile(result)
            "play" -> {
                play(call.argument<String>("uri") ?: "", call.argument<Boolean>("loop") ?: true)
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pickTone(current: String, title: String, result: MethodChannel.Result) {
        if (!begin(result)) return
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
            if (title.isNotEmpty()) putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, title)
            if (current.isNotEmpty()) putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
        }
        start(intent, PICK_TONE)
    }

    private fun pickFile(result: MethodChannel.Result) {
        if (!begin(result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        start(intent, PICK_FILE)
    }

    private fun begin(result: MethodChannel.Result): Boolean {
        if (pending != null) {
            result.error("busy", "A picker is already open.", null)
            return false
        }
        pending = result
        return true
    }

    private fun start(intent: Intent, requestCode: Int) {
        try {
            activity.startActivityForResult(intent, requestCode)
        } catch (error: Exception) {
            // No picker on this device.
            pending?.success(null)
            pending = null
        }
    }

    /** Returns true when the result belonged to one of the pickers. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_TONE && requestCode != PICK_FILE) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return true
        }

        if (requestCode == PICK_TONE) {
            val uri = pickedTone(data)
            result.success(uri?.let { mapOf("uri" to it.toString(), "title" to titleOf(it)) })
            return true
        }

        val source = data.data
        if (source == null) {
            result.success(null)
            return true
        }
        // Copying a song can take a moment; keep the UI thread free.
        Thread {
            val picked = try {
                importFile(source)
            } catch (error: Exception) {
                null
            }
            activity.runOnUiThread { result.success(picked) }
        }.start()
        return true
    }

    private fun pickedTone(data: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        }

    private fun importFile(source: Uri): Map<String, String>? {
        val resolver = activity.contentResolver
        var name = "PharmaLens alarm"
        resolver.query(source, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) name = cursor.getString(0)
        }
        val title = name.substringBeforeLast('.')

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Older Android needs a storage permission to add to the Alarms
            // folder; keep using the picked file instead.
            try {
                resolver.takePersistableUriPermission(source, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: SecurityException) {
            }
            return mapOf("uri" to source.toString(), "title" to title)
        }

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, name)
            put(MediaStore.Audio.Media.MIME_TYPE, resolver.getType(source) ?: "audio/mpeg")
            put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_ALARMS + "/PharmaLens")
            put(MediaStore.Audio.Media.TITLE, title)
            put(MediaStore.Audio.Media.IS_ALARM, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val target = resolver.insert(collection, values) ?: return null
        try {
            resolver.openInputStream(source).use { input ->
                resolver.openOutputStream(target).use { output ->
                    if (input == null || output == null) throw IllegalStateException("Could not copy the file.")
                    input.copyTo(output)
                }
            }
            resolver.update(target, ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }, null, null)
        } catch (error: Exception) {
            resolver.delete(target, null, null)
            throw error
        }
        return mapOf("uri" to target.toString(), "title" to title)
    }

    private fun titleOf(uri: Uri): String =
        try {
            RingtoneManager.getRingtone(activity, uri)?.getTitle(activity) ?: ""
        } catch (_: Exception) {
            ""
        }

    private fun play(uri: String, loop: Boolean) {
        stop()
        val target = if (uri.isEmpty()) Uri.parse("android.resource://${activity.packageName}/raw/pharmalens_alarm") else Uri.parse(uri)
        val next = MediaPlayer()
        player = next
        try {
            next.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            next.setDataSource(activity, target)
            next.isLooping = loop
            next.setOnPreparedListener { if (player === it) it.start() }
            // A deleted or unreadable file: ring with the PharmaLens tone.
            next.setOnErrorListener { _, _, _ ->
                if (uri.isNotEmpty() && player === next) play("", loop)
                true
            }
            next.prepareAsync()
        } catch (error: Exception) {
            next.release()
            player = null
            if (uri.isNotEmpty()) play("", loop)
        }
    }

    fun stop() {
        player?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        player = null
    }

    private companion object {
        const val PICK_TONE = 7301
        const val PICK_FILE = 7302
    }
}
