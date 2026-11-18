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

import '../data/database_helper.dart';
import 'secure_attachment_service.dart';
import 'secure_storage_service.dart';

/// Encrypted, on-device recovery snapshots for the local SQLite database.
/// These snapshots stay on this installation and are not a substitute for an
/// organization-managed off-device backup.
class DatabaseRecoveryService {
  static const _keyName = 'local_database_recovery_key_v1';
  static const _filePrefix = 'SVCB1\n';
  static const _bundlePrefix = 'SVCBUNDLE1\n';
  static const _portablePrefix = 'SVCP3\n';
  static const _portableV2Prefix = 'SVCP2\n';
  static const _legacyPortablePrefix = 'SVCP1\n';
  static const _portableSaltLength = 16;
  static const _portableIterations = 600000;
  static const _nonceLength = 12;
  static const _macLength = 16;
  static final _cipher = AesGcm.with256bits();
  static final _portableKdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _portableIterations,
    bits: 256,
  );

  final DatabaseHelper _databaseHelper;
  final SecureAttachmentService _attachmentService;
  final SecureStorageService _secureStorage;

  DatabaseRecoveryService({
    DatabaseHelper? databaseHelper,
    SecureAttachmentService? attachmentService,
    SecureStorageService? secureStorage,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       _attachmentService = attachmentService ?? SecureAttachmentService(),
       _secureStorage = secureStorage ?? SecureStorageService();

  Future<List<File>> listSnapshots() async {
    final directory = await _snapshotDirectory(create: false);
    if (!await directory.exists()) return [];
    final files = await directory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.svcbak'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<File> createSnapshot({required int actorUserId}) async {
    final snapshot = await _createDatabaseSnapshot(
      actorUserId,
      databaseKey: await _databaseHelper.databaseEncryptionKey,
    );
    final backupPayload = await _encodeBackupBundle(snapshot);
    final snapshotDirectory = await _snapshotDirectory(create: true);
    final id = const Uuid().v4();
    final encryptedPath = p.join(
      snapshotDirectory.path,
      'microcare_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}_$id.svcbak',
    );
    final temporaryFile = File('$encryptedPath.part');
    final encryptedFile = File(encryptedPath);
    final box = await _cipher.encrypt(
      backupPayload,
      secretKey: SecretKey(await _recoveryKey()),
    );
    final bytes = BytesBuilder(copy: false)
      ..add(utf8.encode(_filePrefix))
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    try {
      await temporaryFile.writeAsBytes(bytes.takeBytes(), flush: true);
      await temporaryFile.rename(encryptedFile.path);
      await _recordRecoverySnapshotCreated(
        actorUserId: actorUserId,
        fileName: p.basename(encryptedFile.path),
      );
      return encryptedFile;
    } catch (_) {
      if (await encryptedFile.exists()) await encryptedFile.delete();
      if (await temporaryFile.exists()) await temporaryFile.delete();
      rethrow;
    }
  }

  Future<Uint8List> createPortableBackup({
    required int actorUserId,
    required String passphrase,
  }) async {
    _validatePortablePassphrase(passphrase);
    final random = Random.secure();
    final salt = List<int>.generate(
      _portableSaltLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    final key = await _derivePortableKey(passphrase, salt);
    final databaseKey = base64Url.encode(key).replaceAll('=', '');
    final snapshot = await _createDatabaseSnapshot(
      actorUserId,
      databaseKey: databaseKey,
      portableDatabaseKey: databaseKey,
    );
    final backupPayload = await _encodeBackupBundle(snapshot);
    final box = await _cipher.encrypt(backupPayload, secretKey: SecretKey(key));
    final bytes = BytesBuilder(copy: false)
      ..add(utf8.encode(_portablePrefix))
      ..add(salt)
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return Uint8List.fromList(bytes.takeBytes());
  }

  Future<void> recordPortableBackupExport({
    required int actorUserId,
    required String fileName,
  }) async {
    final db = await _requireActiveAdmin(actorUserId);
    final occurredAt = DateTime.now().toIso8601String().substring(0, 19);
    await db.transaction((txn) async {
      final actors = await txn.query(
        'users',
        columns: ['name'],
        where: "id = ? AND role = 'admin' AND auth_status = 'active'",
        whereArgs: [actorUserId],
        limit: 1,
      );
      if (actors.isEmpty) {
        throw StateError('An active administrator is required.');
      }
      await txn.insert('audit_log', {
        'operation_id': const Uuid().v4(),
        'entity_type': 'system',
        'entity_id': 0,
        'action': 'portable_backup_exported',
        'actor_user_id': actorUserId,
        'actor_role': 'admin',
        'actor_name': actors.first['name'],
        'occurred_at': occurredAt,
        'details': jsonEncode({'file_name': p.basename(fileName)}),
      });
    });
  }

  Future<void> _recordRecoverySnapshotCreated({
    required int actorUserId,
    required String fileName,
  }) async {
    final db = await _requireActiveAdmin(actorUserId);
    final occurredAt = DateTime.now().toIso8601String().substring(0, 19);
    await db.transaction((txn) async {
      final actors = await txn.query(
        'users',
        columns: ['name'],
        where: "id = ? AND role = 'admin' AND auth_status = 'active'",
        whereArgs: [actorUserId],
        limit: 1,
      );
      if (actors.isEmpty) {
        throw StateError('An active administrator is required.');
      }
      await txn.insert('audit_log', {
        'operation_id': const Uuid().v4(),
        'entity_type': 'system',
        'entity_id': 0,
        'action': 'recovery_snapshot_created',
        'actor_user_id': actorUserId,
        'actor_role': 'admin',
        'actor_name': actors.first['name'],
        'occurred_at': occurredAt,
        'details': jsonEncode({'file_name': p.basename(fileName)}),
      });
    });
  }

  Future<({Uint8List databaseBytes, Map<String, Uint8List> attachments})>
  _createDatabaseSnapshot(
    int actorUserId, {
    required String databaseKey,
    String? portableDatabaseKey,
  }) async {
    final db = await _requireActiveAdmin(actorUserId);
    final integrity = await db.rawQuery('PRAGMA quick_check');
    if (integrity.isEmpty || integrity.first.values.first != 'ok') {
      throw StateError(
        'The local database failed its integrity check. Create a recovery snapshot after the database is reviewed.',
      );
    }

    await _databaseHelper.persistentDatabasePath;
    final temporaryDirectory = await getTemporaryDirectory();
    final id = const Uuid().v4();
    final encryptedFile = File(
      p.join(temporaryDirectory.path, 'microcare_$id.db'),
    );
    Database? snapshotDb;
    try {
      final encryptedUri = _databaseHelper.encryptedFileUriForKey(
        encryptedFile.path,
        databaseKey,
      );
      await db.execute("VACUUM INTO '${encryptedUri.replaceAll("'", "''")}'");
      if (portableDatabaseKey != null) {
        await _databaseHelper.preparePortableBackupFile(
          encryptedFile.path,
          databaseKey: portableDatabaseKey,
        );
      }
      snapshotDb = await _databaseHelper.openEncryptedDatabaseFile(
        encryptedFile.path,
        key: databaseKey,
      );
      final attachments = await _attachmentService.collectKycImages(snapshotDb);
      await snapshotDb.execute('VACUUM');
      await snapshotDb.close();
      snapshotDb = null;
      return (
        databaseBytes: await encryptedFile.readAsBytes(),
        attachments: attachments,
      );
    } finally {
      if (snapshotDb != null) await snapshotDb.close();
      if (await encryptedFile.exists()) await encryptedFile.delete();
    }
  }

  Future<Uint8List> _encodeBackupBundle(
    ({Uint8List databaseBytes, Map<String, Uint8List> attachments}) snapshot,
  ) async {
    final attachmentManifest = <String, Map<String, Object>>{};
    for (final entry in snapshot.attachments.entries) {
      attachmentManifest[entry.key.toLowerCase()] = {
        'size_bytes': entry.value.length,
        'sha256': await _sha256Hex(entry.value),
      };
    }
    final manifest = {
      'algorithm': 'sha-256',
      'database': {
        'size_bytes': snapshot.databaseBytes.length,
        'sha256': await _sha256Hex(snapshot.databaseBytes),
      },
      'attachments': attachmentManifest,
    };
    final encoded = BytesBuilder(copy: false)
      ..add(utf8.encode(_bundlePrefix))
      ..add(
        utf8.encode(
          jsonEncode({
            'version': 2,
            'database': base64Encode(snapshot.databaseBytes),
            'attachments': {
              for (final entry in snapshot.attachments.entries)
                entry.key: base64Encode(entry.value),
            },
            'manifest': manifest,
          }),
        ),
      );
    return encoded.takeBytes();
  }

  Future<String> _sha256Hex(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<({Uint8List databaseBytes, Map<String, Uint8List> attachments})>
  _decodeBackupBundle(List<int> payload) async {
    final prefix = utf8.encode(_bundlePrefix);
    if (payload.length < prefix.length ||
        !listEquals(payload.sublist(0, prefix.length), prefix)) {
      return (
        databaseBytes: Uint8List.fromList(payload),
        attachments: <String, Uint8List>{},
      );
    }
    try {
      final decoded = jsonDecode(utf8.decode(payload.sublist(prefix.length)));
      if (decoded is! Map || !{1, 2}.contains(decoded['version'])) {
        throw const FormatException('Backup bundle version is unsupported.');
      }
      final databaseValue = decoded['database'];
      final attachmentValues = decoded['attachments'];
      if (databaseValue is! String || attachmentValues is! Map) {
        throw const FormatException('Backup contents are invalid.');
      }
      final databaseBytes = base64Decode(databaseValue);
      final attachments = <String, Uint8List>{};
      for (final entry in attachmentValues.entries) {
        final id = entry.key;
        final encodedImage = entry.value;
        if (id is! String ||
            !_attachmentService.isValidAttachmentId(id) ||
            encodedImage is! String) {
          throw const FormatException('Backup attachments are invalid.');
        }
        final imageBytes = Uint8List.fromList(base64Decode(encodedImage));
        if (imageBytes.isEmpty || imageBytes.length > 12 * 1024 * 1024) {
          throw const FormatException('Backup attachment size is invalid.');
        }
        final normalizedId = id.toLowerCase();
        if (attachments.containsKey(normalizedId)) {
          throw const FormatException('Backup attachments are duplicated.');
        }
        attachments[normalizedId] = imageBytes;
      }
      if (databaseBytes.isEmpty) {
        throw const FormatException('Backup database contents are empty.');
      }
      if (decoded['version'] == 2) {
        final manifest = decoded['manifest'];
        if (manifest is! Map || manifest['algorithm'] != 'sha-256') {
          throw const FormatException('Backup manifest is invalid.');
        }
        final databaseManifest = manifest['database'];
        final attachmentManifest = manifest['attachments'];
        if (databaseManifest is! Map || attachmentManifest is! Map) {
          throw const FormatException('Backup manifest is incomplete.');
        }
        if (!await _matchesManifestEntry(databaseBytes, databaseManifest)) {
          throw const FormatException('Backup database hash is invalid.');
        }
        if (attachmentManifest.length != attachments.length) {
          throw const FormatException('Backup attachment manifest is invalid.');
        }
        for (final entry in attachments.entries) {
          final manifestEntry = attachmentManifest[entry.key];
          if (manifestEntry is! Map ||
              !await _matchesManifestEntry(entry.value, manifestEntry)) {
            throw const FormatException('Backup attachment hash is invalid.');
          }
        }
      }
      return (databaseBytes: databaseBytes, attachments: attachments);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Backup contents are invalid.');
    }
  }

  Future<bool> _matchesManifestEntry(
    List<int> bytes,
    Map<dynamic, dynamic> entry,
  ) async {
    final sizeBytes = entry['size_bytes'];
    final hash = entry['sha256'];
    return sizeBytes is int &&
        sizeBytes == bytes.length &&
        hash is String &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) &&
        await _sha256Hex(bytes) == hash;
  }

  Future<String> restoreSnapshot({
    required int actorUserId,
    required String snapshotPath,
  }) async {
    await _requireActiveAdmin(actorUserId);
    final snapshotDirectory = await _snapshotDirectory(create: false);
    final snapshot = File(snapshotPath);
    final normalizedDirectory = p.normalize(snapshotDirectory.path);
    final normalizedSnapshot = p.normalize(snapshot.path);
    if (!p.isWithin(normalizedDirectory, normalizedSnapshot) ||
        !snapshot.path.endsWith('.svcbak') ||
        !await snapshot.exists()) {
      throw ArgumentError('Choose a recovery snapshot from this device.');
    }
    final encryptedBytes = await snapshot.readAsBytes();
    final decryptedPayload = await _decryptSnapshot(encryptedBytes);
    final backup = await _decodeBackupBundle(decryptedPayload);
    final plaintextDatabase = _hasPlainSqliteHeader(backup.databaseBytes);
    return _restoreDatabaseBytes(
      actorUserId: actorUserId,
      encryptedDatabaseBytes: backup.databaseBytes,
      sourceDatabaseKey: plaintextDatabase
          ? null
          : await _databaseHelper.databaseEncryptionKey,
      plaintextDatabase: plaintextDatabase,
      backupAttachments: backup.attachments,
      sourceLabel: p.basename(snapshot.path),
      portable: false,
    );
  }

  Future<String> restorePortableBackup({
    required int actorUserId,
    required List<int> backupBytes,
    required String passphrase,
    required String sourceName,
  }) async {
    await _requireActiveAdmin(actorUserId);
    _validatePortablePassphrase(passphrase);
    final portablePayload = await _decryptPortableBackup(
      backupBytes,
      passphrase,
    );
    return _restoreDatabaseBytes(
      actorUserId: actorUserId,
      encryptedDatabaseBytes: portablePayload.databaseBytes,
      sourceDatabaseKey: portablePayload.databaseKey,
      plaintextDatabase: portablePayload.plaintextDatabase,
      backupAttachments: portablePayload.attachments,
      sourceLabel: sourceName,
      portable: true,
    );
  }

  Future<String> _restoreDatabaseBytes({
    required int actorUserId,
    required List<int> encryptedDatabaseBytes,
    required String? sourceDatabaseKey,
    required bool plaintextDatabase,
    required Map<String, Uint8List> backupAttachments,
    required String sourceLabel,
    required bool portable,
  }) async {
    final sourceDb = await _requireActiveAdmin(actorUserId);
    final actorRows = await sourceDb.query(
      'users',
      columns: ['name', 'username'],
      where: 'id = ?',
      whereArgs: [actorUserId],
      limit: 1,
    );
    final actorName = actorRows.first['name'] as String? ?? 'Administrator';
    final actorUsername = (actorRows.first['username'] as String? ?? '').trim();
    if (actorUsername.isEmpty) {
      throw StateError('The active administrator identity is incomplete.');
    }
    final id = const Uuid().v4();
    final temporaryDirectory = await getTemporaryDirectory();
    final candidate = File(p.join(temporaryDirectory.path, 'restore_$id.db'));
    final databasePath = await _databaseHelper.persistentDatabasePath;
    final target = File(databasePath);
    final staged = File('$databasePath.restore_$id');
    final rollback = File('$databasePath.rollback_$id');
    final importedAttachmentReferences = <String>[];
    var restoreCompleted = false;

    try {
      await candidate.writeAsBytes(encryptedDatabaseBytes, flush: true);
      if (plaintextDatabase) {
        await _validatePlaintextCandidate(candidate.path);
        await _databaseHelper.encryptLegacyBackupFile(candidate.path);
        await _validateCandidate(
          candidate.path,
          key: await _databaseHelper.databaseEncryptionKey,
        );
      } else {
        final candidateKey = sourceDatabaseKey;
        if (candidateKey == null) {
          throw StateError('The selected backup encryption key is missing.');
        }
        await _validateCandidate(candidate.path, key: candidateKey);
      }
      if (portable && !plaintextDatabase) {
        final candidateKey = sourceDatabaseKey;
        if (candidateKey == null) {
          throw StateError('The portable backup encryption key is missing.');
        }
        await _databaseHelper.protectPortableBackupFile(
          candidate.path,
          sourceDatabaseKey: candidateKey,
        );
        await _validateCandidate(
          candidate.path,
          key: await _databaseHelper.databaseEncryptionKey,
        );
      }
      final destinationKey = await _databaseHelper.databaseEncryptionKey;
      if (backupAttachments.isNotEmpty) {
        final imported = await _attachmentService.importBackupImages(
          backupAttachments,
        );
        importedAttachmentReferences.addAll(imported.values);
      }
      await _replaceCandidateAttachmentReferences(
        candidate.path,
        databaseKey: destinationKey,
        importedReferences: {
          for (final reference in importedAttachmentReferences)
            _attachmentService.idFromReference(reference): reference,
        },
      );
      await _validateCandidate(candidate.path, key: destinationKey);
      await candidate.copy(staged.path);
      await createSnapshot(actorUserId: actorUserId);

      await _databaseHelper.closeForMaintenance();
      try {
        await _removeSidecarFiles(databasePath);
        if (await target.exists()) await target.copy(rollback.path);
        try {
          await staged.rename(target.path);
        } catch (_) {
          // Some desktop filesystems do not replace an existing file on
          // rename. Keep the rollback copy, then use a delete-and-rename
          // fallback; any failure below restores the saved database.
          if (!await target.exists()) rethrow;
          await target.delete();
          await staged.rename(target.path);
        }
        final restoredDb = await _databaseHelper.reopenAfterMaintenance();
        final integrity = await restoredDb.rawQuery('PRAGMA integrity_check');
        if (integrity.isEmpty || integrity.first.values.first != 'ok') {
          throw StateError('Restored database failed its integrity check.');
        }
        await restoredDb.transaction((txn) async {
          await txn.insert('recovery_events', {
            'operation_id': const Uuid().v4(),
            'action': portable
                ? 'portable_backup_imported'
                : 'database_recovery_restored',
            'source_actor_user_id': actorUserId,
            'source_actor_username': actorUsername,
            'source_actor_name': actorName,
            'source_label': p.basename(sourceLabel),
            'portable': portable ? 1 : 0,
            'occurred_at': DateTime.now().toIso8601String().substring(0, 19),
          });
        });
        if (await rollback.exists()) await rollback.delete();
        restoreCompleted = true;
      } catch (_) {
        await _databaseHelper.closeForMaintenance();
        if (await rollback.exists()) {
          if (await target.exists()) await target.delete();
          await rollback.rename(target.path);
        }
        await _databaseHelper.reopenAfterMaintenance();
        rethrow;
      }
      return sourceLabel;
    } finally {
      if (!restoreCompleted) {
        await _attachmentService.deleteImages(importedAttachmentReferences);
      }
      if (await candidate.exists()) await candidate.delete();
      if (await staged.exists()) await staged.delete();
    }
  }

  Future<Database> _requireActiveAdmin(int actorUserId) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Local recovery snapshots are not available in the web build.',
      );
    }
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'users',
      columns: ['id'],
      where: "id = ? AND role = 'admin' AND auth_status = 'active'",
      whereArgs: [actorUserId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('An active administrator is required.');
    return db;
  }

  Future<void> _replaceCandidateAttachmentReferences(
    String path, {
    required String databaseKey,
    required Map<String, String> importedReferences,
  }) async {
    final candidate = await _databaseHelper.openEncryptedDatabaseFile(
      path,
      key: databaseKey,
    );
    try {
      final tables = await candidate.rawQuery('''
        SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'kyc_forms'
      ''');
      if (tables.isEmpty) {
        if (importedReferences.isEmpty) return;
        throw StateError('Backup images do not match the selected database.');
      }
      final columns = await candidate.rawQuery('PRAGMA table_info(kyc_forms)');
      final available = columns.map((column) => column['name']).toSet();
      final imageColumns = [
        'photo',
        'h_photo',
      ].where(available.contains).toList(growable: false);
      if (imageColumns.isEmpty && importedReferences.isNotEmpty) {
        throw StateError('Backup images do not match the selected database.');
      }
      final rows = await candidate.query(
        'kyc_forms',
        columns: ['id', ...imageColumns],
      );
      final usedIds = <String>{};
      await candidate.transaction((txn) async {
        for (final row in rows) {
          final updates = <String, Object?>{};
          for (final column in imageColumns) {
            final value = row[column]?.toString() ?? '';
            if (!_attachmentService.isAttachmentReference(value)) continue;
            final oldId = _attachmentService.idFromReference(value);
            final newReference = importedReferences[oldId];
            if (newReference == null) {
              throw StateError('A backup image is missing from the archive.');
            }
            usedIds.add(oldId);
            updates[column] = newReference;
          }
          if (updates.isNotEmpty) {
            await txn.update(
              'kyc_forms',
              updates,
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      });
      if (usedIds.length != importedReferences.length) {
        throw StateError('Backup images do not match the selected database.');
      }
      await candidate.execute('VACUUM');
    } finally {
      await candidate.close();
    }
  }

  Future<void> _validateCandidate(String path, {required String key}) async {
    final candidate = await _databaseHelper.openEncryptedDatabaseFile(
      path,
      key: key,
      readOnly: true,
    );
    try {
      final integrity = await candidate.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw StateError('The selected recovery snapshot is damaged.');
      }
      final tables = await candidate.rawQuery('''
        SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'
      ''');
      if (tables.isEmpty) {
        throw StateError('The selected file is not a Microcare database.');
      }
      final versionRows = await candidate.rawQuery('PRAGMA user_version');
      final version = versionRows.first.values.first as int? ?? 0;
      if (version > DatabaseHelper.schemaVersion) {
        throw StateError(
          'This recovery snapshot was created by a newer app version.',
        );
      }
    } finally {
      await candidate.close();
    }
  }

  Future<void> _validatePlaintextCandidate(String path) async {
    final candidate = await openDatabase(
      path,
      readOnly: true,
      singleInstance: false,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        final rows = await db.rawQuery('PRAGMA foreign_keys');
        if (rows.isEmpty || rows.first.values.first != 1) {
          throw StateError('SQLite foreign keys could not be enabled.');
        }
      },
    );
    try {
      final integrity = await candidate.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw StateError('The selected recovery snapshot is damaged.');
      }
      final tables = await candidate.rawQuery('''
        SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'
      ''');
      if (tables.isEmpty) {
        throw StateError('The selected file is not a Microcare database.');
      }
      final versionRows = await candidate.rawQuery('PRAGMA user_version');
      final version = versionRows.first.values.first as int? ?? 0;
      if (version > DatabaseHelper.schemaVersion) {
        throw StateError(
          'This recovery snapshot was created by a newer app version.',
        );
      }
    } finally {
      await candidate.close();
    }
  }

  bool _hasPlainSqliteHeader(List<int> bytes) {
    final expected = ascii.encode('SQLite format 3\u0000');
    return bytes.length >= expected.length &&
        listEquals(bytes.sublist(0, expected.length), expected);
  }

  Future<List<int>> _decryptSnapshot(List<int> bytes) async {
    final prefix = utf8.encode(_filePrefix);
    if (bytes.length < prefix.length + _nonceLength + _macLength ||
        !listEquals(bytes.sublist(0, prefix.length), prefix)) {
      throw const FormatException('Recovery snapshot format is invalid.');
    }
    final nonceStart = prefix.length;
    final macStart = nonceStart + _nonceLength;
    final cipherStart = macStart + _macLength;
    final box = SecretBox(
      bytes.sublist(cipherStart),
      nonce: bytes.sublist(nonceStart, macStart),
      mac: Mac(bytes.sublist(macStart, cipherStart)),
    );
    try {
      return await _cipher.decrypt(
        box,
        secretKey: SecretKey(await _recoveryKey()),
      );
    } on SecretBoxAuthenticationError {
      throw StateError(
        'This snapshot cannot be decrypted with the recovery key on this device.',
      );
    }
  }

  Future<
    ({
      Uint8List databaseBytes,
      String? databaseKey,
      bool plaintextDatabase,
      Map<String, Uint8List> attachments,
    })
  >
  _decryptPortableBackup(List<int> bytes, String passphrase) async {
    final currentPrefix = utf8.encode(_portablePrefix);
    final v2Prefix = utf8.encode(_portableV2Prefix);
    final legacyPrefix = utf8.encode(_legacyPortablePrefix);
    final selectedPrefix = [currentPrefix, v2Prefix, legacyPrefix].firstWhere(
      (candidate) =>
          bytes.length >= candidate.length &&
          listEquals(bytes.sublist(0, candidate.length), candidate),
      orElse: () => Uint8List(0),
    );
    if (selectedPrefix.isEmpty ||
        bytes.length <
            selectedPrefix.length +
                _portableSaltLength +
                _nonceLength +
                _macLength) {
      throw const FormatException('Portable backup format is invalid.');
    }
    final isLegacyPlaintext = identical(selectedPrefix, legacyPrefix);
    final hasBundle = identical(selectedPrefix, currentPrefix);
    final saltStart = selectedPrefix.length;
    final nonceStart = saltStart + _portableSaltLength;
    final macStart = nonceStart + _nonceLength;
    final cipherStart = macStart + _macLength;
    final key = await _derivePortableKey(
      passphrase,
      bytes.sublist(saltStart, nonceStart),
    );
    try {
      final decryptedPayload = await _cipher.decrypt(
        SecretBox(
          bytes.sublist(cipherStart),
          nonce: bytes.sublist(nonceStart, macStart),
          mac: Mac(bytes.sublist(macStart, cipherStart)),
        ),
        secretKey: SecretKey(key),
      );
      final unpacked = hasBundle
          ? await _decodeBackupBundle(decryptedPayload)
          : (
              databaseBytes: Uint8List.fromList(decryptedPayload),
              attachments: <String, Uint8List>{},
            );
      return (
        databaseBytes: unpacked.databaseBytes,
        databaseKey: isLegacyPlaintext
            ? null
            : base64Url.encode(key).replaceAll('=', ''),
        plaintextDatabase: isLegacyPlaintext,
        attachments: unpacked.attachments,
      );
    } on SecretBoxAuthenticationError {
      throw StateError(
        'The passphrase is incorrect or the portable backup was modified.',
      );
    }
  }

  Future<List<int>> _derivePortableKey(
    String passphrase,
    List<int> salt,
  ) async {
    final key = await _portableKdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    return key.extractBytes();
  }

  void _validatePortablePassphrase(String passphrase) {
    if (passphrase.length < 16 || utf8.encode(passphrase).length > 1024) {
      throw ArgumentError(
        'Use a backup passphrase of at least 16 characters and no more than 1024 UTF-8 bytes.',
      );
    }
  }

  Future<List<int>> _recoveryKey() async {
    final existing = await _secureStorage.readPersistentSecret(_keyName);
    if (existing != null) {
      try {
        final key = base64Decode(existing);
        if (key.length == 32) return key;
      } on FormatException {
        // A damaged key is reported below rather than silently replaced.
      }
      throw StateError('The local recovery key is invalid.');
    }

    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.writePersistentSecret(_keyName, base64Encode(key));
    return key;
  }

  Future<Directory> _snapshotDirectory({required bool create}) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(p.join(supportDirectory.path, 'recovery'));
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _removeSidecarFiles(String databasePath) async {
    for (final suffix in const ['-wal', '-shm']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) await file.delete();
    }
  }
}
