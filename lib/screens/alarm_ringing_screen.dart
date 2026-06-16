import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class AlarmRingingScreen extends StatefulWidget {
  final Task task;

  const AlarmRingingScreen({super.key, required this.task});

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TaskService _taskService = TaskService();
  final NotificationService _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startVibration();
  }

  void _startVibration() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 500), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 1000), () => HapticFeedback.heavyImpact());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _dismissAlarm() async {
    await _notifService.cancelTaskAlarm(widget.task.id);
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _snoozeAlarm() async {
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    final snoozeTask = widget.task.copyWith(
      dueDate: snoozeTime,
      alarmTime: TimeOfDay(hour: snoozeTime.hour, minute: snoozeTime.minute),
    );
    await _notifService.cancelTaskAlarm(widget.task.id);
    await _notifService.scheduleTaskAlarm(snoozeTask);

    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _markComplete() async {
    await _taskService.toggleTaskStatus(widget.task.id);
    await _notifService.cancelTaskAlarm(widget.task.id);
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final priorityColor = _getPriorityColor(task.priority);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8), const Color(0xFF2C3E50)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Pulsing alarm icon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.alarm, size: 80, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Current time
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: 4),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM dd').format(DateTime.now()),
                  style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 40),
                // Task info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getPriorityText(task.priority),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          if (task.alarmTime != null) ...[
                            const Spacer(),
                            Icon(Icons.alarm, color: Colors.white.withValues(alpha: 0.8), size: 18),
                            const SizedBox(width: 4),
                            Text(task.alarmTime!.format(), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(task.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(task.description, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8))),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                          Text(DateFormat('MMM dd, yyyy').format(task.dueDate),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Action buttons
                Row(
                  children: [
                    Expanded(child: _buildActionButton(Icons.snooze, 'Snooze 5m', _snoozeAlarm, AppColors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildActionButton(Icons.check_circle_outline, 'Complete', _markComplete, AppColors.green)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _dismissAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Dismiss', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1: return AppColors.green;
      case 2: return AppColors.orange;
      case 3: return AppColors.red;
      default: return AppColors.grey;
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 1: return 'Low';
      case 2: return 'Medium';
      case 3: return 'High';
      default: return 'Normal';
    }
  }
}
