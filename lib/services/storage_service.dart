import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class StorageService {
  static const String _userKey = 'user_logged_in';
  static const String _currentUserKey = 'current_user_email';
  static const String _registeredUsersKey = 'registered_users';

  // Get the tasks key for a specific user
  String _tasksKeyForUser(String email) => 'tasks_$email';

  // Save all tasks for the current user
  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_currentUserKey);
    if (email == null) return;
    final tasksJson = tasks.map((task) => task.toMap()).toList();
    await prefs.setString(_tasksKeyForUser(email), jsonEncode(tasksJson));
  }

  // Load all tasks for the current user
  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_currentUserKey);
    if (email == null) return [];
    final String? tasksString = prefs.getString(_tasksKeyForUser(email));
    
    if (tasksString == null) return [];
    
    final List<dynamic> tasksJson = jsonDecode(tasksString);
    return tasksJson.map((json) => Task.fromMap(json)).toList();
  }

  // Save user login state
  Future<void> saveUserLoggedIn(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey, true);
    await prefs.setString(_currentUserKey, email);
  }

  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userKey) ?? false;
  }

  // Get current logged-in user email
  Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserKey);
  }

  // Register a new user
  Future<bool> registerUser(String name, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_registeredUsersKey);
    
    Map<String, dynamic> users = {};
    if (usersJson != null) {
      users = Map<String, dynamic>.from(jsonDecode(usersJson));
    }
    
    // Check if email already exists
    if (users.containsKey(email)) {
      return false; // Email already registered
    }
    
    // Save user credentials
    users[email] = {
      'name': name,
      'email': email,
      'password': password,
    };
    
    await prefs.setString(_registeredUsersKey, jsonEncode(users));
    return true;
  }

  // Validate login credentials
  Future<Map<String, String>?> loginUser(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_registeredUsersKey);
    
    if (usersJson == null) return null;
    
    final users = Map<String, dynamic>.from(jsonDecode(usersJson));
    
    if (!users.containsKey(email)) return null;
    
    final userData = Map<String, dynamic>.from(users[email]);
    if (userData['password'] != password) return null;
    
    return {
      'name': userData['name'] ?? '',
      'email': userData['email'] ?? '',
    };
  }

  // Get registered user info
  Future<Map<String, String>?> getUserInfo(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_registeredUsersKey);
    
    if (usersJson == null) return null;
    
    final users = Map<String, dynamic>.from(jsonDecode(usersJson));
    if (!users.containsKey(email)) return null;
    
    final userData = Map<String, dynamic>.from(users[email]);
    return {
      'name': userData['name'] ?? '',
      'email': userData['email'] ?? '',
    };
  }

  // Clear all data (logout)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_currentUserKey);
  }
}