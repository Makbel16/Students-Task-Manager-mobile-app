package com.example.flutter_application_1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Wake the screen
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "TaskManager:AlarmWakeLock"
        )
        wakeLock.acquire(60 * 1000L) // Hold for 60 seconds

        // Launch MainActivity with alarm extras
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("alarm_task_id", intent.getStringExtra("task_id"))
        }
        context.startActivity(launchIntent)

        // Release wakelock after a delay
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }, 65 * 1000L)
    }
}
