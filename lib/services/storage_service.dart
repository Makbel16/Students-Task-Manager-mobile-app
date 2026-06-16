import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class StorageService {
  static const String _tasksKey = 'tasks';
  static const String _userKey = 'user';

  // Save all tasks
  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = tasks.map((task) => task.toMap()).toList();
    prefs.setString(_tasksKey, jsonEncode(tasksJson));
  }

  // Load all tasks
  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString(_tasksKey);
    
    if (tasksString == null) return [];
    
    final List<dynamic> tasksJson = jsonDecode(tasksString);
    return tasksJson.map((json) => Task.fromMap(json)).toList();
  }

  // Save user login state
  Future<void> saveUserLoggedIn(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_userKey, isLoggedIn);
  }

  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userKey) ?? false;
  }

  // Clear all data (logout)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}