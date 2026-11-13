package com.codepeakstudio.pharmalens

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
