import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'services/task_service.dart';
import 'screens/splash_screen.dart';
import 'screens/alarm_ringing_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  final notifService = NotificationService();
  await notifService.initialize(
    onTap: (String taskId) async {
      // When notification is tapped, find the task and show alarm screen
      final taskService = TaskService();
      final tasks = await taskService.getTasks();
      final task = tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null && navigatorKey.currentContext != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => AlarmRingingScreen(task: task),
          ),
        );
      }
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
