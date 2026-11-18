import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'secure_storage_service.dart';

/// Keeps KYC images in app-private storage as authenticated ciphertext.
/// Database rows contain opaque references; the encryption key is stored in
/// device secure storage and is never included in a backup.
class SecureAttachmentService {
  static const String referencePrefix = 'svca1:';
  static const _keyName = 'private_attachments_encryption_key_v1';
  static const _filePrefix = 'SVCA1\n';
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _maxImageBytes = 12 * 1024 * 1024;
  static const _maxImagePixels = 20 * 1000 * 1000;

  static final _cipher = AesGcm.with256bits();
  static Future<List<int>>? _cachedKey;

  final SecureStorageService _secureStorage;

  SecureAttachmentService({SecureStorageService? secureStorage})
    : _secureStorage = secureStorage ?? SecureStorageService();

  bool isAttachmentReference(String? value) =>
      value != null && value.startsWith(referencePrefix);

  String referenceForId(String id) => '$referencePrefix${id.toLowerCase()}';

  String idFromReference(String reference) => _idFromReference(reference);

  String _idFromReference(String reference) {
    if (!isAttachmentReference(reference)) {
      throw const FormatException('The attachment reference is invalid.');
    }
    final id = reference.substring(referencePrefix.length);
    if (!isValidAttachmentId(id)) {
      throw const FormatException('The attachment reference is invalid.');
    }
    return id.toLowerCase();
  }

