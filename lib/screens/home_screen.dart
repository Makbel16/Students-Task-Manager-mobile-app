import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import 'add_task_screen.dart';
import 'profile_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  List<Task> _tasks = [];
  Map<String, int> _stats = {'total': 0, 'pending': 0, 'completed': 0, 'high': 0};
  bool _isLoading = true;
  String _filter = 'all'; // all, pending, completed

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _filter = ['all', 'pending', 'completed'][_tabController.index];
      });
    });
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    _tasks = await _taskService.getTasks();
    _stats = await _taskService.getTaskStats();
    setState(() => _isLoading = false);
  }

  List<Task> get _filteredTasks {
    switch (_filter) {
      case 'pending':
        return _tasks.where((t) => !t.isCompleted).toList();
      case 'completed':
        return _tasks.where((t) => t.isCompleted).toList();
      default:
        return _tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Task Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              if (result == true) _loadTasks();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Section
          _buildStatsSection(),
          // Filter Tabs
          _buildFilterTabs(),
          const SizedBox(height: 8),
          // Task List Header
          _buildTableHeader(),
          // Task List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredTasks.isEmpty
                    ? _buildEmptyState()
                    : _buildTaskList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddTask,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        elevation: 6,
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          _buildStatCard('Total', _stats['total']!, Icons.task_alt, Colors.white),
          const SizedBox(width: 10),
          _buildStatCard('Pending', _stats['pending']!, Icons.pending_actions, AppColors.orange),
          const SizedBox(width: 10),
          _buildStatCard('Done', _stats['completed']!, Icons.check_circle_outline, AppColors.green),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(text: 'All Tasks'),
          Tab(text: 'Pending'),
          Tab(text: 'Completed'),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(flex: 3, child: Text('Task', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 12))),
          Expanded(flex: 1, child: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 12), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 12), textAlign: TextAlign.center)),
          SizedBox(width: 60, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 12), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final task = _filteredTasks[index];
          return _buildTaskRow(task, index);
        },
      ),
    );
  }

  Widget _buildTaskRow(Task task, int index) {
    final isOverdue = task.dueDate.isBefore(DateTime.now()) && !task.isCompleted;
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Delete "${task.title}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: AppColors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await NotificationService().cancelTaskAlarm(task.id);
        await _taskService.deleteTask(task.id);
        _loadTasks();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${task.title}" deleted'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: InkWell(
          onTap: () => _navigateToTaskDetail(task),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: 36,
                  child: Checkbox(
                    value: task.isCompleted,
                    onChanged: (_) => _toggleTaskStatus(task),
                    activeColor: AppColors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                // Task Info
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? Colors.grey : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Alarm indicator
                      if (task.alarmEnabled && task.alarmTime != null && !task.isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.alarm, size: 12, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                task.alarmTime!.format(),
                                style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      if (task.description.isNotEmpty && !(task.alarmEnabled && task.alarmTime != null && !task.isCompleted)) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Priority Badge
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task.priority).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getPriorityText(task.priority),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(task.priority),
                        ),
                      ),
                    ),
                  ),
                ),
                // Due Date
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      DateFormat('MMM dd').format(task.dueDate),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverdue ? AppColors.red : Colors.grey.shade600,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                // Actions
                SizedBox(
                  width: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _navigateToTaskDetail(task),
                        child: Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _confirmDelete(task),
                        child: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            _filter == 'all' ? 'No tasks yet' : 'No ${_filter} tasks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add a task',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
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
      case 2: return 'Med';
      case 3: return 'High';
      default: return 'Normal';
    }
  }

  Future<void> _toggleTaskStatus(Task task) async {
    await _taskService.toggleTaskStatus(task.id);
    await _loadTasks();
  }

  Future<void> _confirmDelete(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
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
      await NotificationService().cancelTaskAlarm(task.id);
      await _taskService.deleteTask(task.id);
      _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${task.title}" deleted'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _navigateToAddTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTaskScreen()),
    );
    if (result == true) await _loadTasks();
  }

  Future<void> _navigateToTaskDetail(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTaskScreen(task: task)),
    );
    if (result == true) await _loadTasks();
  }
}
