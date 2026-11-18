import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// PBKDF2-HMAC-SHA-256 password storage for offline local accounts.
///
/// The implementation comes from package:cryptography. A unique random salt,
/// algorithm version and work factor are stored with each derived key.
class PasswordHashService {
  static const int iterations = 600000;
  static const int maxPasswordBytes = 1024;
  static const int _saltLength = 16;
  static const int _keyLength = 32;
  static const String _prefix = 'pbkdf2-sha256-v1';

  static final Pbkdf2 _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: _keyLength * 8,
  );

  static Future<String> hash(String password) async {
    _validatePasswordLength(password);
    final random = Random.secure();
    final salt = List<int>.generate(
      _saltLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    final key = await _algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final derivedKey = await key.extractBytes();
    return '$_prefix\$$iterations\$${base64Encode(salt)}\$${base64Encode(derivedKey)}';
  }

  static Future<bool> verify(String password, String encodedHash) async {
    if (!supportsPasswordLength(password) ||
        !hasSupportedEncoding(encodedHash)) {
      return false;
    }
    final parts = encodedHash.split(r'$');

    try {
      final salt = base64Decode(parts[2]);
      final expected = base64Decode(parts[3]);
      final key = await _algorithm.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final actual = await key.extractBytes();
      if (actual.length != expected.length) return false;

      var difference = 0;
      for (var index = 0; index < actual.length; index++) {
        difference |= actual[index] ^ expected[index];
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  }

  static bool supportsPasswordLength(String password) =>
      password.isNotEmpty &&
      password.length <= maxPasswordBytes &&
      utf8.encode(password).length <= maxPasswordBytes;

  static bool hasSupportedEncoding(String? encodedHash) {
    if (encodedHash == null) return false;
    final parts = encodedHash.split(r'$');
    if (parts.length != 4 ||
        parts[0] != _prefix ||
        int.tryParse(parts[1]) != iterations) {
      return false;
    }
    try {
      return base64Decode(parts[2]).length == _saltLength &&
          base64Decode(parts[3]).length == _keyLength;
    } on FormatException {
      return false;
    }
  }

  /// Spends the same PBKDF2 work without comparing or retaining a verifier.
  /// Use on invalid, locked, or unknown account paths to reduce timing signals.
  static Future<void> performDummyVerificationWork(String password) async {
    if (!supportsPasswordLength(password)) return;
    await hash(password);
  }

  static void _validatePasswordLength(String password) {
    if (password.isEmpty || password.length > maxPasswordBytes) {
      throw ArgumentError('Password length is not supported.');
    }
    if (utf8.encode(password).length > maxPasswordBytes) {
      throw ArgumentError('Password length is not supported.');
    }
  }
}
