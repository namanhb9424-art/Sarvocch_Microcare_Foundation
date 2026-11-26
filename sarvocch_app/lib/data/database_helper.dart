import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/password_hash_service.dart';
import '../services/local_sensitive_data_service.dart';
import '../services/secure_attachment_service.dart';
import '../services/secure_storage_service.dart';

class DatabaseHelper {
  static const int schemaVersion = 33;
  static const String _databaseKeyName = 'local_database_encryption_key_v1';
  static const String _migrationRollbackSuffix = '.plaintext_migration_backup';
  static const Map<String, String> _appExtraMoneyColumns = {
    'inc_agri': 'inc_agri_paise',
    'inc_business': 'inc_business_paise',
    'inc_job': 'inc_job_paise',
    'inc_other': 'inc_other_paise',
    'exp_basic': 'exp_basic_paise',
    'exp_education': 'exp_education_paise',
    'exp_festival': 'exp_festival_paise',
    'exp_health': 'exp_health_paise',
    'exp_emi': 'exp_emi_paise',
    'exp_other': 'exp_other_paise',
    'group_rec': 'group_rec_paise',
    'center_rec': 'center_rec_paise',
    'requested_amt': 'requested_amt_paise',
    'income_total': 'income_total_paise',
    'expense_total': 'expense_total_paise',
    'net_saving': 'net_saving_paise',
  };
  static const Set<String> _appExtraPositiveMoneyColumns = {
    'requested_amt',
    'income_total',
  };
  static const Set<String> _appExtraNegativeMoneyColumns = {'net_saving'};

  static String _appExtraMoneyInvalidCondition(String prefix) {
    return _appExtraMoneyColumns.entries
        .map((entry) {
          final amount = '$prefix${entry.key}';
          final minor = '$prefix${entry.value}';
          final invalidSign = _appExtraPositiveMoneyColumns.contains(entry.key)
              ? '$amount <= 0'
              : _appExtraNegativeMoneyColumns.contains(entry.key)
              ? null
              : '$amount < 0';
          return '''
        ($amount IS NULL AND $minor IS NOT NULL)
        OR ($amount IS NOT NULL AND (
          ${invalidSign == null ? '' : '$invalidSign OR'}
          $minor IS NULL
          OR $minor != CAST(ROUND($amount * 100) AS INTEGER)
          OR ABS($amount * 100 - ROUND($amount * 100)) > 0.000001
        ))
      ''';
        })
        .join(' OR ');
  }

