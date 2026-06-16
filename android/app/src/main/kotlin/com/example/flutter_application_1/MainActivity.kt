package com.example.flutter_application_1

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_application_1/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAlarmTaskId" -> {
                    val taskId = intent?.getStringExtra("alarm_task_id")
                    result.success(taskId)
                }
                "scheduleNativeAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    val triggerTimeMillis = call.argument<Long>("triggerTimeMillis")
                    if (taskId != null && triggerTimeMillis != null) {
                        scheduleAlarm(taskId, triggerTimeMillis)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing taskId or triggerTimeMillis", null)
                    }
                }
                "cancelNativeAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    if (taskId != null) {
                        cancelAlarm(taskId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing taskId", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Check if app was launched by alarm
        checkAlarmIntent()
    }

    private fun scheduleAlarm(taskId: String, triggerTimeMillis: Long) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("task_id", taskId)
        }

        val requestCode = taskId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Use exact alarm
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTimeMillis,
                pendingIntent
            )
        }
    }

    private fun cancelAlarm(taskId: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val requestCode = taskId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun checkAlarmIntent() {
        val taskId = intent?.getStringExtra("alarm_task_id")
        if (taskId != null) {
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onAlarmTriggered", taskId)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val taskId = intent.getStringExtra("alarm_task_id")
        if (taskId != null) {
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onAlarmTriggered", taskId)
            }
        }
    }
}
