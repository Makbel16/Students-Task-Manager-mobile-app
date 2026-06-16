import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

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
  DateTime _selectedDate = DateTime.now();
  int _selectedPriority = 2;
  bool _isLoading = false;

  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _selectedDate = widget.task!.dueDate;
      _selectedPriority = widget.task!.priority;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Please enter a task title', Colors.red);
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
        );
        await _taskService.updateTask(updatedTask);
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
        );
        await _taskService.addTask(newTask);
        _showSnackBar('Task added successfully!', AppColors.green);
      }

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error saving task. Please try again.', Colors.red);
    }
  }

  Future<void> _deleteTask() async {
    if (!isEditing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${widget.task!.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteTask,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text('Task Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _titleController,
              label: 'Enter task title',
              icon: Icons.title,
            ),
            const SizedBox(height: 20),

            // Description
            const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _descriptionController,
              label: 'Enter description (optional)',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // Due Date Picker
            const Text('Due Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Priority Selection
            const Text('Priority Level', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPriorityOption(1, 'Low', Icons.arrow_downward, AppColors.green),
                const SizedBox(width: 12),
                _buildPriorityOption(2, 'Medium', Icons.remove, AppColors.orange),
                const SizedBox(width: 12),
                _buildPriorityOption(3, 'High', Icons.arrow_upward, AppColors.red),
              ],
            ),
            const SizedBox(height: 32),

            // Save Button
            CustomButton(
              text: isEditing ? 'Update Task' : 'Add Task',
              onPressed: _saveTask,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey,
                  side: BorderSide(color: Colors.grey.shade300),
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
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
