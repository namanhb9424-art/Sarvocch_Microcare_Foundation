import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Stores encryption keys only in platform-protected persistent storage.
  Future<void> writePersistentSecret(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      throw StateError(
        'Device secure storage is unavailable; encrypted local data cannot be opened safely.',
      );
    }
  }

  /// Reads a persistent key without accepting a process-only fallback value.
  Future<String?> readPersistentSecret(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      throw StateError(
        'Device secure storage is unavailable; encrypted local data cannot be opened safely.',
      );
    }
  }
}
