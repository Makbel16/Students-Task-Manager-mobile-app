import '../models/task_model.dart';
import 'storage_service.dart';

class TaskService {
  // Singleton pattern
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final StorageService _storage = StorageService();
  List<Task> _tasks = [];
  bool _isLoaded = false;

  // Initialize and load tasks from storage
  Future<void> _ensureLoaded() async {
    if (!_isLoaded) {
      _tasks = await _storage.loadTasks();
      _isLoaded = true;
    }
  }

  // Get all tasks
  Future<List<Task>> getTasks() async {
    await _ensureLoaded();
    return List.from(_tasks);
  }

  // Add a new task
  Future<void> addTask(Task task) async {
    await _ensureLoaded();
    _tasks.insert(0, task); // Add to top
    await _storage.saveTasks(_tasks);
  }

  // Update an existing task
  Future<void> updateTask(Task updatedTask) async {
    await _ensureLoaded();
    final index = _tasks.indexWhere((task) => task.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      await _storage.saveTasks(_tasks);
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    await _ensureLoaded();
    _tasks.removeWhere((task) => task.id == taskId);
    await _storage.saveTasks(_tasks);
  }

  // Toggle task completion status
  Future<void> toggleTaskStatus(String taskId) async {
    await _ensureLoaded();
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        isCompleted: !_tasks[index].isCompleted,
      );
      await _storage.saveTasks(_tasks);
    }
  }

  // Get tasks by completion status
  Future<List<Task>> getTasksByStatus(bool isCompleted) async {
    await _ensureLoaded();
    return _tasks.where((task) => task.isCompleted == isCompleted).toList();
  }

  // Get tasks by priority
  Future<List<Task>> getTasksByPriority(int priority) async {
    await _ensureLoaded();
    return _tasks.where((task) => task.priority == priority).toList();
  }

  // Get task count statistics
  Future<Map<String, int>> getTaskStats() async {
    await _ensureLoaded();
    return {
      'total': _tasks.length,
      'completed': _tasks.where((t) => t.isCompleted).length,
      'pending': _tasks.where((t) => !t.isCompleted).length,
      'high': _tasks.where((t) => t.priority == 3 && !t.isCompleted).length,
    };
  }

  // Reload from storage (useful after external changes)
  Future<void> reload() async {
    _tasks = await _storage.loadTasks();
    _isLoaded = true;
  }
}
