import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import 'alarm_ringing_screen.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;

  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TaskService _taskService = TaskService();
  final NotificationService _notifService = NotificationService();
  DateTime _selectedDate = DateTime.now();
  int _selectedPriority = 2;
  bool _isLoading = false;

  // Alarm fields
  bool _alarmEnabled = false;
  TimeOfDay? _alarmTime;
  String? _alarmSoundPath;
  String? _alarmSoundName;

  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final task = widget.task!;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _selectedDate = task.dueDate;
      _selectedPriority = task.priority;
      _alarmEnabled = task.alarmEnabled;
      _alarmTime = task.alarmTime;
      _alarmSoundPath = task.alarmSoundPath;
      _alarmSoundName = task.alarmSoundName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _testAlarm() {
    // Create a temporary task to test the alarm sound
    final testTask = Task(
      id: 'test_alarm_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim().isEmpty ? 'Test Alarm' : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: DateTime.now(),
      createdAt: DateTime.now(),
      priority: _selectedPriority,
      isCompleted: false,
      alarmEnabled: true,
      alarmTime: _alarmTime ?? TimeOfDay(hour: DateTime.now().hour, minute: DateTime.now().minute),
      alarmSoundPath: _alarmSoundPath,
      alarmSoundName: _alarmSoundName,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AlarmRingingScreen(task: testTask)),
    );
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Please enter a task title', Colors.red);
      return;
    }
    if (_alarmEnabled && _alarmTime == null) {
      _showSnackBar('Please set an alarm time', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isEditing) {
        final updatedTask = widget.task!.copyWith(
          title: title,
          description: _descriptionController.text.trim(),
          dueDate: _selectedDate,
          priority: _selectedPriority,
          alarmEnabled: _alarmEnabled,
          alarmTime: _alarmTime,
          clearAlarmTime: !_alarmEnabled,
          alarmSoundPath: _alarmSoundPath,
          alarmSoundName: _alarmSoundName,
          clearAlarmSound: _alarmSoundPath == null,
        );
        await _taskService.updateTask(updatedTask);
        if (_alarmEnabled) {
          await _notifService.scheduleTaskAlarm(updatedTask);
        } else {
          await _notifService.cancelTaskAlarm(updatedTask.id);
        }
        _showSnackBar('Task updated successfully!', AppColors.green);
      } else {
        final newTask = Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          description: _descriptionController.text.trim(),
          dueDate: _selectedDate,
          isCompleted: false,
          priority: _selectedPriority,
          createdAt: DateTime.now(),
          alarmEnabled: _alarmEnabled,
          alarmTime: _alarmTime,
          alarmSoundPath: _alarmSoundPath,
          alarmSoundName: _alarmSoundName,
        );
        await _taskService.addTask(newTask);
        if (_alarmEnabled) {
          await _notifService.scheduleTaskAlarm(newTask);
        }
        _showSnackBar('Task added successfully!', AppColors.green);
      }

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error saving task: $e', Colors.red);
    }
  }

  Future<void> _deleteTask() async {
    if (!isEditing) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${widget.task!.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      await _notifService.cancelTaskAlarm(widget.task!.id);
      await _taskService.deleteTask(widget.task!.id);
      _showSnackBar('Task deleted!', AppColors.red);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final initHour = _alarmTime?.hour ?? DateTime.now().hour;
    final initMinute = _alarmTime?.minute ?? DateTime.now().minute;
    final flutterTime = await showTimePicker(
      context: context,
      initialTime: mat.TimeOfDay(hour: initHour, minute: initMinute),
    );
    if (flutterTime != null) {
      setState(() {
        _alarmTime = TimeOfDay(hour: flutterTime.hour, minute: flutterTime.minute);
      });
    }
  }

  Future<void> _pickSound() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _alarmSoundPath = result.files.first.path;
          _alarmSoundName = result.files.first.name;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking sound file', Colors.red);
    }
  }

  void _removeSound() {
    setState(() {
      _alarmSoundPath = null;
      _alarmSoundName = null;
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isEditing) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: _deleteTask),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            _sectionLabel('Task Title'),
            const SizedBox(height: 8),
            CustomTextField(controller: _titleController, label: 'Enter task title', icon: Icons.title),
            const SizedBox(height: 20),

            // Description
            _sectionLabel('Description'),
            const SizedBox(height: 8),
            CustomTextField(controller: _descriptionController, label: 'Enter description (optional)', icon: Icons.description_outlined, maxLines: 4),
            const SizedBox(height: 20),

            // Due Date
            _sectionLabel('Due Date'),
            const SizedBox(height: 8),
            _buildDatePicker(),
            const SizedBox(height: 20),

            // Priority
            _sectionLabel('Priority Level'),
            const SizedBox(height: 8),
            Row(children: [
              _buildPriorityOption(1, 'Low', Icons.arrow_downward, AppColors.green),
              const SizedBox(width: 12),
              _buildPriorityOption(2, 'Medium', Icons.remove, AppColors.orange),
              const SizedBox(width: 12),
              _buildPriorityOption(3, 'High', Icons.arrow_upward, AppColors.red),
            ]),
            const SizedBox(height: 20),

            // Alarm Section
            _buildAlarmSection(),
            const SizedBox(height: 32),

            // Save Button
            CustomButton(text: isEditing ? 'Update Task' : 'Add Task', onPressed: _saveTask, isLoading: _isLoading),
            const SizedBox(height: 12),
            // Test Alarm Button
            if (_alarmEnabled && _alarmSoundPath != null)
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: _testAlarm,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Test Alarm Sound Now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadius)),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey, side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadius)),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white, border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 15))),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildAlarmSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _alarmEnabled ? AppColors.primary : Colors.grey.shade300),
        boxShadow: [
          if (_alarmEnabled) BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _alarmEnabled ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.alarm, color: _alarmEnabled ? AppColors.primary : Colors.grey, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Set Alarm Reminder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
            Switch(value: _alarmEnabled, onChanged: (v) => setState(() => _alarmEnabled = v), activeColor: AppColors.primary),
          ]),

          if (_alarmEnabled) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Time picker
            _sectionLabel('Alarm Time'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectTime,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    _alarmTime != null ? _alarmTime!.format() : 'Select alarm time',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _alarmTime != null ? Colors.black87 : Colors.grey),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Sound picker
            _sectionLabel('Alarm Sound'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickSound,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  Icon(
                    _alarmSoundPath != null ? Icons.music_note : Icons.audiotrack_outlined,
                    color: _alarmSoundPath != null ? AppColors.green : Colors.grey, size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _alarmSoundName ?? 'Pick sound from device',
                      style: TextStyle(fontSize: 14, color: _alarmSoundName != null ? Colors.black87 : Colors.grey),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_alarmSoundPath != null)
                    InkWell(onTap: _removeSound, child: const Icon(Icons.close, size: 18, color: Colors.red))
                  else
                    const Icon(Icons.folder_outlined, size: 18, color: Colors.grey),
                ]),
              ),
            ),
            if (_alarmSoundPath == null) ...[
              const SizedBox(height: 6),
              Text('Default system alarm sound will be used', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPriorityOption(int value, String label, IconData icon, Color color) {
    final isSelected = _selectedPriority == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPriority = value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              color: isSelected ? color : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13,
            )),
          ]),
        ),
      ),
    );
  }
}
