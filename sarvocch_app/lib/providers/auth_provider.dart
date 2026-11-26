import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/user_model.dart';
import '../services/password_hash_service.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  String? _sessionPasswordHash;
  bool _isLoading = false;
  bool _needsInitialSetup = false;
  bool _needsAccountRecovery = false;
  String? _initializationError;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get needsInitialSetup => _needsInitialSetup;
  bool get needsAccountRecovery => _needsAccountRecovery;
  String? get initializationError => _initializationError;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      _initializationError = null;
      final results = await db.rawQuery('''
        SELECT u.*, e.designation 
        FROM users u 
        LEFT JOIN employees e ON u.id = e.user_id
        WHERE u.auth_status = 'active' AND u.password_hash IS NOT NULL
        ORDER BY u.id ASC
      ''');
      final setupRows = await db.query(
        'app_meta',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['initial_setup_completed'],
        limit: 1,
      );
      final setupCompleted =
          setupRows.isNotEmpty && setupRows.first['value'] == '1';
      _needsInitialSetup = results.isEmpty && !setupCompleted;
      _needsAccountRecovery = results.isEmpty && setupCompleted;
    } catch (_) {
      _initializationError = 'The local database could not be opened securely.';
      debugPrint('Unable to initialize local authentication.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    final trimmedUsername = username.trim();
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Try Live Cloud Login first (if device has internet connectivity)
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 7);
        final req = await client.postUrl(
          Uri.parse('${SyncService.cloudBaseUrl}/auth/login'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'username': trimmedUsername,
          'password': password,
          'device_label': 'Sarvoocch Android App',
        }));
        final resp = await req.close().timeout(const Duration(seconds: 10));
        final body = await resp.transform(utf8.decoder).join();
        client.close();

        if (resp.statusCode == 200) {
          final parsed = jsonDecode(body) as Map<String, dynamic>? ?? {};
          if (parsed['ok'] == true && parsed['user'] is Map && parsed['token'] is String) {
            final cloudToken = parsed['token'] as String;
            final uMap = Map<String, dynamic>.from(parsed['user'] as Map);
            await SecureStorageService().writePersistentSecret(
              SyncService.tokenStorageKey,
              cloudToken,
            );
            final localHash = await PasswordHashService.hash(password);
            final signedIn = await _upsertCloudAuthenticatedUser(
              db,
              uMap,
              localHash,
            );
            if (signedIn != null) {
              _currentUser = signedIn;
              _sessionPasswordHash = localHash;
              notifyListeners();
              // Pull live cloud data immediately in background
              SyncService().triggerFullSync(userId: signedIn.id);
              return true;
            }
          }
        } else if (resp.statusCode == 401 || resp.statusCode == 423 || resp.statusCode == 429) {
          // Explicit rejection from cloud authoritative server
          await PasswordHashService.performDummyVerificationWork(password);
          return false;
        }
      } catch (e) {
        // Offline / network timeout: gracefully proceed to encrypted local verification
        debugPrint('Cloud auth unavailable, using encrypted offline credential store: $e');
      }

      // 2. Encrypted Local SQLite Authentication (Offline-First / Fallback)
      final results = await db.rawQuery(
        '''
        SELECT u.*, e.designation 
        FROM users u 
        LEFT JOIN employees e ON u.id = e.user_id 
        WHERE lower(u.username) = lower(?)
          AND u.auth_status = 'active'
        LIMIT 1
      ''',
        [trimmedUsername],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        final lockValue = row['locked_until'] as String?;
        final lockedUntil = lockValue == null
            ? null
            : DateTime.tryParse(lockValue);
        if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
          await PasswordHashService.performDummyVerificationWork(password);
          return false;
        }

        final passwordHash = row['password_hash'] as String?;
        final hasSupportedHash = PasswordHashService.hasSupportedEncoding(
          passwordHash,
        );
        final valid = hasSupportedHash
            ? await PasswordHashService.verify(password, passwordHash!)
            : false;
        if (!hasSupportedHash) {
          await PasswordHashService.performDummyVerificationWork(password);
        }
        if (!valid) {
          await _recordFailedLogin(db, row);
          return false;
        }

        final signedInUser = await db.transaction((txn) async {
          final currentRows = await txn.rawQuery(
            '''
            SELECT u.*, e.designation
            FROM users u
            LEFT JOIN employees e ON u.id = e.user_id
            WHERE u.id = ? AND u.auth_status = 'active'
            LIMIT 1
          ''',
            [row['id']],
          );
          if (currentRows.isEmpty ||
              currentRows.first['password_hash'] != passwordHash) {
            return null;
          }
          final lockValue = currentRows.first['locked_until'] as String?;
          final lockedUntil = lockValue == null
              ? null
              : DateTime.tryParse(lockValue);
          if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
            return null;
          }
          final resetFailures = await txn.update(
            'users',
            {'failed_login_attempts': 0, 'locked_until': null},
            where: 'id = ? AND auth_status = ? AND password_hash = ?',
            whereArgs: [row['id'], 'active', passwordHash],
          );
          if (resetFailures != 1) return null;
          await txn.insert('audit_log', {
            'operation_id': const Uuid().v4(),
            'entity_type': 'user',
            'entity_id': row['id'],
            'action': 'login_succeeded',
            'actor_user_id': row['id'],
            'actor_role': currentRows.first['role'],
            'actor_name': currentRows.first['name'],
            'occurred_at': DateTime.now().toIso8601String().substring(0, 19),
            'details': '{}',
          });
          return UserModel.fromMap(currentRows.first);
        });
        if (signedInUser == null) return false;
        _currentUser = signedInUser;
        _sessionPasswordHash = passwordHash;
        notifyListeners();
        return true;
      }
      await PasswordHashService.performDummyVerificationWork(password);
      return false;
    } catch (_) {
      debugPrint('Local sign-in failed.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel?> _upsertCloudAuthenticatedUser(
    Database db,
    Map<String, dynamic> uMap,
    String passwordHash,
  ) async {
    return db.transaction<UserModel?>((txn) async {
      final cloudId = (uMap['id'] as num).toInt();
      final cid = uMap['customer_id'] != null
          ? (uMap['customer_id'] as num).toInt()
          : null;
      if (cid != null) {
        final custExists = await txn.query(
          'customers',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [cid],
          limit: 1,
        );
        if (custExists.isEmpty) {
          await txn.insert('customers', {
            'id': cid,
            'name': uMap['name'] ?? 'Customer',
            'phone': uMap['phone'] ?? '',
            'branch': uMap['branch'] ?? 'Indore - Vijay Nagar',
            'stage': 'converted',
            'kyc_status': 'verified',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      await txn.insert('users', {
        'id': cloudId,
        'username': uMap['username'],
        'password_hash': passwordHash,
        'auth_status': 'active',
        'failed_login_attempts': 0,
        'locked_until': null,
        'name': uMap['name'] ?? uMap['username'],
        'role': uMap['role'] ?? 'field_agent',
        'branch': uMap['branch'] ?? '',
        'phone': uMap['phone'] ?? '',
        'customer_id': cid,
        'must_change': (uMap['must_change'] as num?)?.toInt() ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('app_meta', {
        'key': 'initial_setup_completed',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('audit_log', {
        'operation_id': const Uuid().v4(),
        'entity_type': 'user',
        'entity_id': cloudId,
        'action': 'login_succeeded',
        'actor_user_id': cloudId,
        'actor_role': uMap['role'],
        'actor_name': uMap['name'],
        'occurred_at': DateTime.now().toIso8601String().substring(0, 19),
        'details': '{"mode":"cloud_verified"}',
      });

      final rows = await txn.rawQuery(
        '''
        SELECT u.*, e.designation
        FROM users u
        LEFT JOIN employees e ON u.id = e.user_id
        WHERE u.id = ?
        LIMIT 1
        ''',
        [cloudId],
      );
      if (rows.isEmpty) return null;
      return UserModel.fromMap(rows.first);
    });
  }

  Future<bool> validateCurrentSession() async {
    final sessionUser = _currentUser;
    final sessionPasswordHash = _sessionPasswordHash;
    if (sessionUser == null || sessionPasswordHash == null) return false;

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT u.*, e.designation
        FROM users u
        LEFT JOIN employees e ON u.id = e.user_id
        WHERE u.id = ?
        LIMIT 1
        ''',
        [sessionUser.id],
      );
      if (rows.isEmpty) {
        logout();
        return false;
      }

      final row = rows.first;
      final refreshed = UserModel.fromMap(row);
      final storedHash = row['password_hash'] as String?;
      final lockValue = row['locked_until'] as String?;
      final lockedUntil = lockValue == null
          ? null
          : DateTime.tryParse(lockValue);
      final reason = row['auth_status'] != 'active'
          ? 'account_inactive'
          : storedHash == null || storedHash != sessionPasswordHash
          ? 'password_changed'
          : lockedUntil != null && lockedUntil.isAfter(DateTime.now())
          ? 'account_locked'
          : refreshed.role != sessionUser.role ||
                refreshed.branch != sessionUser.branch ||
                refreshed.customerId != sessionUser.customerId ||
                refreshed.mustChangePassword != sessionUser.mustChangePassword
          ? 'access_scope_changed'
          : null;

      if (reason != null) {
        await db.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'user',
          'entity_id': sessionUser.id,
          'action': 'session_revoked',
          'actor_user_id': sessionUser.id,
          'actor_role': sessionUser.role,
          'actor_name': sessionUser.name,
          'occurred_at': DateTime.now().toIso8601String().substring(0, 19),
          'details': jsonEncode({'reason': reason}),
        });
        logout();
        return false;
      }

      _currentUser = refreshed;
      notifyListeners();
      return true;
    } catch (_) {
      debugPrint('Local session could not be revalidated.');
      logout();
      return false;
    }
  }

  Future<void> _recordFailedLogin(
    Database db,
    Map<String, Object?> user,
  ) async {
    final userId = user['id'] as int?;
    if (userId == null) return;
    await db.transaction((txn) async {
      final currentRows = await txn.query(
        'users',
        columns: ['failed_login_attempts', 'role', 'name'],
        where: "id = ? AND auth_status = 'active'",
        whereArgs: [userId],
        limit: 1,
      );
      if (currentRows.isEmpty) return;
      final attempts =
          ((currentRows.first['failed_login_attempts'] as num?)?.toInt() ?? 0) +
          1;
      final lockMinutes = attempts < 5
          ? 0
          : (1 << min(attempts - 5, 6)).clamp(1, 60).toInt();
      final lockedUntil = lockMinutes == 0
          ? null
          : DateTime.now()
                .add(Duration(minutes: lockMinutes))
                .toIso8601String();
      final updated = await txn.update(
        'users',
        {'failed_login_attempts': attempts, 'locked_until': lockedUntil},
        where: "id = ? AND auth_status = 'active'",
        whereArgs: [userId],
      );
      if (updated != 1) return;
      await txn.insert('audit_log', {
        'operation_id': const Uuid().v4(),
        'entity_type': 'user',
        'entity_id': userId,
        'action': lockedUntil == null ? 'login_failed' : 'login_locked',
        'actor_user_id': userId,
        'actor_role': currentRows.first['role'],
        'actor_name': currentRows.first['name'],
        'occurred_at': DateTime.now().toIso8601String().substring(0, 19),
        'details': jsonEncode({
          'failed_attempts': attempts,
          'lockout_minutes': lockMinutes,
        }),
      });
    });
  }

  Future<bool> bootstrapAdmin({
    required String username,
    required String name,
    required String password,
  }) async {
    if (!_needsInitialSetup) return false;
    final normalizedUsername = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._-]{3,64}$').hasMatch(normalizedUsername) ||
        name.trim().isEmpty ||
        password.length < 12 ||
        password.length > PasswordHashService.maxPasswordBytes) {
      return false;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      final passwordHash = await PasswordHashService.hash(password);
      await db.transaction((transaction) async {
        final setupState = await transaction.query(
          'app_meta',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: ['initial_setup_completed'],
          limit: 1,
        );
        if (setupState.isEmpty || setupState.first['value'] != '0') {
          throw StateError('Initial setup is not available.');
        }
        final existing = await transaction.rawQuery(
          "SELECT COUNT(*) AS count FROM users WHERE auth_status = 'active' AND password_hash IS NOT NULL",
        );
        if ((existing.first['count'] as int? ?? 0) != 0) {
          throw StateError('Administrator setup already completed.');
        }

        final priorAccount = await transaction.query(
          'users',
          columns: ['id'],
          where: 'lower(username) = ?',
          whereArgs: [normalizedUsername],
          limit: 1,
        );
        if (priorAccount.isNotEmpty) {
          throw StateError('Username is already assigned.');
        }
        final account = {
          'username': normalizedUsername,
          'password_hash': passwordHash,
          'auth_status': 'active',
          'name': name.trim(),
          'role': 'admin',
          'branch': '',
          'phone': '',
          'must_change': 0,
          'failed_login_attempts': 0,
          'locked_until': null,
        };
        await transaction.insert('users', account);
        await transaction.update(
          'app_meta',
          {'value': '1'},
          where: 'key = ?',
          whereArgs: ['initial_setup_completed'],
        );
      });
      _needsInitialSetup = false;
      _needsAccountRecovery = false;
      return true;
    } catch (_) {
      debugPrint('Initial administrator setup failed.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null || newPassword.length < 12) return false;
    if (newPassword.length > PasswordHashService.maxPasswordBytes) return false;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'users',
        columns: ['password_hash'],
        where: 'id = ? AND auth_status = ?',
        whereArgs: [currentUser.id, 'active'],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final storedHash = rows.first['password_hash'] as String?;
      if (storedHash == null ||
          !await PasswordHashService.verify(currentPassword, storedHash)) {
        return false;
      }

      final newHash = await PasswordHashService.hash(newPassword);
      final occurredAt = DateTime.now().toIso8601String().substring(0, 19);
      await db.transaction((txn) async {
        final changed = await txn.update(
          'users',
          {'password_hash': newHash, 'must_change': 0},
          where: 'id = ? AND auth_status = ? AND password_hash = ?',
          whereArgs: [currentUser.id, 'active', storedHash],
        );
        if (changed != 1) throw StateError('Active user record changed.');
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'user',
          'entity_id': currentUser.id,
          'action': 'password_changed',
          'actor_user_id': currentUser.id,
          'actor_role': currentUser.role,
          'actor_name': currentUser.name,
          'occurred_at': occurredAt,
          'details': '{}',
        });
      });
      _currentUser = UserModel(
        id: currentUser.id,
        username: currentUser.username,
        name: currentUser.name,
        role: currentUser.role,
        branch: currentUser.branch,
        phone: currentUser.phone,
        customerId: currentUser.customerId,
        lat: currentUser.lat,
        lng: currentUser.lng,
        designation: currentUser.designation,
        mustChangePassword: false,
      );
      _sessionPasswordHash = newHash;
      notifyListeners();
      return true;
    } catch (_) {
      debugPrint('Password update failed.');
      return false;
    }
  }

  Future<List<Map<String, Object?>>> listManagedAccounts(
    int actorUserId,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.transaction((txn) async {
        if (await _activeAdmin(txn, actorUserId) == null) return [];
        final rows = await txn.rawQuery('''
          SELECT u.id, u.username, u.name, u.role, u.branch, u.phone,
                 u.customer_id, u.auth_status, u.must_change,
                 e.id AS employee_id, e.designation,
                 c.id AS linked_customer_id
          FROM users u
          LEFT JOIN employees e ON e.user_id = u.id
          LEFT JOIN customers c ON c.id = u.customer_id
          ORDER BY u.id ASC
        ''');
        return rows.map((row) => Map<String, Object?>.from(row)).toList();
      });
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, Object?>>> listUnlinkedEmployees(
    int actorUserId,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.transaction((txn) async {
        if (await _activeAdmin(txn, actorUserId) == null) return [];
        final rows = await txn.rawQuery('''
          SELECT e.id, e.name, e.designation, e.branch, e.phone
          FROM employees e
          JOIN branches b ON b.name = e.branch AND b.active = 1
          WHERE e.user_id IS NULL
            AND lower(COALESCE(e.status, '')) != 'exited'
          ORDER BY e.name COLLATE NOCASE ASC
        ''');
        return rows.map((row) => Map<String, Object?>.from(row)).toList();
      });
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, Object?>>> listCustomersWithoutAccounts(
    int actorUserId,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.transaction((txn) async {
        if (await _activeAdmin(txn, actorUserId) == null) return [];
        final rows = await txn.rawQuery('''
          SELECT c.id, c.name, c.phone, c.branch
          FROM customers c
          JOIN branches b ON b.name = c.branch AND b.active = 1
          WHERE lower(COALESCE(c.kyc_status, 'pending')) = 'verified'
            AND NOT EXISTS (
            SELECT 1 FROM users u
            WHERE u.role = 'customer' AND u.customer_id = c.id
          )
          ORDER BY c.name COLLATE NOCASE ASC
        ''');
        return rows.map((row) => Map<String, Object?>.from(row)).toList();
      });
    } catch (_) {
      return [];
    }
  }

  Future<bool> createStaffAccount({
    required int actorUserId,
    required int employeeId,
    required String username,
    required String role,
    required String initialPassword,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    if (employeeId <= 0 ||
        !RegExp(r'^[a-z0-9._-]{3,64}$').hasMatch(normalizedUsername) ||
        !{'manager', 'underwriter', 'field_agent'}.contains(role) ||
        initialPassword.length < 12 ||
        initialPassword.length > PasswordHashService.maxPasswordBytes) {
      return false;
    }
    try {
      final passwordHash = await PasswordHashService.hash(initialPassword);
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      await db.transaction((txn) async {
        final actor = await _requireActiveAdmin(txn, actorUserId);
        final duplicateUsername = await txn.rawQuery(
          'SELECT id FROM users WHERE lower(username) = ? LIMIT 1',
          [normalizedUsername],
        );
        if (duplicateUsername.isNotEmpty) {
          throw StateError('Username is already assigned.');
        }
        final employees = await txn.query(
          'employees',
          columns: ['id', 'name', 'branch', 'phone', 'status', 'user_id'],
          where: 'id = ?',
          whereArgs: [employeeId],
          limit: 1,
        );
        if (employees.isEmpty ||
            employees.first['user_id'] != null ||
            (employees.first['status'] as String? ?? '').toLowerCase() ==
                'exited') {
          throw StateError('Employee is unavailable for account linking.');
        }
        final employee = employees.first;
        final branch = (employee['branch'] as String? ?? '').trim();
        final branches = await txn.query(
          'branches',
          columns: ['id'],
          where: 'name = ? AND active = 1',
          whereArgs: [branch],
          limit: 1,
        );
        if (branch.isEmpty || branches.isEmpty) {
          throw StateError('Employee must be assigned to an active branch.');
        }
        final phone = (employee['phone'] as String? ?? '').trim();
        if (!RegExp(r'^\+?[0-9\s()-]{10,20}$').hasMatch(phone)) {
          throw StateError('Employee phone is invalid.');
        }
        final userId = await txn.insert('users', {
          'username': normalizedUsername,
          'password_hash': passwordHash,
          'auth_status': 'active',
          'failed_login_attempts': 0,
          'locked_until': null,
          'name': employee['name'],
          'role': role,
          'branch': branch,
          'phone': phone,
          'customer_id': null,
          'must_change': 1,
        });
        final linked = await txn.update(
          'employees',
          {'user_id': userId},
          where: 'id = ? AND user_id IS NULL',
          whereArgs: [employeeId],
        );
        if (linked != 1) throw StateError('Employee link was already used.');
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'user',
          'entity_id': userId,
          'action': 'staff_account_created',
          'actor_user_id': actorUserId,
          'actor_role': actor['role'],
          'actor_name': actor['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'employee_id': employeeId,
            'username': normalizedUsername,
            'role': role,
            'branch': branch,
            'must_change_password': true,
          }),
        });
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createCustomerAccount({
    required int actorUserId,
    required int customerId,
    required String username,
    required String initialPassword,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    if (customerId <= 0 ||
        !RegExp(r'^[a-z0-9._-]{3,64}$').hasMatch(normalizedUsername) ||
        initialPassword.length < 12 ||
        initialPassword.length > PasswordHashService.maxPasswordBytes) {
      return false;
    }
    try {
      final passwordHash = await PasswordHashService.hash(initialPassword);
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      await db.transaction((txn) async {
        final actor = await _requireActiveAdmin(txn, actorUserId);
        final duplicateUsername = await txn.rawQuery(
          'SELECT id FROM users WHERE lower(username) = ? LIMIT 1',
          [normalizedUsername],
        );
        if (duplicateUsername.isNotEmpty) {
          throw StateError('Username is already assigned.');
        }
        final customers = await txn.query(
          'customers',
          columns: ['name', 'phone', 'branch', 'kyc_status'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customers.isEmpty) throw StateError('Customer does not exist.');
        final customer = customers.first;
        if ((customer['kyc_status'] as String? ?? '').toLowerCase() !=
            'verified') {
          throw StateError(
            'Customer KYC must be approved before portal access.',
          );
        }
        final branch = (customer['branch'] as String? ?? '').trim();
        final branches = await txn.query(
          'branches',
          columns: ['id'],
          where: 'name = ? AND active = 1',
          whereArgs: [branch],
          limit: 1,
        );
        if (branch.isEmpty || branches.isEmpty) {
          throw StateError('Customer must belong to an active branch.');
        }
        final existing = await txn.query(
          'users',
          columns: ['id'],
          where: "role = 'customer' AND customer_id = ?",
          whereArgs: [customerId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          throw StateError('Customer already has a portal account.');
        }
        final userId = await txn.insert('users', {
          'username': normalizedUsername,
          'password_hash': passwordHash,
          'auth_status': 'active',
          'failed_login_attempts': 0,
          'locked_until': null,
          'name': customer['name'],
          'role': 'customer',
          'branch': branch,
          'phone': customer['phone'],
          'customer_id': customerId,
          'must_change': 1,
        });
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'user',
          'entity_id': userId,
          'action': 'customer_account_created',
          'actor_user_id': actorUserId,
          'actor_role': actor['role'],
          'actor_name': actor['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'customer_id': customerId,
            'username': normalizedUsername,
            'branch': branch,
            'must_change_password': true,
          }),
        });
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setManagedAccountActive({
    required int actorUserId,
    required int targetUserId,
    required bool active,
  }) async {
    if (targetUserId <= 0 || targetUserId == actorUserId) return false;
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final changed = await db.transaction((txn) async {
        final actor = await _requireActiveAdmin(txn, actorUserId);
        final targets = await txn.query(
          'users',
          columns: ['role', 'auth_status', 'password_hash'],
          where: 'id = ?',
          whereArgs: [targetUserId],
          limit: 1,
        );
        if (targets.isEmpty ||
            (active && targets.first['password_hash'] == null)) {
          throw StateError('Account cannot be enabled.');
        }
        if (!active &&
            targets.first['role'] == 'admin' &&
            targets.first['auth_status'] == 'active') {
          final activeAdmins = await txn.rawQuery(
            '''
            SELECT COUNT(*) AS count FROM users
            WHERE role = 'admin' AND auth_status = 'active' AND id != ?
          ''',
            [targetUserId],
          );
          if ((activeAdmins.first['count'] as int? ?? 0) == 0) {
            throw StateError(
              'The last active administrator cannot be disabled.',
            );
          }
        }
        final nextStatus = active ? 'active' : 'disabled';
        final updated = await txn.update(
          'users',
          {'auth_status': nextStatus},
          where: 'id = ?',
          whereArgs: [targetUserId],
        );
        if (updated != 1) return false;
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'user',
          'entity_id': targetUserId,
          'action': active ? 'account_enabled' : 'account_disabled',
          'actor_user_id': actorUserId,
          'actor_role': actor['role'],
          'actor_name': actor['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({'auth_status': nextStatus}),
        });
        return true;
      });
      return changed;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetManagedAccountPassword({
    required int actorUserId,
    required int targetUserId,
    required String temporaryPassword,
  }) async {
    if (targetUserId <= 0 ||
        targetUserId == actorUserId ||
        temporaryPassword.length < 12 ||
        temporaryPassword.length > PasswordHashService.maxPasswordBytes) {
      return false;
    }
    try {
      final passwordHash = await PasswordHashService.hash(temporaryPassword);
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      return await db.transaction((txn) async {
        final actor = await _requireActiveAdmin(txn, actorUserId);
        final targets = await txn.query(
          'users',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [targetUserId],
          limit: 1,
        );
        if (targets.isEmpty) throw StateError('Account does not exist.');
        final updated = await txn.update(
          'users',
          {
            'password_hash': passwordHash,
            'must_change': 1,
            'failed_login_attempts': 0,
            'locked_until': null,
          },
          where: 'id = ?',
          whereArgs: [targetUserId],
        );
        if (updated != 1) return false;
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'user',
          'entity_id': targetUserId,
          'action': 'account_password_reset',
          'actor_user_id': actorUserId,
          'actor_role': actor['role'],
          'actor_name': actor['name'],
          'occurred_at': nowIso,
          'details': '{"must_change_password":true}',
        });
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, Object?>?> _activeAdmin(
    DatabaseExecutor executor,
    int actorUserId,
  ) async {
    final rows = await executor.query(
      'users',
      columns: ['id', 'name', 'role', 'auth_status'],
      where: 'id = ?',
      whereArgs: [actorUserId],
      limit: 1,
    );
    if (rows.isEmpty ||
        rows.first['role'] != 'admin' ||
        rows.first['auth_status'] != 'active') {
      return null;
    }
    return rows.first;
  }

  Future<Map<String, Object?>> _requireActiveAdmin(
    DatabaseExecutor executor,
    int actorUserId,
  ) async {
    final actor = await _activeAdmin(executor, actorUserId);
    if (actor == null) throw StateError('Active administrator required.');
    return actor;
  }

  void logout() {
    _revokeCloudTokenAsync();
    _currentUser = null;
    _sessionPasswordHash = null;
    notifyListeners();
  }

  Future<void> _revokeCloudTokenAsync() async {
    try {
      final token = await SyncService().readCloudToken();
      if (token != null) {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
        final req = await client.postUrl(
          Uri.parse('${SyncService.cloudBaseUrl}/auth/logout'),
        );
        req.headers.set('Authorization', 'Bearer $token');
        await req.close().timeout(const Duration(seconds: 5));
        client.close();
      }
    } catch (_) {}
    await SecureStorageService().deleteSecret(SyncService.tokenStorageKey);
  }
}
