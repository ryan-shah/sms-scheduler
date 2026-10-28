package com.rsh.smsscheduler

import android.app.AlarmManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // UI-only channel. Never call it from the alarm isolate: MainActivity
        // channels are not registered in the background engine (CLAUDE.md).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
                    "openExactAlarmSettings" -> result.success(openExactAlarmSettings())
                    else -> result.notImplemented()
                }
            }
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    }

    private fun openExactAlarmSettings(): Boolean {
        val sdk = Build.VERSION.SDK_INT
        if (sdk < Build.VERSION_CODES.S) return false
        val uri = Uri.parse("package:$packageName")
        // USE_EXACT_ALARM (API 33+) is not user-revocable, so there is no
        // per-app toggle; fall back to the app details page.
        val action = if (sdk < Build.VERSION_CODES.TIRAMISU) {
            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
        } else {
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS
        }
        return try {
            startActivity(Intent(action, uri))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    companion object {
        private const val SYSTEM_CHANNEL = "com.rsh.smsscheduler/system"
    }
}
