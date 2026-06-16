import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'services/task_service.dart';
import 'screens/splash_screen.dart';
import 'screens/alarm_ringing_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _handleNotificationTap(String taskId) async {
  debugPrint('>>> Notification tapped for task: $taskId');
  final taskService = TaskService();
  final tasks = await taskService.getTasks();
  debugPrint('>>> Found ${tasks.length} tasks');

  final task = tasks.where((t) => t.id == taskId).firstOrNull;
  if (task == null) {
    debugPrint('>>> Task not found!');
    return;
  }

  debugPrint('>>> Task found: ${task.title}, sound: ${task.alarmSoundPath}');

  // Wait for navigator to be ready
  int attempts = 0;
  while (navigatorKey.currentState == null && attempts < 20) {
    await Future.delayed(const Duration(milliseconds: 100));
    attempts++;
  }

  if (navigatorKey.currentState != null) {
    debugPrint('>>> Navigating to AlarmRingingScreen');
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => AlarmRingingScreen(task: task),
      ),
    );
  } else {
    debugPrint('>>> Navigator not available!');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  final notifService = NotificationService();
  await notifService.initialize(
    onTap: (String taskId) async {
      debugPrint('>>> onTap callback fired for: $taskId');
      await _handleNotificationTap(taskId);
    },
    onAlarm: (String taskId) async {
      debugPrint('>>> Native alarm callback fired for: $taskId');
      await _handleNotificationTap(taskId);
    },
  );

  // Request permissions
  await notifService.requestPermissions();

  // Reschedule all existing alarms
  final taskService = TaskService();
  final tasks = await taskService.getTasks();
  await notifService.rescheduleAllAlarms(tasks);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