  Future<String> storeImagePath(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('The selected image is no longer available.');
    }
    if (await source.length() > _maxImageBytes) {
      throw ArgumentError('Choose a JPG or PNG image up to 12 MB.');
    }
    final reference = await storeImageBytes(await source.readAsBytes());
    await _deleteLegacyPickerCopy(sourcePath);
    return reference;
  }

  Future<String> storeImageBytes(List<int> bytes) async {
    final normalizedBytes = Uint8List.fromList(bytes);
    _validateImage(normalizedBytes);
    final id = const Uuid().v4();
    final directory = await _attachmentDirectory(create: true);
    final target = File(p.join(directory.path, '$id.svca'));
    final temporary = File('${target.path}.tmp');
    try {
      final box = await _cipher.encrypt(
        normalizedBytes,
        secretKey: SecretKey(await _attachmentKey()),
      );
      final output = BytesBuilder(copy: false)
        ..add(utf8.encode(_filePrefix))
        ..add(box.nonce)
        ..add(box.mac.bytes)
        ..add(box.cipherText);
      await temporary.writeAsBytes(output.takeBytes(), flush: true);
      await temporary.rename(target.path);
      return '$referencePrefix$id';
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<Uint8List> readImage(String reference) async {
    final id = _idFromReference(reference);
    final directory = await _attachmentDirectory(create: false);
    final encryptedFile = File(p.join(directory.path, '$id.svca'));
    if (!await encryptedFile.exists()) {
      throw StateError('The saved KYC image is unavailable on this device.');
    }
    final bytes = await encryptedFile.readAsBytes();
    final prefix = utf8.encode(_filePrefix);
    if (bytes.length < prefix.length + _nonceLength + _macLength ||
        !listEquals(bytes.sublist(0, prefix.length), prefix)) {
      throw const FormatException('The saved KYC image is damaged.');
    }
    final nonceStart = prefix.length;
    final macStart = nonceStart + _nonceLength;
    final cipherStart = macStart + _macLength;
    try {
      final clear = await _cipher.decrypt(
        SecretBox(
          bytes.sublist(cipherStart),
          nonce: bytes.sublist(nonceStart, macStart),
          mac: Mac(bytes.sublist(macStart, cipherStart)),
        ),
        secretKey: SecretKey(await _attachmentKey()),
      );
      final result = Uint8List.fromList(clear);
      _validateImage(result);
      return result;
    } on SecretBoxAuthenticationError {
      throw StateError('The saved KYC image cannot be decrypted.');
    }
  }

  Future<void> validateImageReference(String reference) async {
    await readImage(reference);
  }

  Future<void> deleteImage(String reference) async {
    final id = _idFromReference(reference);
    final directory = await _attachmentDirectory(create: false);
    final file = File(p.join(directory.path, '$id.svca'));
    if (await file.exists()) await file.delete();
  }

  Future<Map<String, String>> importBackupImages(
    Map<String, Uint8List> backupImages,
  ) async {
    final references = <String, String>{};
    try {
      for (final entry in backupImages.entries) {
        if (!isValidAttachmentId(entry.key)) {
          throw const FormatException('The backup attachment list is invalid.');
        }
        references[entry.key] = await storeImageBytes(entry.value);
      }
      return references;
    } catch (_) {
      await deleteImages(references.values);
      rethrow;
    }
  }

  Future<void> deleteImages(Iterable<String> references) async {
    for (final reference in references) {
      try {
        await deleteImage(reference);
      } catch (_) {
        // Cleanup is best-effort; unreadable files remain encrypted at rest.
      }
    }
  }

  Future<Map<String, Uint8List>> collectKycImages(Database snapshotDb) async {
    final table = await snapshotDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'kyc_forms'",
    );
    if (table.isEmpty) return {};

    final columns = await snapshotDb.rawQuery('PRAGMA table_info(kyc_forms)');
    final available = columns.map((column) => column['name']).toSet();
    if (!available.contains('id')) return {};
    final imageColumns = [
      'photo',
      'h_photo',
    ].where(available.contains).toList(growable: false);
    if (imageColumns.isEmpty) return {};

    final rows = await snapshotDb.query(
      'kyc_forms',
      columns: ['id', ...imageColumns],
    );
    final backupImages = <String, Uint8List>{};
    final legacyPathIds = <String, String>{};
    final rowUpdates = <int, Map<String, Object?>>{};

    for (final row in rows) {
      final updates = <String, Object?>{};
      for (final column in imageColumns) {
        final value = row[column]?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        late final String attachmentId;
        late final Uint8List imageBytes;
        if (isAttachmentReference(value)) {
          attachmentId = _idFromReference(value);
          imageBytes = backupImages[attachmentId] ?? await readImage(value);
        } else {
          final normalizedPath = p.normalize(p.absolute(value));
          attachmentId = legacyPathIds.putIfAbsent(
            normalizedPath,
            () => const Uuid().v4(),
          );
          imageBytes =
              backupImages[attachmentId] ??
              await _readLegacyPickerImage(normalizedPath);
          updates[column] = referenceForId(attachmentId);
        }
        backupImages[attachmentId] = imageBytes;
      }
      if (updates.isNotEmpty) {
        rowUpdates[row['id'] as int] = updates;
      }
    }

    if (rowUpdates.isNotEmpty) {
      await snapshotDb.transaction((txn) async {
        for (final entry in rowUpdates.entries) {
          await txn.update(
            'kyc_forms',
            entry.value,
            where: 'id = ?',
            whereArgs: [entry.key],
          );
        }
      });
    }
    return backupImages;
  }

  Future<int> migrateLegacyKycImages(Database db) async {
    final table = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'kyc_forms'",
    );
    if (table.isEmpty) return 0;
    final columns = await db.rawQuery('PRAGMA table_info(kyc_forms)');
    final available = columns.map((column) => column['name']).toSet();
    if (!available.contains('id')) return 0;
    final imageColumns = [
      'photo',
      'h_photo',
    ].where(available.contains).toList(growable: false);
    if (imageColumns.isEmpty) return 0;

    final rows = await db.query('kyc_forms', columns: ['id', ...imageColumns]);
    final pathReferences = <String, String>{};
    final rowUpdates = <int, Map<String, Object?>>{};
    final createdReferences = <String>[];
    var unavailableImages = 0;
    try {
      for (final row in rows) {
        final updates = <String, Object?>{};
        for (final column in imageColumns) {
          final value = row[column]?.toString().trim() ?? '';
          if (value.isEmpty || isAttachmentReference(value)) continue;
          final normalizedPath = p.normalize(p.absolute(value));
          var reference = pathReferences[normalizedPath];
          if (reference == null) {
            try {
              final bytes = await _readLegacyPickerImage(normalizedPath);
              reference = await storeImageBytes(bytes);
              pathReferences[normalizedPath] = reference;
              createdReferences.add(reference);
            } catch (_) {
              unavailableImages++;
              continue;
            }
          }
          updates[column] = reference;
        }
        if (updates.isNotEmpty) rowUpdates[row['id'] as int] = updates;
      }

      if (rowUpdates.isNotEmpty) {
        await db.transaction((txn) async {
          for (final entry in rowUpdates.entries) {
            await txn.update(
              'kyc_forms',
              entry.value,
              where: 'id = ?',
              whereArgs: [entry.key],
            );
          }
        });
      }
      for (final oldPath in pathReferences.keys) {
        await _deleteLegacyPickerCopy(oldPath);
      }
      return unavailableImages;
    } catch (_) {
      await deleteImages(createdReferences);
      rethrow;
    }
  }

  Future<Uint8List> _readLegacyPickerImage(String path) async {
    final temporary = await getTemporaryDirectory();
    final normalizedTemporary = p.normalize(p.absolute(temporary.path));
    if (!p.isWithin(normalizedTemporary, path)) {
      throw StateError(
        'A saved KYC image is outside app-managed temporary storage. Replace or remove it before creating a backup.',
      );
    }
    final file = File(path);
    if (!await file.exists()) {
      throw StateError(
        'A previously selected KYC image is no longer available. Replace or remove it before creating a backup.',
      );
    }
    final bytes = Uint8List.fromList(await file.readAsBytes());
    _validateImage(bytes);
    return bytes;
  }

  Future<void> _deleteLegacyPickerCopy(String path) async {
    try {
      final temporary = await getTemporaryDirectory();
      final normalizedTemporary = p.normalize(p.absolute(temporary.path));
      final normalizedPath = p.normalize(p.absolute(path));
      if (!p.isWithin(normalizedTemporary, normalizedPath)) return;
      final file = File(normalizedPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The encrypted copy has been stored; cleanup failure is non-fatal.
    }
  }

  bool isValidAttachmentId(String id) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id);

  void _validateImage(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxImageBytes) {
      throw ArgumentError('Choose a JPG or PNG image up to 12 MB.');
    }
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
    final isPng =
        bytes.length >= pngSignature.length &&
        listEquals(bytes.sublist(0, pngSignature.length), pngSignature);
    if (!isJpeg && !isPng) {
      throw ArgumentError('Choose a valid JPG or PNG image.');
    }

    final dimensions = isPng ? _pngDimensions(bytes) : _jpegDimensions(bytes);
    if (dimensions == null || dimensions.$1 <= 0 || dimensions.$2 <= 0) {
      throw ArgumentError('Choose a valid JPG or PNG image.');
    }
    if (dimensions.$1 * dimensions.$2 > _maxImagePixels) {
      throw ArgumentError('Choose an image with no more than 20 megapixels.');
    }
  }

  (int, int)? _pngDimensions(Uint8List bytes) {
    const ihdr = [73, 72, 68, 82];
    if (bytes.length < 24 ||
        !listEquals(bytes.sublist(12, 16), ihdr) ||
        bytes[8] != 0 ||
        bytes[9] != 0 ||
        bytes[10] != 0 ||
        bytes[11] != 13) {
      return null;
    }
    int readUint32(int offset) =>
        (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    return (readUint32(16), readUint32(20));
  }

  (int, int)? _jpegDimensions(Uint8List bytes) {
    var offset = 2;
    while (offset < bytes.length) {
      if (bytes[offset] != 0xff) return null;
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) return null;
      final marker = bytes[offset++];
      if (marker == 0xda || marker == 0xd9) return null;
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (offset + 2 > bytes.length) return null;
      final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
      if (segmentLength < 2 || offset + segmentLength > bytes.length) {
        return null;
      }

      final isStartOfFrame =
          (marker >= 0xc0 && marker <= 0xc3) ||
          (marker >= 0xc5 && marker <= 0xc7) ||
          (marker >= 0xc9 && marker <= 0xcb) ||
          (marker >= 0xcd && marker <= 0xcf);
      if (isStartOfFrame) {
        if (segmentLength < 7) return null;
        final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
        final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
        return (width, height);
      }
      offset += segmentLength;
    }
    return null;
  }

  Future<List<int>> _attachmentKey() => _cachedKey ??= _loadAttachmentKey();

  Future<List<int>> _loadAttachmentKey() async {
    final stored = await _secureStorage.readPersistentSecret(_keyName);
    if (stored != null) {
      try {
        final key = base64Url.decode(base64Url.normalize(stored));
        if (key.length == 32) return key;
      } on FormatException {
        // Corrupted keys must fail closed rather than replacing old keys.
      }
      throw StateError('The private attachment key is invalid.');
    }
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.writePersistentSecret(
      _keyName,
      base64Url.encode(key).replaceAll('=', ''),
    );
    return key;
  }

  Future<Directory> _attachmentDirectory({required bool create}) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'private_attachments'));
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
