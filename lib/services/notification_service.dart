import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task_model.dart';

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const _alarmChannel = MethodChannel('com.example.flutter_application_1/alarm');

  // Callback when alarm triggers (from native or notification tap)
  Function(String taskId)? onAlarmTriggered;

  bool _initialized = false;

  // Callback when notification is tapped
  Function(String taskId)? onNotificationTap;

  // Initialize the notification service
  Future<void> initialize({Function(String taskId)? onTap, Function(String taskId)? onAlarm}) async {
    if (_initialized) return;

    onNotificationTap = onTap;
    onAlarmTriggered = onAlarm;

    // Initialize timezone data
    tz_data.initializeTimeZones();
    final currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialization settings
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload ?? '';
        debugPrint('>>> Notification response received: $payload');
        if (payload.isNotEmpty && onNotificationTap != null) {
          onNotificationTap!(payload);
        }
      },
    );

    // Listen for native alarm triggers
    _alarmChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmTriggered') {
        final taskId = call.arguments as String;
        debugPrint('>>> Native alarm triggered: $taskId');
        if (onAlarmTriggered != null) {
          onAlarmTriggered!(taskId);
        } else if (onNotificationTap != null) {
          onNotificationTap!(taskId);
        }
      }
    });

    _initialized = true;
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    final notifStatus = await Permission.notification.request();
    final alarmStatus = await Permission.scheduleExactAlarm.request();
    return notifStatus.isGranted && alarmStatus.isGranted;
  }

  // Copy sound file to app cache so it's accessible to notification system
  Future<String?> _copySoundToCache(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      final cacheDir = await getTemporaryDirectory();
      final alarmDir = Directory('${cacheDir.path}/alarm_sounds');
      if (!await alarmDir.exists()) {
        await alarmDir.create(recursive: true);
      }

      final fileName = sourcePath.split('/').last;
      final cachedFile = File('${alarmDir.path}/$fileName');
      await sourceFile.copy(cachedFile.path);
      return cachedFile.path;
    } catch (e) {
      return null;
    }
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
    final androidDetails = await _buildAndroidDetails(task);
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

    // Also schedule native alarm to wake screen and auto-open app
    try {
      await _alarmChannel.invokeMethod('scheduleNativeAlarm', {
        'taskId': task.id,
        'triggerTimeMillis': alarmDateTime.millisecondsSinceEpoch,
      });
      debugPrint('>>> Native alarm scheduled for ${alarmDateTime}');
    } catch (e) {
      debugPrint('>>> Failed to schedule native alarm: $e');
    }
  }

  Future<AndroidNotificationDetails> _buildAndroidDetails(Task task) async {
    // Use unique channel ID per task to avoid channel caching issues
    final channelId = 'task_alarm_${task.id.hashCode.abs() % 10000}';
    final channelName = 'Alarm: ${task.title}';

    if (task.alarmSoundPath != null && task.alarmSoundPath!.isNotEmpty) {
      // Copy sound to app cache for reliable access
      final cachedPath = await _copySoundToCache(task.alarmSoundPath!);

      if (cachedPath != null) {
        return AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Alarm notification for ${task.title}',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          sound: UriAndroidNotificationSound('file://$cachedPath'),
          ongoing: true,
          autoCancel: false,
        );
      }
    }

    // Default alarm sound (system default)
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Alarm notification for ${task.title}',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      ongoing: true,
      autoCancel: false,
    );
  }

  // Cancel alarm for a specific task
  Future<void> cancelTaskAlarm(String taskId) async {
    if (!_initialized) return;
    final notifId = taskId.hashCode.abs() % 100000;
    await _notifications.cancel(notifId);
    // Also cancel native alarm
    try {
      await _alarmChannel.invokeMethod('cancelNativeAlarm', {'taskId': taskId});
    } catch (e) {
      debugPrint('>>> Failed to cancel native alarm: $e');
    }
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
      NotificationDetails(android: await _buildAndroidDetails(task)),
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
