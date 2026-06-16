import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
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

  // Audio player for alarm sound
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _autoStopTimer;
  bool _isPlaying = false;
  int _remainingSeconds = 60; // 1 minute auto-stop

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
    _playAlarmSound();
    _startAutoStopTimer();
  }

  Future<void> _playAlarmSound() async {
    debugPrint('>>> _playAlarmSound() called');
    try {
      // Set audio session to play even in silent mode
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ));
      debugPrint('>>> AudioContext set');

      // Enable looping so sound repeats
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // Play custom sound if available
      final soundPath = widget.task.alarmSoundPath;
      debugPrint('>>> Sound path: $soundPath');

      if (soundPath != null && soundPath.isNotEmpty) {
        final exists = File(soundPath).existsSync();
        debugPrint('>>> File exists at original path: $exists');

        if (exists) {
          debugPrint('>>> Playing from original path');
          await _audioPlayer.play(DeviceFileSource(soundPath));
        } else {
          // Try cached version
          final cachedPath = await _getCachedSoundPath();
          debugPrint('>>> Cached path: $cachedPath');
          if (cachedPath != null && File(cachedPath).existsSync()) {
            debugPrint('>>> Playing from cache');
            await _audioPlayer.play(DeviceFileSource(cachedPath));
          } else {
            debugPrint('>>> No sound file found, playing fallback URL');
            await _audioPlayer.play(
              UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'),
            );
          }
        }
      } else {
        debugPrint('>>> No custom sound, playing fallback URL');
        await _audioPlayer.play(
          UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'),
        );
      }

      if (mounted) {
        setState(() => _isPlaying = true);
      }
      debugPrint('>>> Sound playback started successfully');
    } catch (e) {
      debugPrint('>>> Alarm sound ERROR: $e');
    }
  }

  Future<String?> _getCachedSoundPath() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final alarmDir = Directory('${cacheDir.path}/alarm_sounds');
      if (await alarmDir.exists()) {
        final files = await alarmDir.list().toList();
        if (files.isNotEmpty) {
          return files.first.path;
        }
      }
    } catch (_) {}
    return null;
  }

  void _startAutoStopTimer() {
    _autoStopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        _stopSound();
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _stopSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.dispose();
    } catch (_) {}
    _autoStopTimer?.cancel();
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _startVibration() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 500), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 1000), () => HapticFeedback.heavyImpact());
  }

  @override
  void dispose() {
    _stopSound();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _dismissAlarm() async {
    await _stopSound();
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
    await _stopSound();
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
    await _stopSound();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Pulsing alarm icon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.alarm, size: 60, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Sound playing indicator
                if (_isPlaying)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_up, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Alarm playing... ${_remainingSeconds}s',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _stopSound,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.stop, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // Current time
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: 4),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM dd').format(DateTime.now()),
                  style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 20),
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
                      if (task.alarmSoundName != null && task.alarmSoundName!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.music_note, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.alarmSoundName!,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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
                const SizedBox(height: 24),
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
                const SizedBox(height: 12),
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
