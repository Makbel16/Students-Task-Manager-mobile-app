import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/task_model.dart';

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Callback when notification is tapped
  Function(String taskId)? onNotificationTap;

  // Initialize the notification service
  Future<void> initialize({Function(String taskId)? onTap}) async {
    if (_initialized) return;

    onNotificationTap = onTap;

    // Initialize timezone data
    tz_data.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialization settings
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload ?? '';
        if (payload.isNotEmpty && onNotificationTap != null) {
          onNotificationTap!(payload);
        }
      },
    );

    _initialized = true;
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    final notifStatus = await Permission.notification.request();
    final alarmStatus = await Permission.scheduleExactAlarm.request();
    return notifStatus.isGranted && alarmStatus.isGranted;
  }

  // Schedule an alarm notification for a task
  Future<void> scheduleTaskAlarm(Task task) async {
    if (!_initialized) return;

    // Cancel any existing alarm first
    await cancelTaskAlarm(task.id);

    // Check if alarm should be scheduled
    if (!task.alarmEnabled || task.alarmTime == null || task.isCompleted) return;

    final alarmDateTime = task.alarmDateTime;
    if (alarmDateTime == null) return;

    // Don't schedule alarms in the past
    if (alarmDateTime.isBefore(DateTime.now())) return;

    // Convert to timezone-aware datetime
    final scheduledDate = tz.TZDateTime(
      tz.local,
      alarmDateTime.year,
      alarmDateTime.month,
      alarmDateTime.day,
      alarmDateTime.hour,
      alarmDateTime.minute,
    );

    // Build notification details
    final androidDetails = _buildAndroidDetails(task);
    final notifDetails = NotificationDetails(android: androidDetails);

    final notifId = task.id.hashCode.abs() % 100000;

    await _notifications.zonedSchedule(
      notifId,
      task.title,
      'Alarm: ${task.title}\n${task.description.isNotEmpty ? task.description : "Time for your task!"}',
      scheduledDate,
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: task.id,
    );
  }

  AndroidNotificationDetails _buildAndroidDetails(Task task) {
    if (task.alarmSoundPath != null && task.alarmSoundPath!.isNotEmpty) {
      final soundFile = File(task.alarmSoundPath!);
      if (soundFile.existsSync()) {
        return AndroidNotificationDetails(
          'task_alarms',
          'Task Alarms',
          channelDescription: 'Notifications for task reminders and alarms',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
          sound: UriAndroidNotificationSound('file://${task.alarmSoundPath!}'),
          ongoing: true,
          autoCancel: false,
        );
      }
    }

    return AndroidNotificationDetails(
      'task_alarms',
      'Task Alarms',
      channelDescription: 'Notifications for task reminders and alarms',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      ongoing: true,
      autoCancel: false,
    );
  }

  // Cancel alarm for a specific task
  Future<void> cancelTaskAlarm(String taskId) async {
    if (!_initialized) return;
    final notifId = taskId.hashCode.abs() % 100000;
    await _notifications.cancel(notifId);
  }

  // Cancel all alarms
  Future<void> cancelAllAlarms() async {
    if (!_initialized) return;
    await _notifications.cancelAll();
  }

  // Show an immediate notification (for testing)
  Future<void> showImmediateNotification(Task task) async {
    if (!_initialized) return;

    final notifId = task.id.hashCode.abs() % 100000;

    await _notifications.show(
      notifId,
      task.title,
      'Alarm: ${task.description.isNotEmpty ? task.description : "Time for your task!"}',
      NotificationDetails(android: _buildAndroidDetails(task)),
      payload: task.id,
    );
  }

  // Reschedule all alarms (call after app restart)
  Future<void> rescheduleAllAlarms(List<Task> tasks) async {
    for (final task in tasks) {
      if (task.alarmEnabled && task.alarmTime != null && !task.isCompleted) {
        await scheduleTaskAlarm(task);
      }
    }
  }
}
