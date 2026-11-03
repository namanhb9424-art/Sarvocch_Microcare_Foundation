import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // In-memory fallback for unit/widget tests
  final Map<String, String> _memStorage = {};

  bool get _useMemoryFallback =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> write(String key, String value) async {
    if (_useMemoryFallback) {
      _memStorage[key] = value;
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStorage write error, using memory fallback: $e');
      _memStorage[key] = value;
    }
  }

  Future<String?> read(String key) async {
    if (_useMemoryFallback) {
      return _memStorage[key];
    }
    try {
      return await _storage.read(key: key) ?? _memStorage[key];
    } catch (e) {
      debugPrint('SecureStorage read error, using memory fallback: $e');
      return _memStorage[key];
    }
  }

  Future<void> delete(String key) async {
    if (_useMemoryFallback) {
      _memStorage.remove(key);
      return;
    }
    try {
      await _storage.delete(key: key);
      _memStorage.remove(key);
    } catch (e) {
      _memStorage.remove(key);
    }
  }

  Future<void> clearAll() async {
    _memStorage.clear();
    if (!_useMemoryFallback) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }

  // Convenience methods for credentials & tokens
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'auth_user_id';
  static const _keyUserRole = 'auth_user_role';
  static const _keyUserName = 'auth_user_name';

  Future<void> saveAuthSession({
    required String token,
    required int userId,
    required String role,
    required String name,
  }) async {
    await write(_keyToken, token);
    await write(_keyUserId, userId.toString());
    await write(_keyUserRole, role);
    await write(_keyUserName, name);
  }

  Future<String?> getToken() => read(_keyToken);
  Future<String?> getSavedRole() => read(_keyUserRole);
  Future<int?> getSavedUserId() async {
    final v = await read(_keyUserId);
    return v != null ? int.tryParse(v) : null;
  }
}

