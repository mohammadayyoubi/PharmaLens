package com.techwraplb.pharmalens

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val alarmSound by lazy { AlarmSound(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        showOverLockScreenForDose(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        showOverLockScreenForDose(intent)
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The dose screen turns lock-screen display off again when it closes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pharmalens/lock_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setShowWhenLocked" -> {
                        setLockScreenFlags(call.arguments == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pharmalens/alarm_sound")
            .setMethodCallHandler(alarmSound::handle)
        // When the phone last started, so reminders are rebuilt after a
        // reboot (Android drops every scheduled alarm when it restarts).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pharmalens/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bootTime" -> result.success(System.currentTimeMillis() - SystemClock.elapsedRealtime())
                    // Sent with Google API calls so keys restricted to this
                    // Android app (package + signing certificate) accept them.
                    "appIdentity" -> result.success(mapOf("package" to packageName, "sha1" to signingSha1()))
                    else -> result.notImplemented()
                }
            }
    }

    /** SHA-1 of the certificate this install is signed with (Play's app signing key when installed from Play), upper-case hex. */
    private fun signingSha1(): String = try {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES).signingInfo
            when {
                info == null -> emptyArray()
                info.hasMultipleSigners() -> info.apkContentsSigners
                // Ordered from the first certificate to the current one.
                else -> info.signingCertificateHistory.reversedArray()
            }
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures ?: emptyArray()
        }
        val certificate = signatures.firstOrNull()
        if (certificate == null) "" else MessageDigest.getInstance("SHA-1").digest(certificate.toByteArray())
            .joinToString("") { "%02X".format(it) }
    } catch (error: Exception) {
        ""
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!alarmSound.onActivityResult(requestCode, resultCode, data)) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        alarmSound.stop()
        super.onDestroy()
    }

    // Only a medicine alarm (its notification payload starts with "dose:")
    // may show the app over the lock screen; a normal launch never does, so
    // health data is not visible on a locked phone.
    private fun showOverLockScreenForDose(intent: Intent?) {
        val payload = intent?.getStringExtra("payload") ?: return
        if (payload.startsWith("dose:")) setLockScreenFlags(true)
    }

    private fun setLockScreenFlags(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }
}
