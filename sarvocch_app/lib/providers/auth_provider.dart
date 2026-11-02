import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  List<UserModel> _demoUsers = [];
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  List<UserModel> get demoUsers => _demoUsers;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery('''
        SELECT u.*, e.designation 
        FROM users u 
        LEFT JOIN employees e ON u.id = e.user_id
        ORDER BY u.id ASC
      ''');
      _demoUsers = results.map((m) => UserModel.fromMap(m)).toList();
      
      // Default to Aarav Admin on first launch for demonstration
      if (_demoUsers.isNotEmpty && _currentUser == null) {
        _currentUser = _demoUsers.first;
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery('''
        SELECT u.*, e.designation 
        FROM users u 
        LEFT JOIN employees e ON u.id = e.user_id 
        WHERE u.username = ? AND u.pw = ?
      ''', [username, password]);

      if (results.isNotEmpty) {
        _currentUser = UserModel.fromMap(results.first);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void switchDemoRole(String username) {
    final matched = _demoUsers.firstWhere(
      (u) => u.username == username,
      orElse: () => _demoUsers.first,
    );
    _currentUser = matched;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
