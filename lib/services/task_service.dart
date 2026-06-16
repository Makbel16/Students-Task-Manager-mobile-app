import '../models/task_model.dart';
import 'storage_service.dart';

class TaskService {
  final StorageService _storage = StorageService();
  List<Task> _tasks = [];

  // Get all tasks
  Future<List<Task>> getTasks() async {
    _tasks = await _storage.loadTasks();
    return _tasks;
  }

  // Add a new task
  Future<void> addTask(Task task) async {
    _tasks.add(task);
    await _storage.saveTasks(_tasks);
  }

  // Update an existing task
  Future<void> updateTask(Task updatedTask) async {
    final index = _tasks.indexWhere((task) => task.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      await _storage.saveTasks(_tasks);
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
    await _storage.saveTasks(_tasks);
  }

  // Toggle task completion status
  Future<void> toggleTaskStatus(String taskId) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        isCompleted: !_tasks[index].isCompleted,
      );
      await _storage.saveTasks(_tasks);
    }
  }

  // Get tasks by completion status
  List<Task> getTasksByStatus(bool isCompleted) {
    return _tasks.where((task) => task.isCompleted == isCompleted).toList();
  }

  // Get tasks by priority
  List<Task> getTasksByPriority(int priority) {
    return _tasks.where((task) => task.priority == priority).toList();
  }

  // Get task count statistics
  Map<String, int> getTaskStats() {
    return {
      'total': _tasks.length,
      'completed': _tasks.where((t) => t.isCompleted).length,
      'pending': _tasks.where((t) => !t.isCompleted).length,
      'high': _tasks.where((t) => t.priority == 3 && !t.isCompleted).length,
    };
  }
}