  static final DatabaseHelper instance = DatabaseHelper._internal();
  Database? _database;
  String? _databasePath;
  bool _maintenanceActive = false;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_maintenanceActive) {
      throw StateError('The local database is undergoing maintenance.');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String> get persistentDatabasePath async {
    await database;
    final path = _databasePath;
    if (kIsWeb || path == null || path == inMemoryDatabasePath) {
      throw UnsupportedError(
        'Local recovery snapshots require a persistent device database.',
      );
    }
    return path;
  }

  Future<void> resetDatabase() async {
    final current = _database;
    if (current != null) {
      await current.close();
      _database = null;
    }
    _maintenanceActive = false;
  }

  Future<void> closeForMaintenance() async {
    _maintenanceActive = true;
    final current = _database;
    if (current == null) return;
    try {
      await current.rawQuery('PRAGMA wal_checkpoint(FULL)');
      await current.close();
      _database = null;
    } catch (_) {
      _maintenanceActive = false;
      rethrow;
    }
  }

  Future<Database> reopenAfterMaintenance() async {
    if (!_maintenanceActive) {
      throw StateError('The local database is not in maintenance mode.');
    }
    try {
      _database = await _initDatabase();
      return _database!;
    } finally {
      _maintenanceActive = false;
    }
  }

  Future<void> retrySensitiveDataScrub({required int actorUserId}) async {
    final db = await database;
    final actors = await db.query(
      'users',
      columns: ['id'],
      where: "id = ? AND role = 'admin' AND auth_status = 'active'",
      whereArgs: [actorUserId],
      limit: 1,
    );
    if (actors.isEmpty) {
      throw StateError('An active administrator is required.');
    }
    await db.execute('PRAGMA secure_delete = ON');
    await _completeSensitiveDataScrub(db);
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Browser storage is not supported for this app because it is not encrypted. Use the native app for customer data.',
      );
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    String path;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      path = inMemoryDatabasePath;
    } else {
      try {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        path = join(documentsDirectory.path, 'sarvocch_microcare.db');
      } catch (_) {
        if (kDebugMode || Platform.environment.containsKey('FLUTTER_TEST')) {
          path = inMemoryDatabasePath;
        } else {
          rethrow;
        }
      }
    }

    _databasePath = path;
    final isInMemory = path == inMemoryDatabasePath;
    final key = isInMemory ? null : await _getOrCreateDatabaseKey();
    if (key != null) await _ensureEncryptedDatabase(path, key);
    final db = key == null
        ? await openDatabase(
            path,
            version: schemaVersion,
            onConfigure: _configureDatabaseConnection,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
          )
        : await _openVersionedEncryptedDatabase(path, key);
    await _assertForeignKeysEnabled(db);
    await db.execute('PRAGMA secure_delete = ON');
    await _completeSensitiveDataScrub(db);
    await _retryPendingForeignKeyMigrations(db);
    await _ensureOfflineIntegrityIndexes(db);
    await _ensureRecoveryEventsTable(db);
    await _ensureMfiReferenceTriggers(db);
    await _refreshMfiReferenceWarnings(db);
    await _refreshForeignKeyWarnings(db);
    await _refreshForeignKeyMigrationWarning(db);
    await _migrateLegacyKycImages(db);
    return db;
  }

  Future<void> _migrateLegacyKycImages(Database db) async {
    const warningKey = 'integrity_warning_kyc_attachments_v11';
    try {
      final unavailable = await SecureAttachmentService()
          .migrateLegacyKycImages(db);
      if (unavailable == 0) {
        await db.delete('app_meta', where: 'key = ?', whereArgs: [warningKey]);
      } else {
        await db.insert('app_meta', {
          'key': warningKey,
          'value': '$unavailable',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {
      await db.insert('app_meta', {
        'key': warningKey,
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('Some legacy KYC images could not be migrated securely.');
    }
  }

  /// Returns the native database key. Recovery/import flows use the same key
  /// to validate encrypted SQLite files before they replace the live database.
  Future<String> get databaseEncryptionKey => _getOrCreateDatabaseKey();

  /// Opens an encrypted SQLite file through SQLite3MC. This is used by
  /// recovery flows for encrypted snapshots and passphrase-keyed portable DBs.
  Future<Database> openEncryptedDatabaseFile(
    String path, {
    required String key,
    bool readOnly = false,
  }) {
    return openDatabase(
      path,
      singleInstance: false,
      readOnly: readOnly,
      onConfigure: (db) => _configureEncryptedDatabase(db, key),
    );
  }

  Future<Database> _openVersionedEncryptedDatabase(String path, String key) {
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) => _configureEncryptedDatabase(db, key),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _configureEncryptedDatabase(Database db, String key) async {
    if (key.isEmpty || key.contains("'") || key.contains('\n')) {
      throw StateError('The local database encryption key is invalid.');
    }
    await db.execute("PRAGMA cipher = 'sqlcipher'");
    await db.execute('PRAGMA legacy = 4');
    await db.execute("PRAGMA key = '$key'");
    final cipherRows = await db.rawQuery('PRAGMA cipher');
    final selectedCipher = cipherRows.isEmpty
        ? null
        : cipherRows.first.values.first?.toString().toLowerCase();
    if (selectedCipher != 'sqlcipher') {
      throw StateError(
        'Encrypted SQLite support is unavailable in this build. The database was not opened.',
      );
    }
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA secure_delete = ON');
    await _configureDatabaseConnection(db);
    // PRAGMA key itself does not prove that a key is correct. Force SQLite to
    // read a schema page before the connection is accepted.
    await db.rawQuery('SELECT count(*) FROM sqlite_master');
  }

  Future<void> _configureDatabaseConnection(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await _assertForeignKeysEnabled(db);
  }

  Future<void> _assertForeignKeysEnabled(Database db) async {
    final rows = await db.rawQuery('PRAGMA foreign_keys');
    if (rows.isEmpty || rows.first.values.first != 1) {
      throw StateError(
        'SQLite foreign-key enforcement could not be enabled. The database was not opened for business operations.',
      );
    }
  }

  Future<void> _refreshForeignKeyWarnings(Database db) async {
    const warningKey = 'integrity_warning_foreign_key_violations_v23';
    await db.delete(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['integrity_warning_foreign_key_violations_v21'],
    );
    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    if (violations.isEmpty) {
      await db.delete('app_meta', where: 'key = ?', whereArgs: [warningKey]);
      return;
    }
    await db.insert('app_meta', {
      'key': warningKey,
      'value': '${violations.length}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _refreshForeignKeyMigrationWarning(Database db) async {
    const warningKey = 'integrity_warning_foreign_key_migration_pending_v22';
    const requiredRelations = <String, int>{
      'users': 1,
      'employees': 2,
      'customers': 1,
      'comm_logs': 1,
      'applications': 3,
      'app_extra': 1,
      'approvals': 1,
      'loans': 4,
      'schedule': 1,
      'payments': 2,
      'tasks': 3,
      'attendance': 1,
      'att_requests': 2,
      'pregrt': 1,
      'pregrt_members': 2,
      'kyc_forms': 3,
      'audit_log': 1,
      'mandates': 1,
      'leaves': 1,
      'perf': 1,
      'sync_log': 1,
    };
    var missingRelations = 0;
    for (final entry in requiredRelations.entries) {
      final rows = await db.rawQuery('PRAGMA foreign_key_list(${entry.key})');
      if (rows.length < entry.value) missingRelations++;
    }
    if (missingRelations == 0) {
      await db.delete('app_meta', where: 'key = ?', whereArgs: [warningKey]);
      return;
    }
    await db.insert('app_meta', {
      'key': warningKey,
      'value': '$missingRelations',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _retryPendingForeignKeyMigrations(Database db) async {
    final pending = await db.query(
      'app_meta',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: ['integrity_warning_foreign_key_migration_pending_v22'],
      limit: 1,
    );
    if (pending.isEmpty) return;
    await db.transaction((txn) async {
      await _migrateLegacyLendingForeignKeys(txn);
      await _migrateLegacyOperationalForeignKeys(txn);
      await _ensureOfflineIntegrityIndexes(txn);
    });
  }

  Future<String> _getOrCreateDatabaseKey() async {
    final storage = SecureStorageService();
    final stored = await storage.readPersistentSecret(_databaseKeyName);
    if (stored != null) {
      try {
        if (base64Url.decode(base64Url.normalize(stored)).length == 32) {
          return stored;
        }
      } on FormatException {
        // Report corruption rather than replacing a key and losing the DB.
      }
      throw StateError('The local database encryption key is invalid.');
    }

    final random = Random.secure();
    final rawKey = List<int>.generate(32, (_) => random.nextInt(256));
    final encoded = base64Url.encode(rawKey).replaceAll('=', '');
    await storage.writePersistentSecret(_databaseKeyName, encoded);
    return encoded;
  }

  Future<void> _ensureEncryptedDatabase(String path, String key) async {
    final target = File(path);
    final rollback = File('$path$_migrationRollbackSuffix');
    if (await rollback.exists()) {
      if (!await target.exists()) {
        await rollback.rename(path);
      } else {
        try {
          await _validateEncryptedDatabaseFile(path, key);
          await rollback.delete();
          return;
        } catch (_) {
          // A crash may have left an invalid replacement beside the verified
          // plaintext rollback. Restore that file and retry migration below.
        }
        try {
          await _validateLegacyPlaintextFile(rollback.path);
        } catch (_) {
          throw StateError(
            'The local database and its migration recovery copy could not be opened. Contact support before clearing app data.',
          );
        }
        await target.delete();
        await rollback.rename(path);
        await _removeDatabaseSidecars(path);
      }
    }
    if (!await target.exists()) return;

    final length = await target.length();
    if (length == 0) {
      await target.delete();
      return;
    }

    try {
      await _validateEncryptedDatabaseFile(path, key);
      if (await rollback.exists()) await rollback.delete();
      return;
    } catch (_) {
      // A valid encrypted database with a missing/wrong key must never be
      // interpreted as legacy plaintext. The plaintext integrity/schema check
      // below is required before migration is considered.
    }

    Database? legacyDb;
    final encryptedCandidate = File(
      '$path.encrypted_migration_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      legacyDb = await openDatabase(
        path,
        readOnly: true,
        singleInstance: false,
        onConfigure: _configureDatabaseConnection,
      );
      await _validateLegacyPlaintextDatabase(legacyDb);
      await legacyDb.close();
      legacyDb = null;

      // Reopen for the checkpoint and VACUUM operation. Restrict the migration
      // to a valid SQLite file with the expected application schema.
      legacyDb = await openDatabase(
        path,
        singleInstance: false,
        onConfigure: _configureDatabaseConnection,
      );
      await legacyDb.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await legacyDb.rawQuery('PRAGMA journal_mode = DELETE');
      final encryptedUri = _encryptedFileUri(encryptedCandidate.path, key);
      await legacyDb.execute(
        "VACUUM INTO '${encryptedUri.replaceAll("'", "''")}'",
      );
      await legacyDb.close();
      legacyDb = null;

      await _validateEncryptedDatabaseFile(encryptedCandidate.path, key);
      if (await rollback.exists()) await rollback.delete();
      await target.rename(rollback.path);
      try {
        await encryptedCandidate.rename(target.path);
      } catch (_) {
        if (!await target.exists() && await rollback.exists()) {
          await rollback.rename(target.path);
        }
        rethrow;
      }
      await _removeDatabaseSidecars(path);
      await _validateEncryptedDatabaseFile(path, key);
      if (await rollback.exists()) await rollback.delete();
    } catch (_) {
      if (legacyDb != null) {
        try {
          await legacyDb.close();
        } catch (_) {}
      }
      if (!await target.exists() && await rollback.exists()) {
        await rollback.rename(target.path);
      }
      throw StateError(
        'The existing local database could not be safely encrypted or opened. It was preserved for recovery. Contact support before clearing app data.',
      );
    } finally {
      if (await encryptedCandidate.exists()) {
        await encryptedCandidate.delete();
      }
    }
  }

  Future<void> _validateLegacyPlaintextDatabase(Database db) async {
    final integrity = await db.rawQuery('PRAGMA quick_check');
    if (integrity.isEmpty || integrity.first.values.first != 'ok') {
      throw StateError(
        'The existing SQLite database failed its integrity check.',
      );
    }
    final appTables = await db.rawQuery('''
      SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'
    ''');
    if (appTables.isEmpty) {
      throw StateError('The existing SQLite file is not a Microcare database.');
    }
  }

  Future<void> _validateLegacyPlaintextFile(String path) async {
    final legacyDb = await openDatabase(
      path,
      readOnly: true,
      singleInstance: false,
      onConfigure: _configureDatabaseConnection,
    );
    try {
      await _validateLegacyPlaintextDatabase(legacyDb);
    } finally {
      await legacyDb.close();
    }
  }

  Future<void> _validateEncryptedDatabaseFile(String path, String key) async {
    final encryptedDb = await openEncryptedDatabaseFile(
      path,
      key: key,
      readOnly: true,
    );
    try {
      final integrity = await encryptedDb.rawQuery('PRAGMA quick_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw StateError(
          'Encrypted SQLite database failed its integrity check.',
        );
      }
      final appTables = await encryptedDb.rawQuery('''
        SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'
      ''');
      if (appTables.isEmpty) {
        throw StateError('Encrypted SQLite file is not a Microcare database.');
      }
    } finally {
      await encryptedDb.close();
    }
  }

  String _encryptedFileUri(String path, String key) {
    return Uri.file(path)
        .replace(
          queryParameters: {'cipher': 'sqlcipher', 'legacy': '4', 'key': key},
        )
        .toString();
  }

  String encryptedFileUriForKey(String path, String key) =>
      _encryptedFileUri(path, key);

  Future<void> _removeDatabaseSidecars(String path) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final sidecar = File('$path$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS leaves (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          from_d TEXT,
          to_d TEXT,
          reason TEXT,
          status TEXT DEFAULT 'pending'
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS perf (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          period TEXT,
          rating INTEGER,
          notes TEXT,
          by_name TEXT
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS holidays (
          day TEXT PRIMARY KEY,
          name TEXT
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT UNIQUE,
          user_id INTEGER,
          payload TEXT,
          captured_at TEXT,
          synced_at TEXT
        );
      ''');
    }

    if (oldVersion < 3) {
      final userColumns = await db.rawQuery('PRAGMA table_info(users)');
      final columnNames = userColumns.map((column) => column['name']).toSet();
      if (!columnNames.contains('password_hash')) {
        await db.execute('ALTER TABLE users ADD COLUMN password_hash TEXT');
      }
      if (!columnNames.contains('auth_status')) {
        await db.execute(
          "ALTER TABLE users ADD COLUMN auth_status TEXT NOT NULL DEFAULT 'reset_required'",
        );
      }
      if (!columnNames.contains('failed_login_attempts')) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN failed_login_attempts INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!columnNames.contains('locked_until')) {
        await db.execute('ALTER TABLE users ADD COLUMN locked_until TEXT');
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      // Cloud linking and sync were simulations. Clear their saved settings.
      await _clearLegacyCloudConfiguration(db);

      final legacyUsers = await db.query('users');
      for (final user in legacyUsers) {
        final legacyPassword = user['pw'] as String? ?? '';
        final passwordHash = legacyPassword.isEmpty
            ? null
            : await PasswordHashService.hash(legacyPassword);
        await db.update(
          'users',
          {
            'password_hash': passwordHash,
            'auth_status': passwordHash == null ? 'reset_required' : 'active',
            'failed_login_attempts': 0,
            'locked_until': null,
            // Remove the cleartext value after the derived hash is committed.
            'pw': null,
          },
          where: 'id = ?',
          whereArgs: [user['id']],
        );
      }

      final activeAccounts = await db.rawQuery(
        "SELECT COUNT(*) AS count FROM users WHERE auth_status = 'active' AND password_hash IS NOT NULL",
      );
      final setupCompleted = (activeAccounts.first['count'] as int? ?? 0) > 0;
      await db.insert('app_meta', {
        'key': 'initial_setup_completed',
        'value': setupCompleted ? '1' : '0',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    if (oldVersion < 4) {
      final paymentColumns = await db.rawQuery('PRAGMA table_info(payments)');
      if (!paymentColumns.any((column) => column['name'] == 'operation_id')) {
        await db.execute('ALTER TABLE payments ADD COLUMN operation_id TEXT');
      }
      final taskColumns = await db.rawQuery('PRAGMA table_info(tasks)');
      if (!taskColumns.any((column) => column['name'] == 'loan_id')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN loan_id INTEGER');
      }
      final loanColumns = await db.rawQuery('PRAGMA table_info(loans)');
      if (!loanColumns.any((column) => column['name'] == 'disbursement_ref')) {
        await db.execute('ALTER TABLE loans ADD COLUMN disbursement_ref TEXT');
      }
      if (!loanColumns.any(
        (column) => column['name'] == 'disbursement_channel',
      )) {
        await db.execute(
          'ALTER TABLE loans ADD COLUMN disbursement_channel TEXT',
        );
      }
      await db.execute('''
        UPDATE tasks
        SET loan_id = (
          SELECT l.id FROM loans l
          WHERE l.customer_id = tasks.customer_id AND l.status = 'active'
          LIMIT 1
        )
        WHERE lower(COALESCE(ttype, '')) = 'collection' AND loan_id IS NULL
          AND (
            SELECT COUNT(*) FROM loans l
            WHERE l.customer_id = tasks.customer_id AND l.status = 'active'
          ) = 1
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_operation_id
        ON payments(operation_id)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_schedule_due_unpaid
        ON schedule(loan_id, paid, due_date)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_applications_status_created
        ON applications(status, created)
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation_id TEXT NOT NULL UNIQUE,
          entity_type TEXT NOT NULL,
          entity_id INTEGER NOT NULL,
          action TEXT NOT NULL,
          actor_user_id INTEGER NOT NULL,
          actor_role TEXT NOT NULL,
          actor_name TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          details TEXT NOT NULL DEFAULT '{}'
        )
      ''');

      // Earlier form submission code marked a customer verified without a
      // separate review. Move those records back to the review queue.
      await db.update('customers', {
        'kyc_status': 'pending',
      }, where: "lower(kyc_status) = 'verified'");
    }

    if (oldVersion < 5) {
      final kycColumns = await db.rawQuery('PRAGMA table_info(kyc_forms)');
      if (!kycColumns.any((column) => column['name'] == 'updated_by')) {
        await db.execute('ALTER TABLE kyc_forms ADD COLUMN updated_by INTEGER');
      }
      await db.execute('''
        UPDATE kyc_forms
        SET updated_by = created_by
        WHERE updated_by IS NULL
      ''');
    }

    if (oldVersion < 6 && !kDebugMode) {
      // Legacy WhatsApp OTPs were local simulations, and the prototype seeded
      // example branch coordinates. Clear their verification state/config so
      // release attendance and customer records require real setup.
      await db.update('customers', {'wa_verified': 0, 'wa_otp': null});
      const demoGeofences = [
        ['Indore - Vijay Nagar', 22.7533, 75.8937],
        ['Indore - Palasia', 22.7241, 75.8839],
        ['Bhopal - MP Nagar', 23.2332, 77.4340],
        ['Pipariya Branch', 22.7388, 78.3563],
        ['Bhopal Head Office', 23.2799, 77.4522],
      ];
      for (final geofence in demoGeofences) {
        await db.update(
          'branches',
          {'lat': null, 'lng': null, 'radius_m': 0},
          where: 'name = ? AND lat = ? AND lng = ?',
          whereArgs: geofence,
        );
      }
    }

    if (oldVersion < 8) {
      final kycColumns = await db.rawQuery('PRAGMA table_info(kyc_forms)');
      if (!kycColumns.any((column) => column['name'] == 'bank_acct_last4')) {
        await db.execute(
          'ALTER TABLE kyc_forms ADD COLUMN bank_acct_last4 TEXT',
        );
      }
      await db.execute('PRAGMA secure_delete = ON');
      await _protectLegacyBankAccounts(db, scrubLegacyPlaintext: true);
    }

    if (oldVersion < 9) {
      await _clearLegacyCloudConfiguration(db);
    }

    if (oldVersion < 21) {
      await _migrateCoreMoneyColumns(db);
      for (final trigger in _mfiIntegrityTriggerNames) {
        await db.execute('DROP TRIGGER IF EXISTS $trigger');
      }
      await _ensureOfflineIntegrityIndexes(db);
    }

    if (oldVersion < 22) {
      for (final trigger in _mfiIntegrityTriggerNames) {
        await db.execute('DROP TRIGGER IF EXISTS $trigger');
      }
      await db.update('payments', {
        'schedule_id': null,
      }, where: 'schedule_id = 0');
      await db.insert('app_meta', {
        'key': 'integrity_warning_foreign_key_migration_pending_v22',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    if (oldVersion < 23) {
      await _migrateLegacyLendingForeignKeys(db);
      await _ensureOfflineIntegrityIndexes(db);
    }

    if (oldVersion < 24) {
      await _migrateLegacyOperationalForeignKeys(db);
      await _ensureOfflineIntegrityIndexes(db);
    }

    if (oldVersion < 25) {
      await _migrateApplicationProductSnapshots(db);
    }

    if (oldVersion < 26) {
      await _ensureOfflineIntegrityIndexes(db);
    }

    if (oldVersion < 28) {
      await _unlinkAmbiguousCollectionTasks(db);
    }

    if (oldVersion < 30) {
      await _migrateCoreMoneyColumns(db);
    }

    if (oldVersion < 31) {
      await _redactPreGrtVoterIds(db);
    }

    if (oldVersion < 32) {
      await _ensureRecoveryEventsTable(db);
    }

    if (oldVersion < 33) {
      await _ensureGrievancesTable(db);
      await _ensureOperationalSeedData(db);
    }
  }

  Future<void> _redactPreGrtVoterIds(DatabaseExecutor db) async {
    final tables = await db.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type = 'table' AND name = 'pregrt_members'
    ''');
    if (tables.isEmpty) return;
    final columns = await db.rawQuery('PRAGMA table_info(pregrt_members)');
    if (!columns.any((column) => column['name'] == 'voter_id')) return;
    await db.execute('''
      UPDATE pregrt_members
      SET voter_id = NULLIF(
        substr(replace(replace(trim(voter_id), ' ', ''), '-', ''), -4),
        ''
      )
      WHERE voter_id IS NOT NULL AND length(trim(voter_id)) > 4
    ''');
  }

  Future<void> _migrateApplicationProductSnapshots(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(applications)');
    final existingColumns = columns
        .map((column) => column['name'] as String)
        .toSet();
    const snapshotColumns = <String, String>{
      'product_name_snapshot': 'TEXT',
      'method_snapshot': 'TEXT',
      'min_amt_paise_snapshot': 'INTEGER',
      'max_amt_paise_snapshot': 'INTEGER',
      'min_tenure_snapshot': 'INTEGER',
      'max_tenure_snapshot': 'INTEGER',
      'fee_pct_snapshot': 'REAL',
    };
    for (final entry in snapshotColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE applications ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
    await db.execute('''
      UPDATE applications
      SET product_name_snapshot = COALESCE(
            product_name_snapshot,
            (SELECT name FROM products WHERE products.id = applications.product_id)
          ),
          method_snapshot = COALESCE(
            method_snapshot,
            (SELECT lower(COALESCE(method, 'reducing')) FROM products
             WHERE products.id = applications.product_id)
          ),
          min_amt_paise_snapshot = COALESCE(
            min_amt_paise_snapshot,
            (SELECT min_amt_paise FROM products
             WHERE products.id = applications.product_id)
          ),
          max_amt_paise_snapshot = COALESCE(
            max_amt_paise_snapshot,
            (SELECT max_amt_paise FROM products
             WHERE products.id = applications.product_id)
          ),
          min_tenure_snapshot = COALESCE(
            min_tenure_snapshot,
            (SELECT min_tenure FROM products
             WHERE products.id = applications.product_id)
          ),
          max_tenure_snapshot = COALESCE(
            max_tenure_snapshot,
            (SELECT max_tenure FROM products
             WHERE products.id = applications.product_id)
          ),
          fee_pct_snapshot = COALESCE(
            fee_pct_snapshot,
            (SELECT fee_pct FROM products
             WHERE products.id = applications.product_id)
          )
      WHERE EXISTS (
        SELECT 1 FROM products WHERE products.id = applications.product_id
      )
    ''');
  }

  Future<void> _clearLegacyCloudConfiguration(DatabaseExecutor db) async {
    final tableColumns = await db.rawQuery(
      'PRAGMA table_info(cloud_connections)',
    );
    final availableColumns = tableColumns
        .map((column) => column['name'] as String)
        .toSet();
    if (availableColumns.isEmpty) return;

    const possibleSensitiveColumns = ['api_key', 'endpoint_url', 'project_ref'];
    final sensitiveColumns = possibleSensitiveColumns
        .where(availableColumns.contains)
        .toList();
    if (sensitiveColumns.isNotEmpty) {
      final hasStoredConfiguration = await db.rawQuery('''
        SELECT 1 FROM cloud_connections
        WHERE ${sensitiveColumns.map((column) => "($column IS NOT NULL AND trim($column) != '')").join(' OR ')}
        LIMIT 1
      ''');
      if (hasStoredConfiguration.isNotEmpty) {
        await db.execute('PRAGMA secure_delete = ON');
        await db.insert('app_meta', {
          'key': 'sensitive_data_v9_vacuum_required',
          'value': '1',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    final clearedValues = <String, Object?>{
      if (availableColumns.contains('api_key')) 'api_key': '',
      if (availableColumns.contains('endpoint_url')) 'endpoint_url': null,
      if (availableColumns.contains('project_ref')) 'project_ref': null,
      if (availableColumns.contains('status')) 'status': 'disconnected',
      if (availableColumns.contains('last_synced')) 'last_synced': null,
    };
    if (clearedValues.isNotEmpty) {
      await db.update('cloud_connections', clearedValues);
    }
  }

  Future<void> _protectLegacyBankAccounts(
    DatabaseExecutor db, {
    bool scrubLegacyPlaintext = false,
  }) async {
    final encryption = LocalSensitiveDataService();
    final rows = await db.query(
      'kyc_forms',
      columns: ['id', 'bank_acct', 'bank_acct_last4'],
    );
    for (final row in rows) {
      final storedValue = row['bank_acct']?.toString() ?? '';
      if (storedValue.isEmpty) {
        if (row['bank_acct_last4'] != null) {
          await db.update(
            'kyc_forms',
            {'bank_acct_last4': null},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
        continue;
      }

      final clearValue = await encryption.decrypt(storedValue);
      final protectedValue = await encryption.encrypt(clearValue);
      final lastFour = encryption.lastFour(clearValue);
      if (storedValue != protectedValue || row['bank_acct_last4'] != lastFour) {
        await db.update(
          'kyc_forms',
          {'bank_acct': protectedValue, 'bank_acct_last4': lastFour},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    if (scrubLegacyPlaintext) {
      await db.insert('app_meta', {
        'key': 'sensitive_data_v8_vacuum_required',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _completeSensitiveDataScrub(Database db) async {
    final pendingRows = await db.query(
      'app_meta',
      columns: ['key'],
      where: "key LIKE 'sensitive_data_%_vacuum_required'",
    );
    if (pendingRows.isEmpty) return;

    final pendingKeys = pendingRows.map((row) => row['key'] as String).toList();
    final warningKeys = pendingKeys.map((key) {
      final version = key
          .replaceFirst('sensitive_data_', '')
          .replaceFirst('_vacuum_required', '');
      return 'integrity_warning_sensitive_data_scrub_$version';
    }).toList();

    try {
      // Rebuild database pages after sensitive legacy values were cleared.
      await db.execute('VACUUM');
      for (final key in [...pendingKeys, ...warningKeys]) {
        await db.delete('app_meta', where: 'key = ?', whereArgs: [key]);
      }
    } catch (_) {
      for (final key in warningKeys) {
        await db.insert('app_meta', {
          'key': key,
          'value': '1',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      debugPrint('Sensitive data page cleanup remains pending.');
    }
  }

  Future<void> preparePortableBackupFile(
    String path, {
    required String databaseKey,
  }) async {
    final backupDb = await openEncryptedDatabaseFile(path, key: databaseKey);
    try {
      final columns = await backupDb.rawQuery('PRAGMA table_info(kyc_forms)');
      if (columns.isEmpty) return;
      if (!columns.any((column) => column['name'] == 'bank_acct_last4')) {
        await backupDb.execute(
          'ALTER TABLE kyc_forms ADD COLUMN bank_acct_last4 TEXT',
        );
      }
      await backupDb.execute('PRAGMA secure_delete = ON');
      final encryption = LocalSensitiveDataService();
      await backupDb.transaction((txn) async {
        final rows = await txn.query(
          'kyc_forms',
          columns: ['id', 'bank_acct', 'bank_acct_last4'],
        );
        for (final row in rows) {
          final storedValue = row['bank_acct']?.toString() ?? '';
          if (storedValue.isEmpty) continue;
          final clearValue = await encryption.decrypt(storedValue);
          final lastFour = encryption.lastFour(clearValue);
          if (storedValue != clearValue || row['bank_acct_last4'] != lastFour) {
            await txn.update(
              'kyc_forms',
              {'bank_acct': clearValue, 'bank_acct_last4': lastFour},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      });
      await backupDb.execute('VACUUM');
    } finally {
      await backupDb.close();
    }
  }

  Future<void> protectPortableBackupFile(
    String path, {
    required String sourceDatabaseKey,
  }) async {
    final destinationKey = await _getOrCreateDatabaseKey();
    final backupDb = await openEncryptedDatabaseFile(
      path,
      key: sourceDatabaseKey,
    );
    try {
      final columns = await backupDb.rawQuery('PRAGMA table_info(kyc_forms)');
      if (columns.isEmpty) return;
      if (!columns.any((column) => column['name'] == 'bank_acct_last4')) {
        await backupDb.execute(
          'ALTER TABLE kyc_forms ADD COLUMN bank_acct_last4 TEXT',
        );
      }
      await backupDb.execute('PRAGMA secure_delete = ON');
      await backupDb.transaction((txn) async {
        await _protectLegacyBankAccounts(txn);
      });
      await backupDb.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await backupDb.rawQuery('PRAGMA journal_mode = DELETE');
      await backupDb.execute('VACUUM');
      await backupDb.execute("PRAGMA rekey = '$destinationKey'");
      await backupDb.rawQuery('SELECT count(*) FROM sqlite_master');
    } finally {
      await backupDb.close();
    }
    await _validateEncryptedDatabaseFile(path, destinationKey);
  }

  /// Converts a legacy plaintext backup candidate into a destination-device
  /// encrypted database. Legacy portable backups may contain clear bank
  /// account values, so field protection is applied before the full DB copy.
  Future<void> encryptLegacyBackupFile(String path) async {
    final destinationKey = await _getOrCreateDatabaseKey();
    final sourceDb = await openDatabase(
      path,
      singleInstance: false,
      onConfigure: _configureDatabaseConnection,
    );
    final encryptedCandidate = File(
      '$path.encrypted_import_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final columns = await sourceDb.rawQuery('PRAGMA table_info(kyc_forms)');
      if (columns.isNotEmpty) {
        if (!columns.any((column) => column['name'] == 'bank_acct_last4')) {
          await sourceDb.execute(
            'ALTER TABLE kyc_forms ADD COLUMN bank_acct_last4 TEXT',
          );
        }
        await sourceDb.execute('PRAGMA secure_delete = ON');
        await sourceDb.transaction((txn) async {
          await _protectLegacyBankAccounts(txn);
        });
      }
      await sourceDb.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await sourceDb.rawQuery('PRAGMA journal_mode = DELETE');
      final encryptedUri = _encryptedFileUri(
        encryptedCandidate.path,
        destinationKey,
      );
      await sourceDb.execute(
        "VACUUM INTO '${encryptedUri.replaceAll("'", "''")}'",
      );
      await sourceDb.close();
      await _validateEncryptedDatabaseFile(
        encryptedCandidate.path,
        destinationKey,
      );
      final plaintextCandidate = File(path);
      await plaintextCandidate.delete();
      await encryptedCandidate.rename(path);
      await _validateEncryptedDatabaseFile(path, destinationKey);
    } finally {
      try {
        await sourceDb.close();
      } catch (_) {}
      if (await encryptedCandidate.exists()) {
        await encryptedCandidate.delete();
      }
    }
  }

  /// Add database constraints only when legacy rows are consistent. If an
  /// older installation already contains duplicate keys, preserve those rows
  /// and leave an app_meta warning for an administrator to review.
  Future<void> _migrateCoreMoneyColumns(DatabaseExecutor db) async {
    const columns = <String, Map<String, String>>{
      'applications': {
        'amount': 'amount_paise',
        'income': 'income_paise',
        'co_income': 'co_income_paise',
      },
      'approvals': {'amount': 'amount_paise'},
      'products': {'min_amt': 'min_amt_paise', 'max_amt': 'max_amt_paise'},
      'loans': {'principal': 'principal_paise', 'emi': 'emi_paise'},
      'schedule': {
        'emi': 'emi_paise',
        'principal': 'principal_paise',
        'interest': 'interest_paise',
        'balance': 'balance_paise',
      },
      'payments': {'amount': 'amount_paise'},
      'tasks': {'collected': 'collected_paise'},
      'employees': {'salary': 'salary_paise'},
      'app_extra': _appExtraMoneyColumns,
      'pregrt_members': {
        'annual_income': 'annual_income_paise',
        'loan_amount': 'loan_amount_paise',
      },
      'kyc_forms': {
        'annual_income': 'annual_income_paise',
        'current_debt': 'current_debt_paise',
        'co_income': 'co_income_paise',
      },
    };
    for (final tableEntry in columns.entries) {
      final tableColumns = await db.rawQuery(
        'PRAGMA table_info(${tableEntry.key})',
      );
      final existingColumns = tableColumns
          .map((column) => column['name'] as String)
          .toSet();
      for (final mapping in tableEntry.value.entries) {
        if (!existingColumns.contains(mapping.value)) {
          await db.execute(
            'ALTER TABLE ${tableEntry.key} ADD COLUMN ${mapping.value} INTEGER',
          );
        }
        await db.execute('''
          UPDATE ${tableEntry.key}
          SET ${mapping.value} = CAST(ROUND(${mapping.key} * 100) AS INTEGER)
          WHERE ${mapping.value} IS NULL
            AND ${mapping.key} IS NOT NULL
            AND ABS(${mapping.key} * 100 - ROUND(${mapping.key} * 100)) <= 0.000001
        ''');
      }
    }
  }

  Future<void> _ensureOfflineIntegrityIndexes(DatabaseExecutor db) async {
    await _ensureUniqueIndex(
      db,
      table: 'attendance',
      columns: ['user_id', 'day'],
      indexName: 'idx_attendance_user_day_unique',
      warningKey: 'integrity_warning_attendance_duplicates_v7',
    );
    await _ensureUniqueIndex(
      db,
      table: 'att_requests',
      columns: ['user_id', 'day'],
      indexName: 'idx_att_requests_pending_user_day_unique',
      warningKey: 'integrity_warning_attendance_request_duplicates_v25',
      whereClause: "status = 'pending'",
    );
    await _ensureUniqueIndex(
      db,
      table: 'schedule',
      columns: ['loan_id', 'no'],
      indexName: 'idx_schedule_loan_number_unique',
      warningKey: 'integrity_warning_schedule_duplicates_v7',
    );
    await _ensureUniqueIndex(
      db,
      table: 'users',
      columns: ['lower(username)'],
      indexName: 'idx_users_username_ci_unique',
      warningKey: 'integrity_warning_username_duplicates_v7',
    );
    await _ensureUniqueIndex(
      db,
      table: 'employees',
      columns: ['user_id'],
      indexName: 'idx_employees_user_unique',
      warningKey: 'integrity_warning_employee_user_duplicates_v7',
    );
    await _ensureUniqueIndex(
      db,
      table: 'payments',
      columns: ['schedule_id'],
      indexName: 'idx_payments_schedule_unique',
      warningKey: 'integrity_warning_payment_schedule_duplicates_v12',
      whereClause: 'schedule_id IS NOT NULL AND schedule_id > 0',
    );
    await _ensureUniqueIndex(
      db,
      table: 'loans',
      columns: ['application_id'],
      indexName: 'idx_loans_application_unique',
      warningKey: 'integrity_warning_loans_application_duplicates_v13',
    );
  }

  Future<void> _ensureRecoveryEventsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recovery_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT NOT NULL UNIQUE,
        action TEXT NOT NULL CHECK (
          action IN ('portable_backup_imported', 'database_recovery_restored')
        ),
        source_actor_user_id INTEGER NOT NULL,
        source_actor_username TEXT NOT NULL,
        source_actor_name TEXT NOT NULL,
        source_label TEXT NOT NULL,
        portable INTEGER NOT NULL CHECK (portable IN (0, 1)),
        occurred_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_recovery_events_no_update
      BEFORE UPDATE ON recovery_events
      BEGIN SELECT RAISE(ABORT, 'recovery events are immutable'); END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_recovery_events_no_delete
      BEFORE DELETE ON recovery_events
      BEGIN SELECT RAISE(ABORT, 'recovery events are immutable'); END
    ''');
  }

  Future<Map<String, int>> _readAutoincrementSequences(
    DatabaseExecutor db,
    List<String> tables,
  ) async {
    final placeholders = List.filled(tables.length, '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT name, seq FROM sqlite_sequence WHERE name IN ($placeholders)',
      tables,
    );
    return {for (final row in rows) row['name'] as String: row['seq'] as int};
  }

  Future<void> _restoreAutoincrementSequences(
    DatabaseExecutor db,
    Map<String, int> sequences,
  ) async {
    for (final entry in sequences.entries) {
      final rows = await db.query(
        'sqlite_sequence',
        columns: ['seq'],
        where: 'name = ?',
        whereArgs: [entry.key],
        limit: 1,
      );
      if (rows.isEmpty) {
        await db.insert('sqlite_sequence', {
          'name': entry.key,
          'seq': entry.value,
        });
      } else if ((rows.first['seq'] as int) < entry.value) {
        await db.update(
          'sqlite_sequence',
          {'seq': entry.value},
          where: 'name = ?',
          whereArgs: [entry.key],
        );
      }
    }
  }

  /// Rebuilds the six core lending tables only when their existing references
  /// are consistent. Invalid legacy rows remain untouched for admin review.
  /// The surrounding onUpgrade transaction makes the table swap atomic.
  Future<void> _migrateLegacyLendingForeignKeys(DatabaseExecutor db) async {
    const expectedForeignKeys = <String, int>{
      'applications': 3,
      'app_extra': 1,
      'approvals': 1,
      'loans': 4,
      'schedule': 1,
      'payments': 2,
    };
    var existingForeignKeys = true;
    for (final entry in expectedForeignKeys.entries) {
      final rows = await db.rawQuery('PRAGMA foreign_key_list(${entry.key})');
      if (rows.length < entry.value) {
        existingForeignKeys = false;
        break;
      }
    }
    if (existingForeignKeys) {
      await db.delete(
        'app_meta',
        where: 'key = ?',
        whereArgs: ['integrity_warning_foreign_key_orphans_v23'],
      );
      return;
    }

    const relationships = <(String, String, String)>[
      ('applications', 'customer_id', 'customers'),
      ('applications', 'product_id', 'products'),
      ('applications', 'agent_id', 'users'),
      ('app_extra', 'application_id', 'applications'),
      ('approvals', 'application_id', 'applications'),
      ('loans', 'application_id', 'applications'),
      ('loans', 'customer_id', 'customers'),
      ('loans', 'product_id', 'products'),
      ('loans', 'agent_id', 'users'),
      ('schedule', 'loan_id', 'loans'),
      ('payments', 'loan_id', 'loans'),
      ('payments', 'schedule_id', 'schedule'),
    ];
    var orphanCount = 0;
    for (final relation in relationships) {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS count
        FROM ${relation.$1} child
        LEFT JOIN ${relation.$3} parent ON parent.id = child.${relation.$2}
        WHERE child.${relation.$2} IS NOT NULL AND parent.id IS NULL
      ''');
      orphanCount += rows.first['count'] as int? ?? 0;
    }
    final inconsistentLoans = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM loans l
      JOIN applications a ON a.id = l.application_id
      WHERE COALESCE(a.customer_id, -1) != COALESCE(l.customer_id, -1)
        OR COALESCE(a.product_id, -1) != COALESCE(l.product_id, -1)
    ''');
    orphanCount += inconsistentLoans.first['count'] as int? ?? 0;
    final inconsistentPaymentSchedules = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM payments p
      JOIN schedule s ON s.id = p.schedule_id
      WHERE p.schedule_id > 0 AND s.loan_id != p.loan_id
    ''');
    orphanCount += inconsistentPaymentSchedules.first['count'] as int? ?? 0;
    if (orphanCount > 0) {
      await db.insert('app_meta', {
        'key': 'integrity_warning_foreign_key_orphans_v23',
        'value': '$orphanCount',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }
    await db.delete(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['integrity_warning_foreign_key_orphans_v23'],
    );

    final sequences = await _readAutoincrementSequences(
      db,
      expectedForeignKeys.keys.toList(),
    );

    await db.execute('PRAGMA defer_foreign_keys = ON');
    for (final trigger in _mfiIntegrityTriggerNames) {
      await db.execute('DROP TRIGGER IF EXISTS $trigger');
    }

    await db.execute('''
      CREATE TABLE applications_fk23 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        product_id INTEGER REFERENCES products(id) ON DELETE RESTRICT,
        amount REAL,
        amount_paise INTEGER,
        tenure INTEGER,
        rate REAL,
        purpose TEXT,
        income REAL,
        income_paise INTEGER,
        occupation TEXT,
        employer TEXT,
        co_name TEXT,
        co_phone TEXT,
        co_relation TEXT,
        co_income REAL,
        co_income_paise INTEGER,
        status TEXT,
        agent_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        branch TEXT,
        created TEXT,
        remarks TEXT,
        docs TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE app_extra_fk23 (
        application_id INTEGER PRIMARY KEY
          REFERENCES applications(id) ON DELETE RESTRICT,
        prev_loans TEXT,
        insurance_wanted TEXT,
        insurance_for TEXT,
        docs_deposited TEXT,
        docs_other TEXT,
        inc_agri REAL,
        inc_business REAL,
        inc_job REAL,
        inc_other REAL,
        exp_basic REAL,
        exp_education REAL,
        exp_festival REAL,
        exp_health REAL,
        exp_emi REAL,
        exp_other REAL,
        group_rec REAL,
        center_rec REAL,
        loan_cycle INTEGER,
        requested_amt REAL,
        income_total REAL,
        expense_total REAL,
        net_saving REAL,
        declaration INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE approvals_fk23 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        application_id INTEGER REFERENCES applications(id) ON DELETE RESTRICT,
        stage TEXT,
        by_user TEXT,
        by_role TEXT,
        amount REAL,
        amount_paise INTEGER,
        remarks TEXT,
        at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE loans_fk23 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        application_id INTEGER REFERENCES applications(id) ON DELETE RESTRICT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        product_id INTEGER REFERENCES products(id) ON DELETE RESTRICT,
        principal REAL,
        principal_paise INTEGER,
        rate REAL,
        tenure INTEGER,
        method TEXT,
        emi REAL,
        emi_paise INTEGER,
        start_date TEXT,
        status TEXT,
        closure_date TEXT,
        branch TEXT,
        agent_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        disbursement_ref TEXT,
        disbursement_channel TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE schedule_fk23 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER REFERENCES loans(id) ON DELETE RESTRICT,
        no INTEGER,
        due_date TEXT,
        emi REAL,
        emi_paise INTEGER,
        principal REAL,
        principal_paise INTEGER,
        interest REAL,
        interest_paise INTEGER,
        balance REAL,
        balance_paise INTEGER,
        paid INTEGER DEFAULT 0,
        paid_on TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE payments_fk23 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER REFERENCES loans(id) ON DELETE RESTRICT,
        schedule_id INTEGER REFERENCES schedule(id) ON DELETE RESTRICT,
        amount REAL,
        amount_paise INTEGER,
        channel TEXT,
        ref TEXT,
        at TEXT,
        operation_id TEXT UNIQUE
      )
    ''');

    for (final table in const [
      'applications',
      'app_extra',
      'approvals',
      'loans',
      'schedule',
      'payments',
    ]) {
      await db.execute('INSERT INTO ${table}_fk23 SELECT * FROM $table');
    }
    for (final table in const [
      'payments',
      'schedule',
      'loans',
      'approvals',
      'app_extra',
      'applications',
    ]) {
      await db.execute('DROP TABLE $table');
    }
    for (final table in const [
      'applications',
      'app_extra',
      'approvals',
      'loans',
      'schedule',
      'payments',
    ]) {
      await db.execute('ALTER TABLE ${table}_fk23 RENAME TO $table');
    }
    await _restoreAutoincrementSequences(db, sequences);
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_schedule_due_unpaid
      ON schedule(loan_id, paid, due_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_applications_status_created
      ON applications(status, created)
    ''');
    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    if (violations.isNotEmpty) {
      throw StateError('The lending-table foreign-key migration failed.');
    }
    await db.delete(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['integrity_warning_foreign_key_orphans_v23'],
    );
  }

  /// Adds the remaining operational foreign keys only when every existing
  /// relationship can be preserved. The copy-and-swap runs within the schema
  /// upgrade transaction; orphaned records are left in their original tables.
  Future<void> _migrateLegacyOperationalForeignKeys(DatabaseExecutor db) async {
    const coreForeignKeys = <String, int>{
      'applications': 3,
      'app_extra': 1,
      'approvals': 1,
      'loans': 4,
      'schedule': 1,
      'payments': 2,
    };
    for (final entry in coreForeignKeys.entries) {
      final rows = await db.rawQuery('PRAGMA foreign_key_list(${entry.key})');
      if (rows.length < entry.value) return;
    }

    const operationalForeignKeys = <String, int>{
      'users': 1,
      'employees': 2,
      'customers': 1,
      'comm_logs': 1,
      'tasks': 3,
      'attendance': 1,
      'att_requests': 2,
      'pregrt': 1,
      'pregrt_members': 2,
      'kyc_forms': 3,
      'audit_log': 1,
      'mandates': 1,
      'leaves': 1,
      'perf': 1,
      'sync_log': 1,
    };
    var alreadyMigrated = true;
    for (final entry in operationalForeignKeys.entries) {
      final rows = await db.rawQuery('PRAGMA foreign_key_list(${entry.key})');
      if (rows.length < entry.value) {
        alreadyMigrated = false;
        break;
      }
    }
    if (alreadyMigrated) {
      await db.delete(
        'app_meta',
        where: 'key = ?',
        whereArgs: ['integrity_warning_foreign_key_operational_orphans_v24'],
      );
      return;
    }

    const relationships = <(String, String, String)>[
      ('users', 'customer_id', 'customers'),
      ('employees', 'user_id', 'users'),
      ('employees', 'manager_id', 'employees'),
      ('customers', 'agent_id', 'users'),
      ('comm_logs', 'customer_id', 'customers'),
      ('tasks', 'customer_id', 'customers'),
      ('tasks', 'loan_id', 'loans'),
      ('tasks', 'officer_id', 'users'),
      ('attendance', 'user_id', 'users'),
      ('att_requests', 'user_id', 'users'),
      ('att_requests', 'approver_id', 'users'),
      ('pregrt', 'agent_id', 'users'),
      ('pregrt_members', 'pregrt_id', 'pregrt'),
      ('pregrt_members', 'customer_id', 'customers'),
      ('kyc_forms', 'customer_id', 'customers'),
      ('kyc_forms', 'created_by', 'users'),
      ('kyc_forms', 'updated_by', 'users'),
      ('audit_log', 'actor_user_id', 'users'),
      ('mandates', 'loan_id', 'loans'),
      ('leaves', 'user_id', 'users'),
      ('perf', 'user_id', 'users'),
      ('sync_log', 'user_id', 'users'),
    ];
    var orphanCount = 0;
    for (final relation in relationships) {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS count
        FROM ${relation.$1} child
        LEFT JOIN ${relation.$3} parent ON parent.id = child.${relation.$2}
        WHERE child.${relation.$2} IS NOT NULL AND parent.id IS NULL
      ''');
      orphanCount += rows.first['count'] as int? ?? 0;
    }
    if (orphanCount > 0) {
      await db.insert('app_meta', {
        'key': 'integrity_warning_foreign_key_operational_orphans_v24',
        'value': '$orphanCount',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }
    await db.delete(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['integrity_warning_foreign_key_operational_orphans_v24'],
    );

    final sequences = await _readAutoincrementSequences(
      db,
      operationalForeignKeys.keys.toList(),
    );

    await db.execute('PRAGMA defer_foreign_keys = ON');
    for (final trigger in _mfiIntegrityTriggerNames) {
      await db.execute('DROP TRIGGER IF EXISTS $trigger');
    }

    await db.execute('''
      CREATE TABLE users_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password_hash TEXT,
        auth_status TEXT NOT NULL DEFAULT 'active',
        failed_login_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        name TEXT,
        role TEXT,
        branch TEXT,
        phone TEXT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT
          DEFERRABLE INITIALLY DEFERRED,
        lat REAL,
        lng REAL,
        loc_at TEXT,
        must_change INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE employees_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        name TEXT,
        designation TEXT,
        branch TEXT,
        manager_id INTEGER REFERENCES employees(id) ON DELETE RESTRICT,
        phone TEXT,
        email TEXT,
        joined TEXT,
        status TEXT,
        bg_check TEXT,
        docs TEXT,
        salary REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE customers_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        phone TEXT,
        dob TEXT,
        address TEXT,
        branch TEXT,
        agent_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        stage TEXT,
        aadhaar TEXT,
        pan TEXT,
        voter TEXT,
        kyc_status TEXT DEFAULT 'pending',
        wa_verified INTEGER DEFAULT 0,
        wa_otp TEXT,
        created TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE comm_logs_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        channel TEXT,
        note TEXT,
        by_name TEXT,
        at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        loan_id INTEGER REFERENCES loans(id) ON DELETE RESTRICT,
        ttype TEXT,
        lat REAL,
        lng REAL,
        due_date TEXT,
        officer_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        status TEXT DEFAULT 'open',
        collected REAL DEFAULT 0,
        collected_paise INTEGER DEFAULT 0,
        notes TEXT,
        done_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE attendance_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        day TEXT,
        in_time TEXT,
        out_time TEXT,
        lat REAL,
        lng REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE att_requests_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        branch TEXT,
        day TEXT,
        in_time TEXT,
        out_time TEXT,
        reason TEXT,
        status TEXT DEFAULT 'pending',
        approver_role TEXT,
        approver_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        requested_at TEXT,
        decided_by TEXT,
        decided_at TEXT,
        remarks TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE pregrt_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch TEXT,
        center_no TEXT,
        group_no TEXT,
        village TEXT,
        district TEXT,
        form_date TEXT,
        pso_name TEXT,
        pso_empid TEXT,
        bm_name TEXT,
        bm_empid TEXT,
        leader_knows_duties TEXT,
        notes TEXT,
        agent_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        status TEXT DEFAULT 'draft',
        created_at TEXT,
        verified_by TEXT,
        verified_on TEXT,
        review_remarks TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE pregrt_members_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pregrt_id INTEGER REFERENCES pregrt(id) ON DELETE RESTRICT,
        sno INTEGER,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        name TEXT,
        husband_name TEXT,
        age INTEGER,
        voter_id TEXT,
        aadhaar4 TEXT,
        family_in_group TEXT,
        house_type TEXT,
        land_ha REAL,
        livestock TEXT,
        annual_income REAL,
        annual_income_paise INTEGER,
        family_size INTEGER,
        category TEXT,
        loan_amount REAL,
        loan_amount_paise INTEGER,
        purpose TEXT,
        frequency TEXT,
        instalments INTEGER,
        c_meeting INTEGER,
        c_joint INTEGER,
        c_fee INTEGER,
        c_rate INTEGER,
        c_insurance INTEGER,
        c_company INTEGER,
        c_group INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE kyc_forms_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER UNIQUE REFERENCES customers(id) ON DELETE RESTRICT,
        created_by INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        updated_by INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        created_at TEXT,
        updated_at TEXT,
        form_date TEXT,
        center_no TEXT,
        group_no TEXT,
        guardian_type TEXT,
        guardian_name TEXT,
        education TEXT,
        religion TEXT,
        category TEXT,
        house_no TEXT,
        village TEXT,
        post_office TEXT,
        district TEXT,
        state TEXT,
        pincode TEXT,
        family TEXT,
        house_type TEXT,
        land_ha REAL,
        livestock TEXT,
        bank_name TEXT,
        bank_acct TEXT,
        bank_acct_last4 TEXT,
        passbook_name TEXT,
        poverty_line TEXT,
        dist_center_m REAL,
        dist_branch_km REAL,
        relative_in_center TEXT,
        relative_name TEXT,
        annual_income REAL,
        annual_income_paise INTEGER,
        other_loans INTEGER,
        current_debt REAL,
        current_debt_paise INTEGER,
        repay_freq TEXT,
        photo TEXT,
        h_name TEXT,
        h_father TEXT,
        h_dob TEXT,
        h_address TEXT,
        h_photo TEXT,
        consent_given INTEGER DEFAULT 0,
        consent_date TEXT,
        declaration INTEGER DEFAULT 0,
        bureau_consent INTEGER DEFAULT 0,
        address_verified INTEGER DEFAULT 0,
        verified_by TEXT,
        verified_on TEXT,
        verify_remarks TEXT,
        signed_copy TEXT,
        co_name TEXT,
        co_phone TEXT,
        co_relation TEXT,
        co_income REAL,
        co_income_paise INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_log_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT NOT NULL UNIQUE,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        actor_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        actor_role TEXT NOT NULL,
        actor_name TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await db.execute('''
      CREATE TABLE mandates_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER REFERENCES loans(id) ON DELETE RESTRICT,
        mtype TEXT,
        bank TEXT,
        acct_last4 TEXT,
        status TEXT,
        created TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE leaves_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        from_d TEXT,
        to_d TEXT,
        reason TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');
    await db.execute('''
      CREATE TABLE perf_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        period TEXT,
        rating INTEGER,
        notes TEXT,
        by_name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_log_fk24 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        payload TEXT,
        captured_at TEXT,
        synced_at TEXT
      )
    ''');

    const tables = [
      'users',
      'employees',
      'customers',
      'comm_logs',
      'tasks',
      'attendance',
      'att_requests',
      'pregrt',
      'pregrt_members',
      'kyc_forms',
      'audit_log',
      'mandates',
      'leaves',
      'perf',
      'sync_log',
    ];
    for (final table in tables) {
      await db.execute('INSERT INTO ${table}_fk24 SELECT * FROM $table');
    }
    for (final table in const [
      'tasks',
      'pregrt_members',
      'kyc_forms',
      'comm_logs',
      'audit_log',
      'mandates',
      'attendance',
      'att_requests',
      'leaves',
      'perf',
      'sync_log',
      'employees',
      'customers',
      'pregrt',
      'users',
    ]) {
      await db.execute('DROP TABLE $table');
    }
    for (final table in const [
      'users',
      'employees',
      'customers',
      'comm_logs',
      'tasks',
      'attendance',
      'att_requests',
      'pregrt',
      'pregrt_members',
      'kyc_forms',
      'audit_log',
      'mandates',
      'leaves',
      'perf',
      'sync_log',
    ]) {
      await db.execute('ALTER TABLE ${table}_fk24 RENAME TO $table');
    }
    await _restoreAutoincrementSequences(db, sequences);
    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    if (violations.isNotEmpty) {
      throw StateError('The operational foreign-key migration failed.');
    }
    await db.delete(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['integrity_warning_foreign_key_operational_orphans_v24'],
    );
  }

  /// Relationship triggers protect writes on legacy databases whose orphaned
  /// rows prevent the table rebuild from adding SQL foreign keys.
  Future<void> _ensureMfiReferenceTriggers(Database db) async {
    final triggers = <String>[
      '''
      CREATE TRIGGER IF NOT EXISTS trg_applications_refs_insert
      BEFORE INSERT ON applications
      WHEN NEW.customer_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM customers WHERE id = NEW.customer_id
      ) OR NEW.product_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM products WHERE id = NEW.product_id
      )
      BEGIN SELECT RAISE(ABORT, 'application reference is missing'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_applications_refs_update
      BEFORE UPDATE OF customer_id, product_id ON applications
      WHEN NEW.customer_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM customers WHERE id = NEW.customer_id
      ) OR NEW.product_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM products WHERE id = NEW.product_id
      ) OR EXISTS (
        SELECT 1 FROM loans l
        WHERE l.application_id = OLD.id
          AND (COALESCE(l.customer_id, -1) != NEW.customer_id
            OR COALESCE(l.product_id, -1) != NEW.product_id)
      )
      BEGIN SELECT RAISE(ABORT, 'application reference is missing'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_applications_status_transition
      BEFORE UPDATE OF status ON applications
      WHEN lower(trim(COALESCE(NEW.status, ''))) !=
           lower(trim(COALESCE(OLD.status, '')))
       AND NOT (
         (lower(trim(COALESCE(OLD.status, ''))) = 'submitted'
           AND lower(trim(COALESCE(NEW.status, ''))) = 'under_review')
         OR (lower(trim(COALESCE(OLD.status, ''))) = 'under_review'
           AND lower(trim(COALESCE(NEW.status, ''))) IN ('approved', 'rejected'))
         OR (lower(trim(COALESCE(OLD.status, ''))) = 'approved'
           AND lower(trim(COALESCE(NEW.status, ''))) = 'sanctioned')
         OR (lower(trim(COALESCE(OLD.status, ''))) = 'sanctioned'
           AND lower(trim(COALESCE(NEW.status, ''))) = 'disbursed')
       )
      BEGIN SELECT RAISE(ABORT, 'application status transition is invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_loans_refs_insert
      BEFORE INSERT ON loans
      WHEN NEW.application_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM applications WHERE id = NEW.application_id
      ) OR NEW.customer_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM customers WHERE id = NEW.customer_id
      ) OR NEW.product_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM products WHERE id = NEW.product_id
      ) OR NOT EXISTS (
        SELECT 1 FROM applications
        WHERE id = NEW.application_id
          AND customer_id = NEW.customer_id
          AND product_id = NEW.product_id
      )
      BEGIN SELECT RAISE(ABORT, 'loan reference is missing'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_loans_refs_update
      BEFORE UPDATE OF id, application_id, customer_id, product_id ON loans
      WHEN NEW.application_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM applications WHERE id = NEW.application_id
      ) OR NEW.customer_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM customers WHERE id = NEW.customer_id
      ) OR NEW.product_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM products WHERE id = NEW.product_id
      ) OR NOT EXISTS (
        SELECT 1 FROM applications
        WHERE id = NEW.application_id
          AND customer_id = NEW.customer_id
          AND product_id = NEW.product_id
      ) OR ((NEW.id IS NOT OLD.id OR NEW.application_id IS NOT OLD.application_id
          OR NEW.customer_id IS NOT OLD.customer_id OR NEW.product_id IS NOT OLD.product_id)
          AND (EXISTS (SELECT 1 FROM schedule WHERE loan_id = OLD.id)
            OR EXISTS (SELECT 1 FROM payments WHERE loan_id = OLD.id)))
      BEGIN SELECT RAISE(ABORT, 'loan reference is missing'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_schedule_loan_insert
      BEFORE INSERT ON schedule
      WHEN NEW.loan_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM loans WHERE id = NEW.loan_id
      )
      BEGIN SELECT RAISE(ABORT, 'schedule loan is missing'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_schedule_loan_update
      BEFORE UPDATE OF id, loan_id ON schedule
      WHEN NEW.loan_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM loans WHERE id = NEW.loan_id
      ) OR EXISTS (
        SELECT 1 FROM payments p WHERE p.schedule_id = OLD.id
          AND (NEW.id IS NOT OLD.id OR NEW.loan_id IS NOT OLD.loan_id)
      )
      BEGIN SELECT RAISE(ABORT, 'schedule loan is missing'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_payments_refs_insert
      BEFORE INSERT ON payments
      WHEN NEW.loan_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM loans WHERE id = NEW.loan_id
      ) OR (NEW.schedule_id IS NOT NULL AND NEW.schedule_id < 0)
        OR (NEW.schedule_id IS NOT NULL AND NEW.schedule_id > 0 AND NOT EXISTS (
        SELECT 1 FROM schedule
        WHERE id = NEW.schedule_id AND loan_id = NEW.loan_id
      ))
      BEGIN SELECT RAISE(ABORT, 'payment reference is missing'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_payments_refs_update
      BEFORE UPDATE OF loan_id, schedule_id ON payments
      WHEN NEW.loan_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM loans WHERE id = NEW.loan_id
      ) OR (NEW.schedule_id IS NOT NULL AND NEW.schedule_id < 0)
        OR (NEW.schedule_id IS NOT NULL AND NEW.schedule_id > 0 AND NOT EXISTS (
        SELECT 1 FROM schedule
        WHERE id = NEW.schedule_id AND loan_id = NEW.loan_id
      ))
      BEGIN SELECT RAISE(ABORT, 'payment reference is missing'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_customer_delete_refs
      BEFORE DELETE ON customers
      WHEN EXISTS (SELECT 1 FROM applications WHERE customer_id = OLD.id)
        OR EXISTS (SELECT 1 FROM loans WHERE customer_id = OLD.id)
      BEGIN SELECT RAISE(ABORT, 'customer has financial records'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_product_delete_refs
      BEFORE DELETE ON products
      WHEN EXISTS (SELECT 1 FROM applications WHERE product_id = OLD.id)
        OR EXISTS (SELECT 1 FROM loans WHERE product_id = OLD.id)
      BEGIN SELECT RAISE(ABORT, 'product has financial records'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_application_delete_refs
      BEFORE DELETE ON applications
      WHEN EXISTS (SELECT 1 FROM loans WHERE application_id = OLD.id)
        OR EXISTS (SELECT 1 FROM approvals WHERE application_id = OLD.id)
        OR EXISTS (SELECT 1 FROM app_extra WHERE application_id = OLD.id)
      BEGIN SELECT RAISE(ABORT, 'application has dependent records'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_loan_delete_refs
      BEFORE DELETE ON loans
      WHEN EXISTS (SELECT 1 FROM schedule WHERE loan_id = OLD.id)
        OR EXISTS (SELECT 1 FROM payments WHERE loan_id = OLD.id)
      BEGIN SELECT RAISE(ABORT, 'loan has repayment records'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_schedule_delete_refs
      BEFORE DELETE ON schedule
      WHEN EXISTS (SELECT 1 FROM payments WHERE schedule_id = OLD.id)
      BEGIN SELECT RAISE(ABORT, 'installment has payment records'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_audit_log_no_update
      BEFORE UPDATE ON audit_log
      BEGIN SELECT RAISE(ABORT, 'audit events are append only'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_audit_log_no_delete
      BEFORE DELETE ON audit_log
      BEGIN SELECT RAISE(ABORT, 'audit events are append only'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_approvals_no_update
      BEFORE UPDATE ON approvals
      BEGIN SELECT RAISE(ABORT, 'approval events are append only'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_approvals_no_delete
      BEFORE DELETE ON approvals
      BEGIN SELECT RAISE(ABORT, 'approval events are append only'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_approvals_amount_insert
      BEFORE INSERT ON approvals
      WHEN NEW.amount IS NULL OR NEW.amount <= 0
        OR NEW.amount_paise IS NULL
        OR NEW.amount_paise != CAST(ROUND(NEW.amount * 100) AS INTEGER)
        OR ABS(NEW.amount * 100 - ROUND(NEW.amount * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'approval amount is invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_products_amounts_insert
      BEFORE INSERT ON products
      WHEN NEW.min_amt IS NULL OR NEW.min_amt <= 0
        OR NEW.min_amt_paise IS NULL
        OR NEW.min_amt_paise != CAST(ROUND(NEW.min_amt * 100) AS INTEGER)
        OR ABS(NEW.min_amt * 100 - ROUND(NEW.min_amt * 100)) > 0.000001
        OR NEW.max_amt IS NULL OR NEW.max_amt < NEW.min_amt
        OR NEW.max_amt_paise IS NULL
        OR NEW.max_amt_paise != CAST(ROUND(NEW.max_amt * 100) AS INTEGER)
        OR ABS(NEW.max_amt * 100 - ROUND(NEW.max_amt * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'loan product amount limits are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_products_amounts_update
      BEFORE UPDATE OF min_amt, min_amt_paise, max_amt, max_amt_paise ON products
      WHEN NEW.min_amt IS NULL OR NEW.min_amt <= 0
        OR NEW.min_amt_paise IS NULL
        OR NEW.min_amt_paise != CAST(ROUND(NEW.min_amt * 100) AS INTEGER)
        OR ABS(NEW.min_amt * 100 - ROUND(NEW.min_amt * 100)) > 0.000001
        OR NEW.max_amt IS NULL OR NEW.max_amt < NEW.min_amt
        OR NEW.max_amt_paise IS NULL
        OR NEW.max_amt_paise != CAST(ROUND(NEW.max_amt * 100) AS INTEGER)
        OR ABS(NEW.max_amt * 100 - ROUND(NEW.max_amt * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'loan product amount limits are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_kyc_money_insert
      BEFORE INSERT ON kyc_forms
      WHEN NEW.annual_income IS NULL OR NEW.annual_income <= 0
        OR NEW.annual_income_paise IS NULL
        OR NEW.annual_income_paise != CAST(ROUND(NEW.annual_income * 100) AS INTEGER)
        OR ABS(NEW.annual_income * 100 - ROUND(NEW.annual_income * 100)) > 0.000001
        OR (NEW.current_debt IS NULL AND NEW.current_debt_paise IS NOT NULL)
        OR (NEW.current_debt IS NOT NULL AND (
          NEW.current_debt < 0 OR NEW.current_debt_paise IS NULL
          OR NEW.current_debt_paise != CAST(ROUND(NEW.current_debt * 100) AS INTEGER)
          OR ABS(NEW.current_debt * 100 - ROUND(NEW.current_debt * 100)) > 0.000001
        ))
        OR (NEW.co_income IS NULL AND NEW.co_income_paise IS NOT NULL)
        OR (NEW.co_income IS NOT NULL AND (
          NEW.co_income < 0 OR NEW.co_income_paise IS NULL
          OR NEW.co_income_paise != CAST(ROUND(NEW.co_income * 100) AS INTEGER)
          OR ABS(NEW.co_income * 100 - ROUND(NEW.co_income * 100)) > 0.000001
        ))
      BEGIN SELECT RAISE(ABORT, 'KYC money values are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_kyc_money_update
      BEFORE UPDATE OF annual_income, annual_income_paise,
        current_debt, current_debt_paise, co_income, co_income_paise ON kyc_forms
      WHEN NEW.annual_income IS NULL OR NEW.annual_income <= 0
        OR NEW.annual_income_paise IS NULL
        OR NEW.annual_income_paise != CAST(ROUND(NEW.annual_income * 100) AS INTEGER)
        OR ABS(NEW.annual_income * 100 - ROUND(NEW.annual_income * 100)) > 0.000001
        OR (NEW.current_debt IS NULL AND NEW.current_debt_paise IS NOT NULL)
        OR (NEW.current_debt IS NOT NULL AND (
          NEW.current_debt < 0 OR NEW.current_debt_paise IS NULL
          OR NEW.current_debt_paise != CAST(ROUND(NEW.current_debt * 100) AS INTEGER)
          OR ABS(NEW.current_debt * 100 - ROUND(NEW.current_debt * 100)) > 0.000001
        ))
        OR (NEW.co_income IS NULL AND NEW.co_income_paise IS NOT NULL)
        OR (NEW.co_income IS NOT NULL AND (
          NEW.co_income < 0 OR NEW.co_income_paise IS NULL
          OR NEW.co_income_paise != CAST(ROUND(NEW.co_income * 100) AS INTEGER)
          OR ABS(NEW.co_income * 100 - ROUND(NEW.co_income * 100)) > 0.000001
        ))
      BEGIN SELECT RAISE(ABORT, 'KYC money values are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_tasks_collected_insert
      BEFORE INSERT ON tasks
      WHEN NEW.collected IS NULL OR NEW.collected < 0
        OR NEW.collected_paise IS NULL
        OR NEW.collected_paise != CAST(ROUND(NEW.collected * 100) AS INTEGER)
        OR ABS(NEW.collected * 100 - ROUND(NEW.collected * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'task collection amount is invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_tasks_collected_update
      BEFORE UPDATE OF collected, collected_paise ON tasks
      WHEN NEW.collected IS NULL OR NEW.collected < 0
        OR NEW.collected_paise IS NULL
        OR NEW.collected_paise != CAST(ROUND(NEW.collected * 100) AS INTEGER)
        OR ABS(NEW.collected * 100 - ROUND(NEW.collected * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'task collection amount is invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_pregrt_member_money_insert
      BEFORE INSERT ON pregrt_members
      WHEN NEW.annual_income IS NULL OR NEW.annual_income <= 0
        OR NEW.annual_income_paise IS NULL
        OR NEW.annual_income_paise != CAST(ROUND(NEW.annual_income * 100) AS INTEGER)
        OR ABS(NEW.annual_income * 100 - ROUND(NEW.annual_income * 100)) > 0.000001
        OR NEW.loan_amount IS NULL OR NEW.loan_amount <= 0
        OR NEW.loan_amount_paise IS NULL
        OR NEW.loan_amount_paise != CAST(ROUND(NEW.loan_amount * 100) AS INTEGER)
        OR ABS(NEW.loan_amount * 100 - ROUND(NEW.loan_amount * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'Pre-GRT member money values are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_pregrt_member_money_update
      BEFORE UPDATE OF annual_income, annual_income_paise,
        loan_amount, loan_amount_paise ON pregrt_members
      WHEN NEW.annual_income IS NULL OR NEW.annual_income <= 0
        OR NEW.annual_income_paise IS NULL
        OR NEW.annual_income_paise != CAST(ROUND(NEW.annual_income * 100) AS INTEGER)
        OR ABS(NEW.annual_income * 100 - ROUND(NEW.annual_income * 100)) > 0.000001
        OR NEW.loan_amount IS NULL OR NEW.loan_amount <= 0
        OR NEW.loan_amount_paise IS NULL
        OR NEW.loan_amount_paise != CAST(ROUND(NEW.loan_amount * 100) AS INTEGER)
        OR ABS(NEW.loan_amount * 100 - ROUND(NEW.loan_amount * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'Pre-GRT member money values are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_pregrt_member_voter_insert
      BEFORE INSERT ON pregrt_members
      WHEN NEW.voter_id IS NOT NULL AND length(trim(NEW.voter_id)) > 4
      BEGIN SELECT RAISE(ABORT, 'Pre-GRT voter ID must be masked'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_pregrt_member_voter_update
      BEFORE UPDATE OF voter_id ON pregrt_members
      WHEN NEW.voter_id IS NOT NULL AND length(trim(NEW.voter_id)) > 4
      BEGIN SELECT RAISE(ABORT, 'Pre-GRT voter ID must be masked'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_applications_terms_immutable
      BEFORE UPDATE OF customer_id, product_id, amount, amount_paise,
        tenure, rate, product_name_snapshot, method_snapshot,
        min_amt_paise_snapshot, max_amt_paise_snapshot,
        min_tenure_snapshot, max_tenure_snapshot, fee_pct_snapshot
      ON applications
      WHEN lower(trim(COALESCE(OLD.status, ''))) != 'draft'
       AND (
         NEW.customer_id IS NOT OLD.customer_id
         OR NEW.product_id IS NOT OLD.product_id
         OR CAST(ROUND(NEW.amount * 100) AS INTEGER) IS NOT
            CAST(ROUND(OLD.amount * 100) AS INTEGER)
         OR NEW.amount_paise IS NOT OLD.amount_paise
         OR NEW.tenure IS NOT OLD.tenure
         OR NEW.rate IS NOT OLD.rate
         OR NEW.product_name_snapshot IS NOT OLD.product_name_snapshot
         OR NEW.method_snapshot IS NOT OLD.method_snapshot
         OR NEW.min_amt_paise_snapshot IS NOT OLD.min_amt_paise_snapshot
         OR NEW.max_amt_paise_snapshot IS NOT OLD.max_amt_paise_snapshot
         OR NEW.min_tenure_snapshot IS NOT OLD.min_tenure_snapshot
         OR NEW.max_tenure_snapshot IS NOT OLD.max_tenure_snapshot
         OR NEW.fee_pct_snapshot IS NOT OLD.fee_pct_snapshot
       )
      BEGIN SELECT RAISE(ABORT, 'submitted application terms are immutable'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_applications_terms_insert
      BEFORE INSERT ON applications
      WHEN NEW.amount IS NULL OR NEW.amount <= 0
        OR NEW.amount_paise IS NULL
        OR NEW.amount_paise != CAST(ROUND(NEW.amount * 100) AS INTEGER)
        OR ABS(NEW.amount * 100 - ROUND(NEW.amount * 100)) > 0.000001
        OR NEW.income IS NULL OR NEW.income <= 0 OR NEW.income_paise IS NULL
        OR NEW.income_paise != CAST(ROUND(NEW.income * 100) AS INTEGER)
        OR ABS(NEW.income * 100 - ROUND(NEW.income * 100)) > 0.000001
        OR NEW.co_income IS NULL OR NEW.co_income < 0 OR NEW.co_income_paise IS NULL
        OR NEW.co_income_paise != CAST(ROUND(NEW.co_income * 100) AS INTEGER)
        OR ABS(NEW.co_income * 100 - ROUND(NEW.co_income * 100)) > 0.000001
        OR NEW.tenure IS NULL OR NEW.tenure <= 0
      BEGIN SELECT RAISE(ABORT, 'application terms are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_applications_terms_update
      BEFORE UPDATE OF amount, amount_paise, income, income_paise,
        co_income, co_income_paise, tenure ON applications
      WHEN NEW.amount IS NULL OR NEW.amount <= 0
        OR NEW.amount_paise IS NULL
        OR NEW.amount_paise != CAST(ROUND(NEW.amount * 100) AS INTEGER)
        OR ABS(NEW.amount * 100 - ROUND(NEW.amount * 100)) > 0.000001
        OR NEW.income IS NULL OR NEW.income <= 0 OR NEW.income_paise IS NULL
        OR NEW.income_paise != CAST(ROUND(NEW.income * 100) AS INTEGER)
        OR ABS(NEW.income * 100 - ROUND(NEW.income * 100)) > 0.000001
        OR NEW.co_income IS NULL OR NEW.co_income < 0 OR NEW.co_income_paise IS NULL
        OR NEW.co_income_paise != CAST(ROUND(NEW.co_income * 100) AS INTEGER)
        OR ABS(NEW.co_income * 100 - ROUND(NEW.co_income * 100)) > 0.000001
        OR NEW.tenure IS NULL OR NEW.tenure <= 0
      BEGIN SELECT RAISE(ABORT, 'application terms are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_loans_terms_insert
      BEFORE INSERT ON loans
      WHEN NEW.principal IS NULL OR NEW.principal <= 0
        OR NEW.principal_paise IS NULL
        OR NEW.principal_paise != CAST(ROUND(NEW.principal * 100) AS INTEGER)
        OR ABS(NEW.principal * 100 - ROUND(NEW.principal * 100)) > 0.000001
        OR NEW.rate IS NULL OR NEW.rate < 0
        OR NEW.tenure IS NULL OR NEW.tenure <= 0
        OR NEW.emi IS NULL OR NEW.emi <= 0
        OR NEW.emi_paise IS NULL
        OR NEW.emi_paise != CAST(ROUND(NEW.emi * 100) AS INTEGER)
        OR ABS(NEW.emi * 100 - ROUND(NEW.emi * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'loan terms are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_loans_terms_update
      BEFORE UPDATE OF principal, principal_paise, rate, tenure, emi, emi_paise ON loans
      WHEN NEW.principal IS NULL OR NEW.principal <= 0
        OR NEW.principal_paise IS NULL
        OR NEW.principal_paise != CAST(ROUND(NEW.principal * 100) AS INTEGER)
        OR ABS(NEW.principal * 100 - ROUND(NEW.principal * 100)) > 0.000001
        OR NEW.rate IS NULL OR NEW.rate < 0
        OR NEW.tenure IS NULL OR NEW.tenure <= 0
        OR NEW.emi IS NULL OR NEW.emi <= 0
        OR NEW.emi_paise IS NULL
        OR NEW.emi_paise != CAST(ROUND(NEW.emi * 100) AS INTEGER)
        OR ABS(NEW.emi * 100 - ROUND(NEW.emi * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'loan terms are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_schedule_values_insert
      BEFORE INSERT ON schedule
      WHEN NEW.no IS NULL OR NEW.no <= 0
        OR NEW.emi IS NULL OR NEW.emi <= 0
        OR NEW.emi_paise IS NULL
        OR NEW.emi_paise != CAST(ROUND(NEW.emi * 100) AS INTEGER)
        OR ABS(NEW.emi * 100 - ROUND(NEW.emi * 100)) > 0.000001
        OR NEW.principal IS NULL OR NEW.principal < 0
        OR NEW.principal_paise IS NULL
        OR NEW.principal_paise != CAST(ROUND(NEW.principal * 100) AS INTEGER)
        OR ABS(NEW.principal * 100 - ROUND(NEW.principal * 100)) > 0.000001
        OR NEW.interest IS NULL OR NEW.interest < 0
        OR NEW.interest_paise IS NULL
        OR NEW.interest_paise != CAST(ROUND(NEW.interest * 100) AS INTEGER)
        OR ABS(NEW.interest * 100 - ROUND(NEW.interest * 100)) > 0.000001
        OR NEW.balance IS NULL OR NEW.balance < 0
        OR NEW.balance_paise IS NULL
        OR NEW.balance_paise != CAST(ROUND(NEW.balance * 100) AS INTEGER)
        OR ABS(NEW.balance * 100 - ROUND(NEW.balance * 100)) > 0.000001
        OR NEW.paid IS NULL OR NEW.paid NOT IN (0, 1)
      BEGIN SELECT RAISE(ABORT, 'installment values are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_schedule_values_update
      BEFORE UPDATE OF no, emi, emi_paise, principal, principal_paise,
        interest, interest_paise, balance, balance_paise, paid ON schedule
      WHEN NEW.no IS NULL OR NEW.no <= 0
        OR NEW.emi IS NULL OR NEW.emi <= 0
        OR NEW.emi_paise IS NULL
        OR NEW.emi_paise != CAST(ROUND(NEW.emi * 100) AS INTEGER)
        OR ABS(NEW.emi * 100 - ROUND(NEW.emi * 100)) > 0.000001
        OR NEW.principal IS NULL OR NEW.principal < 0
        OR NEW.principal_paise IS NULL
        OR NEW.principal_paise != CAST(ROUND(NEW.principal * 100) AS INTEGER)
        OR ABS(NEW.principal * 100 - ROUND(NEW.principal * 100)) > 0.000001
        OR NEW.interest IS NULL OR NEW.interest < 0
        OR NEW.interest_paise IS NULL
        OR NEW.interest_paise != CAST(ROUND(NEW.interest * 100) AS INTEGER)
        OR ABS(NEW.interest * 100 - ROUND(NEW.interest * 100)) > 0.000001
        OR NEW.balance IS NULL OR NEW.balance < 0
        OR NEW.balance_paise IS NULL
        OR NEW.balance_paise != CAST(ROUND(NEW.balance * 100) AS INTEGER)
        OR ABS(NEW.balance * 100 - ROUND(NEW.balance * 100)) > 0.000001
        OR NEW.paid IS NULL OR NEW.paid NOT IN (0, 1)
      BEGIN SELECT RAISE(ABORT, 'installment values are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_payments_amount_insert
      BEFORE INSERT ON payments
      WHEN NEW.amount IS NULL OR NEW.amount <= 0
        OR NEW.amount_paise IS NULL
        OR NEW.amount_paise != CAST(ROUND(NEW.amount * 100) AS INTEGER)
        OR ABS(NEW.amount * 100 - ROUND(NEW.amount * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'payment amount is invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_payments_amount_update
      BEFORE UPDATE OF amount, amount_paise ON payments
      WHEN NEW.amount IS NULL OR NEW.amount <= 0
        OR NEW.amount_paise IS NULL
        OR NEW.amount_paise != CAST(ROUND(NEW.amount * 100) AS INTEGER)
        OR ABS(NEW.amount * 100 - ROUND(NEW.amount * 100)) > 0.000001
      BEGIN SELECT RAISE(ABORT, 'payment amount is invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_employee_salary_insert
      BEFORE INSERT ON employees
      WHEN (NEW.salary IS NULL AND NEW.salary_paise IS NOT NULL)
        OR (NEW.salary IS NOT NULL AND (
          NEW.salary <= 0 OR NEW.salary_paise IS NULL
          OR NEW.salary_paise != CAST(ROUND(NEW.salary * 100) AS INTEGER)
          OR ABS(NEW.salary * 100 - ROUND(NEW.salary * 100)) > 0.000001
        ))
      BEGIN SELECT RAISE(ABORT, 'employee salary is invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_employee_salary_update
      BEFORE UPDATE OF salary, salary_paise ON employees
      WHEN (NEW.salary IS NULL AND NEW.salary_paise IS NOT NULL)
        OR (NEW.salary IS NOT NULL AND (
          NEW.salary <= 0 OR NEW.salary_paise IS NULL
          OR NEW.salary_paise != CAST(ROUND(NEW.salary * 100) AS INTEGER)
          OR ABS(NEW.salary * 100 - ROUND(NEW.salary * 100)) > 0.000001
        ))
      BEGIN SELECT RAISE(ABORT, 'employee salary is invalid'); END
      ''',
    ];
    final appExtraUpdatedColumns = _appExtraMoneyColumns.entries
        .expand((entry) => [entry.key, entry.value])
        .join(', ');
    final appExtraInvalidValues = _appExtraMoneyInvalidCondition('NEW.');
    triggers.addAll([
      '''
      CREATE TRIGGER IF NOT EXISTS trg_app_extra_money_insert
      BEFORE INSERT ON app_extra
      WHEN $appExtraInvalidValues
      BEGIN SELECT RAISE(ABORT, 'application cashflow values are invalid'); END
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS trg_app_extra_money_update
      BEFORE UPDATE OF $appExtraUpdatedColumns ON app_extra
      WHEN $appExtraInvalidValues
      BEGIN SELECT RAISE(ABORT, 'application cashflow values are invalid'); END
      ''',
    ]);
    for (final trigger in triggers) {
      await db.execute(trigger);
    }
  }

  static const List<String> _mfiIntegrityTriggerNames = [
    'trg_applications_refs_insert',
    'trg_applications_refs_update',
    'trg_applications_status_transition',
    'trg_loans_refs_insert',
    'trg_loans_refs_update',
    'trg_schedule_loan_insert',
    'trg_schedule_loan_update',
    'trg_payments_refs_insert',
    'trg_payments_refs_update',
    'trg_customer_delete_refs',
    'trg_product_delete_refs',
    'trg_application_delete_refs',
    'trg_loan_delete_refs',
    'trg_schedule_delete_refs',
    'trg_audit_log_no_update',
    'trg_audit_log_no_delete',
    'trg_approvals_no_update',
    'trg_approvals_no_delete',
    'trg_approvals_amount_insert',
    'trg_products_amounts_insert',
    'trg_products_amounts_update',
    'trg_kyc_money_insert',
    'trg_kyc_money_update',
    'trg_tasks_collected_insert',
    'trg_tasks_collected_update',
    'trg_pregrt_member_money_insert',
    'trg_pregrt_member_money_update',
    'trg_pregrt_member_voter_insert',
    'trg_pregrt_member_voter_update',
    'trg_applications_terms_insert',
    'trg_applications_terms_update',
    'trg_applications_terms_immutable',
    'trg_loans_terms_insert',
    'trg_loans_terms_update',
    'trg_schedule_values_insert',
    'trg_schedule_values_update',
    'trg_payments_amount_insert',
    'trg_payments_amount_update',
    'trg_employee_salary_insert',
    'trg_employee_salary_update',
    'trg_app_extra_money_insert',
    'trg_app_extra_money_update',
  ];

  /// Reports legacy dangling references without deleting or silently repairing
  /// them. The next startup refreshes the counts after an administrator resolves
  /// records through the normal business workflow.
  Future<void> _refreshMfiReferenceWarnings(Database db) async {
    final checks = <String, String>{
      'integrity_warning_orphan_applications_customer_v13': '''
        SELECT COUNT(*) AS count FROM applications a
        LEFT JOIN customers c ON c.id = a.customer_id
        WHERE a.customer_id IS NULL OR c.id IS NULL
      ''',
      'integrity_warning_orphan_applications_product_v13': '''
        SELECT COUNT(*) AS count FROM applications a
        LEFT JOIN products p ON p.id = a.product_id
        WHERE a.product_id IS NULL OR p.id IS NULL
      ''',
      'integrity_warning_orphan_loans_v13': '''
        SELECT COUNT(*) AS count FROM loans l
        LEFT JOIN applications a ON a.id = l.application_id
        LEFT JOIN customers c ON c.id = l.customer_id
        LEFT JOIN products p ON p.id = l.product_id
        WHERE l.application_id IS NULL OR a.id IS NULL
          OR l.customer_id IS NULL OR c.id IS NULL
          OR l.product_id IS NULL OR p.id IS NULL
          OR COALESCE(a.customer_id, -1) != COALESCE(l.customer_id, -1)
          OR COALESCE(a.product_id, -1) != COALESCE(l.product_id, -1)
      ''',
      'integrity_warning_orphan_schedule_v13': '''
        SELECT COUNT(*) AS count FROM schedule s
        LEFT JOIN loans l ON l.id = s.loan_id
        WHERE s.loan_id IS NULL OR l.id IS NULL
      ''',
      'integrity_warning_orphan_payments_v13': '''
        SELECT COUNT(*) AS count FROM payments p
        LEFT JOIN loans l ON l.id = p.loan_id
        LEFT JOIN schedule s ON s.id = p.schedule_id
        WHERE p.loan_id IS NULL OR l.id IS NULL
          OR p.schedule_id < 0
          OR (p.schedule_id > 0 AND (s.id IS NULL OR s.loan_id != p.loan_id))
      ''',
      'integrity_warning_invalid_applications_v16': '''
        SELECT COUNT(*) AS count FROM applications
        WHERE amount IS NULL OR amount <= 0
          OR amount_paise IS NULL
          OR amount_paise != CAST(ROUND(amount * 100) AS INTEGER)
          OR ABS(amount * 100 - ROUND(amount * 100)) > 0.000001
          OR income IS NULL OR income <= 0 OR income_paise IS NULL
          OR income_paise != CAST(ROUND(income * 100) AS INTEGER)
          OR ABS(income * 100 - ROUND(income * 100)) > 0.000001
          OR co_income IS NULL OR co_income < 0 OR co_income_paise IS NULL
          OR co_income_paise != CAST(ROUND(co_income * 100) AS INTEGER)
          OR ABS(co_income * 100 - ROUND(co_income * 100)) > 0.000001
          OR tenure IS NULL OR tenure <= 0
      ''',
      'integrity_warning_invalid_kyc_income_v20': '''
        SELECT COUNT(*) AS count FROM kyc_forms
        WHERE annual_income IS NULL OR annual_income <= 0
          OR annual_income_paise IS NULL
          OR annual_income_paise != CAST(ROUND(annual_income * 100) AS INTEGER)
          OR ABS(annual_income * 100 - ROUND(annual_income * 100)) > 0.000001
          OR (current_debt IS NULL AND current_debt_paise IS NOT NULL)
          OR (current_debt IS NOT NULL AND (
            current_debt < 0 OR current_debt_paise IS NULL
            OR current_debt_paise != CAST(ROUND(current_debt * 100) AS INTEGER)
            OR ABS(current_debt * 100 - ROUND(current_debt * 100)) > 0.000001
          ))
          OR (co_income IS NULL AND co_income_paise IS NOT NULL)
          OR (co_income IS NOT NULL AND (
            co_income < 0 OR co_income_paise IS NULL
            OR co_income_paise != CAST(ROUND(co_income * 100) AS INTEGER)
            OR ABS(co_income * 100 - ROUND(co_income * 100)) > 0.000001
          ))
      ''',
      'integrity_warning_invalid_tasks_collected_v21': '''
        SELECT COUNT(*) AS count FROM tasks
        WHERE collected IS NULL OR collected < 0
          OR collected_paise IS NULL
          OR collected_paise != CAST(ROUND(collected * 100) AS INTEGER)
          OR ABS(collected * 100 - ROUND(collected * 100)) > 0.000001
      ''',
      'integrity_warning_invalid_pregrt_member_money_v21': '''
        SELECT COUNT(*) AS count FROM pregrt_members
        WHERE annual_income IS NULL OR annual_income <= 0
          OR annual_income_paise IS NULL
          OR annual_income_paise != CAST(ROUND(annual_income * 100) AS INTEGER)
          OR ABS(annual_income * 100 - ROUND(annual_income * 100)) > 0.000001
          OR loan_amount IS NULL OR loan_amount <= 0
          OR loan_amount_paise IS NULL
          OR loan_amount_paise != CAST(ROUND(loan_amount * 100) AS INTEGER)
          OR ABS(loan_amount * 100 - ROUND(loan_amount * 100)) > 0.000001
      ''',
      'integrity_warning_invalid_approvals_v19': '''
        SELECT COUNT(*) AS count FROM approvals
        WHERE amount IS NULL OR amount <= 0 OR amount_paise IS NULL
          OR amount_paise != CAST(ROUND(amount * 100) AS INTEGER)
          OR ABS(amount * 100 - ROUND(amount * 100)) > 0.000001
      ''',
      'integrity_warning_invalid_products_amounts_v21': '''
        SELECT COUNT(*) AS count FROM products
        WHERE min_amt IS NULL OR min_amt <= 0 OR min_amt_paise IS NULL
          OR min_amt_paise != CAST(ROUND(min_amt * 100) AS INTEGER)
          OR ABS(min_amt * 100 - ROUND(min_amt * 100)) > 0.000001
          OR max_amt IS NULL OR max_amt < min_amt OR max_amt_paise IS NULL
          OR max_amt_paise != CAST(ROUND(max_amt * 100) AS INTEGER)
          OR ABS(max_amt * 100 - ROUND(max_amt * 100)) > 0.000001
      ''',
      'integrity_warning_invalid_loans_v16': '''
        SELECT COUNT(*) AS count FROM loans
        WHERE principal IS NULL OR principal <= 0
          OR principal_paise IS NULL
          OR principal_paise != CAST(ROUND(principal * 100) AS INTEGER)
          OR ABS(principal * 100 - ROUND(principal * 100)) > 0.000001
          OR rate IS NULL OR rate < 0
          OR tenure IS NULL OR tenure <= 0
          OR emi IS NULL OR emi <= 0
          OR emi_paise IS NULL
          OR emi_paise != CAST(ROUND(emi * 100) AS INTEGER)
          OR ABS(emi * 100 - ROUND(emi * 100)) > 0.000001
      ''',
      'integrity_warning_invalid_schedule_v16': '''
        SELECT COUNT(*) AS count FROM schedule
        WHERE no IS NULL OR no <= 0
          OR emi IS NULL OR emi <= 0
          OR emi_paise IS NULL
          OR emi_paise != CAST(ROUND(emi * 100) AS INTEGER)
          OR ABS(emi * 100 - ROUND(emi * 100)) > 0.000001
          OR principal IS NULL OR principal < 0
          OR principal_paise IS NULL
          OR principal_paise != CAST(ROUND(principal * 100) AS INTEGER)
          OR ABS(principal * 100 - ROUND(principal * 100)) > 0.000001
          OR interest IS NULL OR interest < 0
          OR interest_paise IS NULL
          OR interest_paise != CAST(ROUND(interest * 100) AS INTEGER)
          OR ABS(interest * 100 - ROUND(interest * 100)) > 0.000001
          OR balance IS NULL OR balance < 0
          OR balance_paise IS NULL
          OR balance_paise != CAST(ROUND(balance * 100) AS INTEGER)
          OR ABS(balance * 100 - ROUND(balance * 100)) > 0.000001
          OR paid IS NULL OR paid NOT IN (0, 1)
      ''',
      'integrity_warning_invalid_payments_v16': '''
        SELECT COUNT(*) AS count FROM payments
        WHERE amount IS NULL OR amount <= 0
          OR amount_paise IS NULL
          OR amount_paise != CAST(ROUND(amount * 100) AS INTEGER)
          OR ABS(amount * 100 - ROUND(amount * 100)) > 0.000001
      ''',
      'integrity_warning_invalid_employee_salary_v29': '''
        SELECT COUNT(*) AS count FROM employees
        WHERE (salary IS NULL AND salary_paise IS NOT NULL)
          OR (salary IS NOT NULL AND (
            salary <= 0 OR salary_paise IS NULL
            OR salary_paise != CAST(ROUND(salary * 100) AS INTEGER)
            OR ABS(salary * 100 - ROUND(salary * 100)) > 0.000001
          ))
      ''',
      'integrity_warning_invalid_application_cashflow_v30':
          '''
        SELECT COUNT(*) AS count FROM app_extra
        WHERE ${_appExtraMoneyInvalidCondition('')}
      ''',
    };
    for (final entry in checks.entries) {
      final rows = await db.rawQuery(entry.value);
      final count = rows.first['count'] as int? ?? 0;
      if (count == 0) {
        await db.delete('app_meta', where: 'key = ?', whereArgs: [entry.key]);
      } else {
        await db.insert('app_meta', {
          'key': entry.key,
          'value': '$count',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> _ensureUniqueIndex(
    DatabaseExecutor db, {
    required String table,
    required List<String> columns,
    required String indexName,
    required String warningKey,
    String? whereClause,
  }) async {
    final groupColumns = columns.join(', ');
    final nonNullCondition = columns
        .map((column) {
          final nullableColumn = column.startsWith('lower(')
              ? column.substring('lower('.length, column.length - 1)
              : column;
          return '$nullableColumn IS NOT NULL';
        })
        .join(' AND ');
    final duplicateRows = await db.rawQuery('''
      SELECT COUNT(*) AS duplicate_groups
      FROM (
        SELECT 1 FROM $table
        WHERE $nonNullCondition${whereClause == null ? '' : ' AND ($whereClause)'}
        GROUP BY $groupColumns
        HAVING COUNT(*) > 1
      )
    ''');
    final duplicateGroups =
        duplicateRows.first['duplicate_groups'] as int? ?? 0;
    if (duplicateGroups > 0) {
      await db.insert('app_meta', {
        'key': warningKey,
        'value': '$duplicateGroups',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint(
        'Preserved $duplicateGroups duplicate key groups in $table; '
        'skipped unique index $indexName.',
      );
      return;
    }

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS $indexName ON $table($groupColumns)'
      '${whereClause == null ? '' : ' WHERE $whereClause'}',
    );
    await db.delete('app_meta', where: 'key = ?', whereArgs: [warningKey]);
  }

  Future<void> _unlinkAmbiguousCollectionTasks(DatabaseExecutor db) async {
    final affected = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM tasks
      WHERE lower(COALESCE(tasks.ttype, '')) = 'collection'
        AND lower(COALESCE(tasks.status, 'open')) != 'done'
        AND tasks.loan_id IS NOT NULL
        AND (
          NOT EXISTS (
            SELECT 1 FROM loans linked
            WHERE linked.id = tasks.loan_id
              AND linked.customer_id = tasks.customer_id
              AND linked.status = 'active'
          )
          OR (
            SELECT COUNT(*) FROM loans active
            WHERE active.customer_id = tasks.customer_id
              AND active.status = 'active'
          ) > 1
        )
    ''');
    final count = affected.first['count'] as int? ?? 0;
    if (count > 0) {
      await db.execute('''
        UPDATE tasks
        SET loan_id = NULL
        WHERE lower(COALESCE(tasks.ttype, '')) = 'collection'
          AND lower(COALESCE(tasks.status, 'open')) != 'done'
          AND tasks.loan_id IS NOT NULL
          AND (
            NOT EXISTS (
              SELECT 1 FROM loans linked
              WHERE linked.id = tasks.loan_id
                AND linked.customer_id = tasks.customer_id
                AND linked.status = 'active'
            )
            OR (
              SELECT COUNT(*) FROM loans active
              WHERE active.customer_id = tasks.customer_id
                AND active.status = 'active'
            ) > 1
          )
      ''');
    }
    await db.insert('app_meta', {
      'key': 'migration_v28_unlinked_ambiguous_collection_tasks',
      'value': '$count',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password_hash TEXT,
        auth_status TEXT NOT NULL DEFAULT 'active',
        failed_login_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        name TEXT,
        role TEXT,
        branch TEXT,
        phone TEXT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT
          DEFERRABLE INITIALLY DEFERRED,
        lat REAL,
        lng REAL,
        loc_at TEXT,
        must_change INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    await db.insert('app_meta', {
      'key': 'initial_setup_completed',
      'value': '0',
    });

    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        name TEXT,
        designation TEXT,
        branch TEXT,
        manager_id INTEGER REFERENCES employees(id) ON DELETE RESTRICT,
        phone TEXT,
        email TEXT,
        joined TEXT,
        status TEXT,
        bg_check TEXT,
        docs TEXT,
        salary REAL,
        salary_paise INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        phone TEXT,
        dob TEXT,
        address TEXT,
        branch TEXT,
        agent_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        stage TEXT,
        aadhaar TEXT,
        pan TEXT,
        voter TEXT,
        kyc_status TEXT DEFAULT 'pending',
        wa_verified INTEGER DEFAULT 0,
        wa_otp TEXT,
        created TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS comm_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        channel TEXT,
        note TEXT,
        by_name TEXT,
        at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        rate REAL,
        min_amt REAL,
        min_amt_paise INTEGER,
        max_amt REAL,
        max_amt_paise INTEGER,
        min_tenure INTEGER,
        max_tenure INTEGER,
        method TEXT,
        fee_pct REAL,
        active INTEGER DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS applications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        product_id INTEGER REFERENCES products(id) ON DELETE RESTRICT,
        amount REAL,
        amount_paise INTEGER,
        tenure INTEGER,
        rate REAL,
        purpose TEXT,
        income REAL,
        income_paise INTEGER,
        occupation TEXT,
        employer TEXT,
        co_name TEXT,
        co_phone TEXT,
        co_relation TEXT,
        co_income REAL,
        co_income_paise INTEGER,
        status TEXT,
        agent_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        branch TEXT,
        created TEXT,
        remarks TEXT,
        docs TEXT,
        product_name_snapshot TEXT,
        method_snapshot TEXT,
        min_amt_paise_snapshot INTEGER,
        max_amt_paise_snapshot INTEGER,
        min_tenure_snapshot INTEGER,
        max_tenure_snapshot INTEGER,
        fee_pct_snapshot REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_extra (
        application_id INTEGER PRIMARY KEY
          REFERENCES applications(id) ON DELETE RESTRICT,
        prev_loans TEXT,
        insurance_wanted TEXT,
        insurance_for TEXT,
        docs_deposited TEXT,
        docs_other TEXT,
        inc_agri REAL,
        inc_business REAL,
        inc_job REAL,
        inc_other REAL,
        exp_basic REAL,
        exp_education REAL,
        exp_festival REAL,
        exp_health REAL,
        exp_emi REAL,
        exp_other REAL,
        group_rec REAL,
        center_rec REAL,
        loan_cycle INTEGER,
        requested_amt REAL,
        income_total REAL,
        expense_total REAL,
        net_saving REAL,
        declaration INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS approvals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        application_id INTEGER REFERENCES applications(id) ON DELETE RESTRICT,
        stage TEXT,
        by_user TEXT,
        by_role TEXT,
        amount REAL,
        amount_paise INTEGER,
        remarks TEXT,
        at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        application_id INTEGER REFERENCES applications(id) ON DELETE RESTRICT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        product_id INTEGER REFERENCES products(id) ON DELETE RESTRICT,
        principal REAL,
        principal_paise INTEGER,
        rate REAL,
        tenure INTEGER,
        method TEXT,
        emi REAL,
        emi_paise INTEGER,
        start_date TEXT,
        status TEXT,
        closure_date TEXT,
        branch TEXT,
        agent_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        disbursement_ref TEXT,
        disbursement_channel TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER REFERENCES loans(id) ON DELETE RESTRICT,
        no INTEGER,
        due_date TEXT,
        emi REAL,
        emi_paise INTEGER,
        principal REAL,
        principal_paise INTEGER,
        interest REAL,
        interest_paise INTEGER,
        balance REAL,
        balance_paise INTEGER,
        paid INTEGER DEFAULT 0,
        paid_on TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER REFERENCES loans(id) ON DELETE RESTRICT,
        schedule_id INTEGER REFERENCES schedule(id) ON DELETE RESTRICT,
        amount REAL,
        amount_paise INTEGER,
        channel TEXT,
        ref TEXT,
        at TEXT,
        operation_id TEXT UNIQUE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT NOT NULL UNIQUE,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        actor_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        actor_role TEXT NOT NULL,
        actor_name TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '{}'
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_schedule_due_unpaid
      ON schedule(loan_id, paid, due_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_applications_status_created
      ON applications(status, created)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mandates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER REFERENCES loans(id) ON DELETE RESTRICT,
        mtype TEXT,
        bank TEXT,
        acct_last4 TEXT,
        status TEXT,
        created TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        loan_id INTEGER REFERENCES loans(id) ON DELETE RESTRICT,
        ttype TEXT,
        lat REAL,
        lng REAL,
        due_date TEXT,
        officer_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        status TEXT DEFAULT 'open',
        collected REAL DEFAULT 0,
        collected_paise INTEGER DEFAULT 0,
        notes TEXT,
        done_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        day TEXT,
        in_time TEXT,
        out_time TEXT,
        lat REAL,
        lng REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        code TEXT,
        address TEXT,
        phone TEXT,
        head_name TEXT,
        lat REAL,
        lng REAL,
        radius_m INTEGER DEFAULT 2000,
        active INTEGER DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS att_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        branch TEXT,
        day TEXT,
        in_time TEXT,
        out_time TEXT,
        reason TEXT,
        status TEXT DEFAULT 'pending',
        approver_role TEXT,
        approver_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        requested_at TEXT,
        decided_by TEXT,
        decided_at TEXT,
        remarks TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pregrt (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch TEXT,
        center_no TEXT,
        group_no TEXT,
        village TEXT,
        district TEXT,
        form_date TEXT,
        pso_name TEXT,
        pso_empid TEXT,
        bm_name TEXT,
        bm_empid TEXT,
        leader_knows_duties TEXT,
        notes TEXT,
        agent_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        status TEXT DEFAULT 'draft',
        created_at TEXT,
        verified_by TEXT,
        verified_on TEXT,
        review_remarks TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pregrt_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pregrt_id INTEGER REFERENCES pregrt(id) ON DELETE RESTRICT,
        sno INTEGER,
        customer_id INTEGER REFERENCES customers(id) ON DELETE RESTRICT,
        name TEXT,
        husband_name TEXT,
        age INTEGER,
        voter_id TEXT,
        aadhaar4 TEXT,
        family_in_group TEXT,
        house_type TEXT,
        land_ha REAL,
        livestock TEXT,
        annual_income REAL,
        annual_income_paise INTEGER,
        family_size INTEGER,
        category TEXT,
        loan_amount REAL,
        loan_amount_paise INTEGER,
        purpose TEXT,
        frequency TEXT,
        instalments INTEGER,
        c_meeting INTEGER,
        c_joint INTEGER,
        c_fee INTEGER,
        c_rate INTEGER,
        c_insurance INTEGER,
        c_company INTEGER,
        c_group INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kyc_forms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER UNIQUE REFERENCES customers(id) ON DELETE RESTRICT,
        created_by INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        updated_by INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        created_at TEXT,
        updated_at TEXT,
        form_date TEXT,
        center_no TEXT,
        group_no TEXT,
        guardian_type TEXT,
        guardian_name TEXT,
        education TEXT,
        religion TEXT,
        category TEXT,
        house_no TEXT,
        village TEXT,
        post_office TEXT,
        district TEXT,
        state TEXT,
        pincode TEXT,
        family TEXT,
        house_type TEXT,
        land_ha REAL,
        livestock TEXT,
        bank_name TEXT,
        bank_acct TEXT,
        bank_acct_last4 TEXT,
        passbook_name TEXT,
        poverty_line TEXT,
        dist_center_m REAL,
        dist_branch_km REAL,
        relative_in_center TEXT,
        relative_name TEXT,
        annual_income REAL,
        annual_income_paise INTEGER,
        other_loans INTEGER,
        current_debt REAL,
        current_debt_paise INTEGER,
        repay_freq TEXT,
        photo TEXT,
        h_name TEXT,
        h_father TEXT,
        h_dob TEXT,
        h_address TEXT,
        h_photo TEXT,
        consent_given INTEGER DEFAULT 0,
        consent_date TEXT,
        declaration INTEGER DEFAULT 0,
        bureau_consent INTEGER DEFAULT 0,
        address_verified INTEGER DEFAULT 0,
        verified_by TEXT,
        verified_on TEXT,
        verify_remarks TEXT,
        signed_copy TEXT,
        co_name TEXT,
        co_phone TEXT,
        co_relation TEXT,
        co_income REAL,
        co_income_paise INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cloud_connections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider_id TEXT,
        endpoint_url TEXT,
        api_key TEXT,
        project_ref TEXT,
        status TEXT DEFAULT 'configured',
        last_synced TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaves (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        from_d TEXT,
        to_d TEXT,
        reason TEXT,
        status TEXT DEFAULT 'pending'
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS perf (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        period TEXT,
        rating INTEGER,
        notes TEXT,
        by_name TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS holidays (
        day TEXT PRIMARY KEY,
        name TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
        payload TEXT,
        captured_at TEXT,
        synced_at TEXT
      );
    ''');

    await _ensureGrievancesTable(db);
    await _protectLegacyBankAccounts(db);
    await _migrateCoreMoneyColumns(db);
    await _migrateApplicationProductSnapshots(db);
    await _ensureOfflineIntegrityIndexes(db);
    await _ensureOperationalSeedData(db);
  }

  Future<void> _ensureGrievancesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS grievances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_no TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        category TEXT NOT NULL,
        details TEXT NOT NULL,
        status TEXT DEFAULT 'open',
        assigned_to INTEGER,
        branch TEXT DEFAULT 'Bhopal Head Office',
        resolution_notes TEXT,
        resolved_at TEXT,
        created_at TEXT
      );
    ''');
  }

  Future<void> _ensureOperationalSeedData(DatabaseExecutor db) async {
    // 1. Ensure Branches with accurate GPS Geofence boundaries
    final branchCountRows = await db.rawQuery('SELECT COUNT(*) as c FROM branches');
    final branchCount = branchCountRows.first['c'] as int? ?? 0;
    if (branchCount == 0) {
      const branches = [
        {'id': 1, 'name': 'Indore - Vijay Nagar', 'code': 'IND-VN', 'address': 'Scheme 54, Vijay Nagar, Indore (MP)', 'phone': '+91 91111 99101', 'head_name': 'Meera Manager', 'lat': 22.7533, 'lng': 75.8937, 'radius_m': 2000},
        {'id': 2, 'name': 'Indore - Palasia', 'code': 'IND-PL', 'address': 'AB Road, New Palasia, Indore (MP)', 'phone': '+91 91111 99102', 'head_name': 'Palasia Hub Lead', 'lat': 22.7241, 'lng': 75.8839, 'radius_m': 2000},
        {'id': 3, 'name': 'Bhopal - MP Nagar', 'code': 'BPL-MP', 'address': 'Zone 2, MP Nagar, Bhopal (MP)', 'phone': '+91 91111 99103', 'head_name': 'Bhopal Hub Lead', 'lat': 23.2332, 'lng': 77.4340, 'radius_m': 2000},
        {'id': 4, 'name': 'Pipariya Branch', 'code': 'PPR', 'address': 'Station Road, Pipariya, Narmadapuram (MP)', 'phone': '+91 91111 99104', 'head_name': 'Abhinav Rai', 'lat': 22.738750, 'lng': 78.356346, 'radius_m': 2000},
        {'id': 5, 'name': 'Bhopal Head Office', 'code': 'BPL-HO', 'address': 'Shop 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal', 'phone': '+91 91111 99101', 'head_name': 'Bandana Singh', 'lat': 23.279930, 'lng': 77.452200, 'radius_m': 2000},
        {'id': 6, 'name': 'Indore - Rajwada', 'code': 'IND-02', 'address': 'Rajwada Square, Indore (MP)', 'phone': '+91 91111 99105', 'head_name': 'Rajwada Officer', 'lat': 22.7196, 'lng': 75.8577, 'radius_m': 2000},
        {'id': 7, 'name': 'Ujjain - Freeganj', 'code': 'UJJ-01', 'address': 'Freeganj Tower Chowk, Ujjain (MP)', 'phone': '+91 91111 99106', 'head_name': 'Ujjain Officer', 'lat': 23.1765, 'lng': 75.7885, 'radius_m': 2000},
        {'id': 8, 'name': 'Dewas - Station Road', 'code': 'DEW-01', 'address': 'Station Road, Dewas (MP)', 'phone': '+91 91111 99107', 'head_name': 'Dewas Officer', 'lat': 22.9676, 'lng': 76.0534, 'radius_m': 2000},
      ];
      for (final b in branches) {
        await db.insert('branches', {
          'id': b['id'],
          'name': b['name'],
          'code': b['code'],
          'address': b['address'],
          'phone': b['phone'],
          'head_name': b['head_name'],
          'lat': b['lat'],
          'lng': b['lng'],
          'radius_m': b['radius_m'],
          'active': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    // 2. Ensure Loan Products
    final prodRows = await db.rawQuery('SELECT COUNT(*) as c FROM products');
    if ((prodRows.first['c'] as int? ?? 0) == 0) {
      const products = [
        {'id': 1, 'name': 'Micro Business Loan', 'min_amt': 10000.0, 'max_amt': 100000.0, 'min_tenure': 6, 'max_tenure': 24, 'rate': 18.0, 'method': 'reducing', 'fee_pct': 1.0},
        {'id': 2, 'name': 'Income Generation Loan', 'min_amt': 5000.0, 'max_amt': 50000.0, 'min_tenure': 6, 'max_tenure': 18, 'rate': 22.0, 'method': 'flat', 'fee_pct': 1.0},
        {'id': 3, 'name': 'Emergency Loan', 'min_amt': 2000.0, 'max_amt': 25000.0, 'min_tenure': 3, 'max_tenure': 12, 'rate': 12.0, 'method': 'reducing', 'fee_pct': 0.5},
        {'id': 4, 'name': 'Group Loan (JLG)', 'min_amt': 5000.0, 'max_amt': 30000.0, 'min_tenure': 6, 'max_tenure': 24, 'rate': 20.0, 'method': 'reducing', 'fee_pct': 1.0},
      ];
      for (final p in products) {
        final minAmt = p['min_amt'] as double;
        final maxAmt = p['max_amt'] as double;
        await db.insert('products', {
          'id': p['id'],
          'name': p['name'],
          'min_amt': minAmt,
          'min_amt_paise': (minAmt * 100).round(),
          'max_amt': maxAmt,
          'max_amt_paise': (maxAmt * 100).round(),
          'min_tenure': p['min_tenure'],
          'max_tenure': p['max_tenure'],
          'rate': p['rate'],
          'method': p['method'],
          'fee_pct': p['fee_pct'],
          'active': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    // 3. Ensure Default Settings
    const defaultSettings = {
      'min_age': '18',
      'max_age': '55',
      'group_min': '2',
      'group_max': '5',
      'income_limit': '25000',
      'emi_pct': '60',
      'gst_rate': '18',
      'att_hours': '8',
    };
    for (final entry in defaultSettings.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 4. Seed Operational Role Accounts (All 5 Roles with PBKDF2-HMAC-SHA256)
    final activeUsers = await db.rawQuery(
      "SELECT COUNT(*) as c FROM users WHERE auth_status = 'active' AND password_hash IS NOT NULL",
    );
    if ((activeUsers.first['c'] as int? ?? 0) == 0) {
      const roleSeeds = [
        {'id': 1, 'username': 'admin', 'pw': 'admin123', 'name': 'Aarav Admin', 'role': 'admin', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000001'},
        {'id': 2, 'username': 'manager1', 'pw': 'manager123', 'name': 'Meera Manager', 'role': 'manager', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000002'},
        {'id': 3, 'username': 'uw1', 'pw': 'uw123', 'name': 'Uday Underwriter', 'role': 'underwriter', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000003'},
        {'id': 4, 'username': 'agent1', 'pw': 'agent123', 'name': 'Ravi Field Officer', 'role': 'field_agent', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000004'},
        {'id': 5, 'username': 'agent2', 'pw': 'agent123', 'name': 'Sneha Field Officer', 'role': 'field_agent', 'branch': 'Indore - Palasia', 'phone': '9800000005'},
        {'id': 6, 'username': 'agent3', 'pw': 'agent123', 'name': 'Imran Field Officer', 'role': 'field_agent', 'branch': 'Bhopal - MP Nagar', 'phone': '9800000006'},
        {'id': 7, 'username': 'cust1', 'pw': 'cust123', 'name': 'Sunita Verma', 'role': 'customer', 'branch': 'Indore - Vijay Nagar', 'phone': '9811111111'},
      ];

      final hashes = await Future.wait(
        roleSeeds.map((u) => PasswordHashService.hash(u['pw'] as String)),
      );

      for (var i = 0; i < roleSeeds.length; i++) {
        final u = roleSeeds[i];
        await db.insert('users', {
          'id': u['id'],
          'username': u['username'],
          'password_hash': hashes[i],
          'auth_status': 'active',
          'failed_login_attempts': 0,
          'locked_until': null,
          'name': u['name'],
          'role': u['role'],
          'branch': u['branch'],
          'phone': u['phone'],
          'customer_id': null,
          'must_change': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Seed Customer #1 (agent_id=4 now exists) and link cust1 -> customer_id=1
      await db.insert('customers', {
        'id': 1,
        'name': 'Sunita Verma',
        'phone': '9811111111',
        'dob': '1990-05-12',
        'address': 'Pardesipura Center 04, Indore (MP)',
        'branch': 'Indore - Vijay Nagar',
        'agent_id': 4,
        'stage': 'converted',
        'aadhaar': 'XXXX-XXXX-4321',
        'pan': 'ABCPV1234K',
        'kyc_status': 'verified',
        'wa_verified': 1,
        'created': '2026-11-01',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await db.update('users', {'customer_id': 1}, where: 'id = ?', whereArgs: [7]);

      // Seed matching staff employee rows
      const empSeeds = [
        {'id': 1, 'user_id': 1, 'name': 'Aarav Admin', 'designation': 'Chief Administrator', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000001', 'salary': 65000.0},
        {'id': 2, 'user_id': 2, 'name': 'Meera Manager', 'designation': 'Branch Manager', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000002', 'salary': 45000.0},
        {'id': 3, 'user_id': 3, 'name': 'Uday Underwriter', 'designation': 'Senior Credit Underwriter', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000003', 'salary': 38000.0},
        {'id': 4, 'user_id': 4, 'name': 'Ravi Field Officer', 'designation': 'Field Officer (PSO)', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000004', 'salary': 22000.0},
        {'id': 5, 'user_id': 5, 'name': 'Sneha Field Officer', 'designation': 'Field Officer (PSO)', 'branch': 'Indore - Palasia', 'phone': '9800000005', 'salary': 22000.0},
        {'id': 6, 'user_id': 6, 'name': 'Imran Field Officer', 'designation': 'Field Officer (PSO)', 'branch': 'Bhopal - MP Nagar', 'phone': '9800000006', 'salary': 22000.0},
      ];
      for (final e in empSeeds) {
        final sal = e['salary'] as double;
        await db.insert('employees', {
          'id': e['id'],
          'user_id': e['user_id'],
          'name': e['name'],
          'designation': e['designation'],
          'branch': e['branch'],
          'phone': e['phone'],
          'joined': '2026-01-15',
          'status': 'active',
          'bg_check': 'cleared',
          'salary': sal,
          'salary_paise': (sal * 100).round(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await db.insert('app_meta', {
        'key': 'initial_setup_completed',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
