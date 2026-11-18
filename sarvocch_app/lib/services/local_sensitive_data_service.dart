import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'secure_storage_service.dart';

/// Encrypts selected high-risk fields in SQLite while preserving the app's
/// existing SQLite implementation across supported platforms.
class LocalSensitiveDataService {
  static const _prefix = 'enc:v1:';
  static const _keyName = 'microcare_sensitive_field_key_v1';
  static const _nonceLength = 12;
  static const _macLength = 16;
  static final _cipher = AesGcm.with256bits();

  final SecureStorageService _secureStorage;

  LocalSensitiveDataService({SecureStorageService? secureStorage})
    : _secureStorage = secureStorage ?? SecureStorageService();

  Future<String> encrypt(String value) async {
    if (value.isEmpty) return value;
    if (value.startsWith(_prefix)) {
      await decrypt(value);
      return value;
    }
    final box = await _cipher.encrypt(
      utf8.encode(value),
      secretKey: SecretKey(await _getKey()),
    );
    final bytes = <int>[...box.nonce, ...box.mac.bytes, ...box.cipherText];
    return '$_prefix${base64Encode(bytes)}';
  }

  Future<String> decrypt(String value) async {
    if (!value.startsWith(_prefix)) return value;
    try {
      final bytes = base64Decode(value.substring(_prefix.length));
      if (bytes.length < _nonceLength + _macLength) {
        throw const FormatException('Encrypted field is truncated.');
      }
      final macStart = _nonceLength;
      final cipherStart = macStart + _macLength;
      final clearBytes = await _cipher.decrypt(
        SecretBox(
          bytes.sublist(cipherStart),
          nonce: bytes.sublist(0, macStart),
          mac: Mac(bytes.sublist(macStart, cipherStart)),
        ),
        secretKey: SecretKey(await _getKey()),
      );
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      throw StateError(
        'A protected local field cannot be decrypted with this installation key.',
      );
    } on FormatException {
      throw StateError('A protected local field is damaged.');
    }
  }

  String lastFour(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  Future<List<int>> _getKey() async {
    final encoded = await _secureStorage.readPersistentSecret(_keyName);
    if (encoded != null) {
      try {
        final key = base64Decode(encoded);
        if (key.length == 32) return key;
      } on FormatException {
        // Report an invalid key without replacing it and losing access to data.
      }
      throw StateError('The local sensitive-data key is invalid.');
    }

    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.writePersistentSecret(_keyName, base64Encode(key));
    return key;
  }
}
