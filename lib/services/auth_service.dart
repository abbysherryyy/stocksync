// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Keys for SharedPreferences
  static const String _usersKey = 'registered_users';
  static const String _currentUserKey = 'current_user';
  static const String _loggedInKey = 'isLoggedIn';

  // Demo credentials (still available)
  final String _demoEmail = 'demo@stocksync.com';
  final String _demoPassword = 'password123';

  // Login
  Future<bool> login(String email, String password, {bool rememberMe = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // Check demo account first
    if (email == _demoEmail && password == _demoPassword) {
      await prefs.setBool(_loggedInKey, true);
      await prefs.setString('userEmail', email);
      await prefs.setString('userName', 'Demo User');
      return true;
    }

    // Check registered users
    final users = await _getRegisteredUsers();
    for (var user in users) {
      if (user['email'] == email && user['password'] == password) {
        await prefs.setBool(_loggedInKey, true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userName', user['name'] ?? email.split('@')[0]);
        return true;
      }
    }

    return false;
  }

  // Sign Up
  Future<bool> signUp(String email, String password, String name) async {
    final prefs = await SharedPreferences.getInstance();

    // Check if already exists
    final users = await _getRegisteredUsers();
    if (users.any((user) => user['email'] == email)) {
      throw Exception('Email already registered');
    }

    // Add new user
    users.add({
      'email': email,
      'password': password,
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Save to SharedPreferences
    await prefs.setString(_usersKey, _encodeUsers(users));

    // Auto-login after signup
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString('userEmail', email);
    await prefs.setString('userName', name);

    return true;
  }

  // Get all registered users
  Future<List<Map<String, String>>> _getRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersString = prefs.getString(_usersKey);
    if (usersString == null) return [];

    return _decodeUsers(usersString);
  }

  // Encode users list to JSON string
  String _encodeUsers(List<Map<String, String>> users) {
    return users.map((user) =>
    '${user['email']}|${user['password']}|${user['name']}|${user['createdAt']}'
    ).join(';');
  }

  // Decode users from JSON string
  List<Map<String, String>> _decodeUsers(String usersString) {
    if (usersString.isEmpty) return [];

    return usersString.split(';').map((userStr) {
      final parts = userStr.split('|');
      return {
        'email': parts[0],
        'password': parts[1],
        'name': parts.length > 2 ? parts[2] : parts[0].split('@')[0],
        'createdAt': parts.length > 3 ? parts[3] : DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  // Get user info
  Future<Map<String, String?>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('userEmail'),
      'name': prefs.getString('userName'),
    };
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loggedInKey);
    await prefs.remove('userEmail');
    await prefs.remove('userName');
  }
}