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

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _selectedDate = widget.task!.dueDate;
      _selectedPriority = widget.task!.priority;
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter task title', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    if (widget.task != null) {
      // Update existing task
      final updatedTask = widget.task!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _selectedDate,
        priority: _selectedPriority,
      );
      await _taskService.updateTask(updatedTask);
      _showSnackBar('Task updated successfully', AppColors.green);
    } else {
      // Create new task
      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _selectedDate,
        isCompleted: false,
        priority: _selectedPriority,
        createdAt: DateTime.now(),
      );
      await _taskService.addTask(newTask);
      _showSnackBar('Task added successfully', AppColors.green);
    }

    setState(() => _isLoading = false);
    Navigator.pop(context, true);
  }

  Future<void> _deleteTask() async {
    if (widget.task == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _taskService.deleteTask(widget.task!.id);
              _showSnackBar('Task deleted successfully', AppColors.red);
              if (!mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task != null ? 'Edit Task' : 'Add Task'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.task != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteTask,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          children: [
            CustomTextField(
              controller: _titleController,
              label: AppStrings.taskTitle,
              icon: Icons.title,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _descriptionController,
              label: AppStrings.taskDescription,
              icon: Icons.description,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            // Due Date Picker
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Due Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Priority Selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priority', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPriorityOption(1, 'Low', AppColors.green),
                      const SizedBox(width: 12),
                      _buildPriorityOption(2, 'Medium', AppColors.orange),
                      const SizedBox(width: 12),
                      _buildPriorityOption(3, 'High', AppColors.red),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: widget.task != null ? AppStrings.updateTask : AppStrings.addTask,
              onPressed: _saveTask,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityOption(int value, String label, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPriority = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _selectedPriority == value ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _selectedPriority == value ? color : Colors.grey.shade400,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: _selectedPriority == value ? color : Colors.grey.shade700,
                fontWeight: _selectedPriority == value ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}