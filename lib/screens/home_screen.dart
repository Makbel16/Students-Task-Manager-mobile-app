import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../utils/constants.dart';
import '../widgets/task_card.dart';
import 'add_task_screen.dart';
import 'profile_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService _taskService = TaskService();
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    _tasks = await _taskService.getTasks();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _taskService.getTaskStats();
    final pendingTasks = _tasks.where((t) => !t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard('Total', stats['total']!, Icons.task, AppColors.primary),
                const SizedBox(width: 12),
                _buildStatCard('Pending', stats['pending']!, Icons.pending, AppColors.orange),
                const SizedBox(width: 12),
                _buildStatCard('Completed', stats['completed']!, Icons.check_circle, AppColors.green),
              ],
            ),
          ),
          // Task List Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  '${pendingTasks.length} pending',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Task List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.noTasks,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return TaskCard(
                            task: task,
                            onTap: () => _navigateToTaskDetail(task),
                            onToggleComplete: () => _toggleTaskStatus(task),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTask(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTaskStatus(Task task) async {
    await _taskService.toggleTaskStatus(task.id);
    await _loadTasks();
  }

  Future<void> _navigateToAddTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTaskScreen()),
    );
    if (result == true) {
      await _loadTasks();
    }
  }

  Future<void> _navigateToTaskDetail(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTaskScreen(task: task)),
    );
    if (result == true) {
      await _loadTasks();
    }
  }
}