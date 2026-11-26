import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';
import 'secure_storage_service.dart';

class SyncService extends ChangeNotifier {
  static const String cloudBaseUrl = 'https://sarvocchfinance.com/portal/api/v1';
  static const String defaultSyncEndpoint = '$cloudBaseUrl/sync';
  static const String pullSyncEndpoint = '$cloudBaseUrl/sync/pull';
  static const String tokenStorageKey = 'cloud_api_token_v1';

  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _isCloudOnline = false;
  String _lastSyncStatus = 'Ready for Cloud Sync';
  String? _lastSyncedAt;

  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;
  bool get isCloudOnline => _isCloudOnline;
  String get lastSyncStatus => _lastSyncStatus;
  String? get lastSyncedAt => _lastSyncedAt;

  Future<void> init() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final meta = await db.query(
        'app_meta',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['last_cloud_synced_at'],
        limit: 1,
      );
      if (meta.isNotEmpty) {
        _lastSyncedAt = meta.first['value'] as String?;
      }
    } catch (_) {}
    await updatePendingCount();
  }

  Future<int> updatePendingCount() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM sync_log WHERE synced_at IS NULL OR synced_at = ''",
      );
      _pendingCount = (res.first['cnt'] as num?)?.toInt() ?? 0;
      notifyListeners();
      return _pendingCount;
    } catch (_) {
      return 0;
    }
  }

  Future<String?> readCloudToken() async {
    try {
      final token = await SecureStorageService().readPersistentSecret(tokenStorageKey);
      return (token != null && token.trim().isNotEmpty) ? token.trim() : null;
    } catch (_) {
      return null;
    }
  }

  /// Queue offline action idempotently for cloud push sync
  Future<bool> enqueueAction({
    required int userId,
    required String action,
    required Map<String, dynamic> payload,
    required String operationId,
  }) async {
    final normalizedAction = action.trim();
    final normalizedOperationId = operationId.trim();
    if (userId <= 0 ||
        normalizedAction.isEmpty ||
        normalizedOperationId.isEmpty ||
        normalizedOperationId.length > 128) {
      return false;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final encodedPayload = jsonEncode({
        'action': normalizedAction,
        'data': payload,
      });
      final inserted = await db.transaction<bool>((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['id'],
          where: "id = ? AND auth_status = 'active'",
          whereArgs: [userId],
          limit: 1,
        );
        if (actors.isEmpty) return false;

        final existing = await txn.query(
          'sync_log',
          columns: ['user_id', 'payload'],
          where: 'uuid = ?',
          whereArgs: [normalizedOperationId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return existing.first['user_id'] == userId &&
              existing.first['payload'] == encodedPayload;
        }

        await txn.insert('sync_log', {
          'uuid': normalizedOperationId,
          'user_id': userId,
          'payload': encodedPayload,
          'captured_at': nowIso,
          'synced_at': null,
        });
        return true;
      });

      await updatePendingCount();
      return inserted;
    } catch (_) {
      debugPrint('Offline operation could not be queued.');
      return false;
    }
  }

  /// Bi-directional Push + Pull Cloud Synchronization against Hostinger Portal
  Future<bool> triggerFullSync({
    int? userId,
    String? syncUrl,
  }) async {
    if (_isSyncing) return false;
    _isSyncing = true;
    _lastSyncStatus = 'Connecting to Cloud...';
    notifyListeners();

    final endpoint = syncUrl ?? defaultSyncEndpoint;
    try {
      final token = await readCloudToken();
      if (token == null) {
        _isCloudOnline = false;
        _lastSyncStatus = 'Offline session (Sign in online to enable Cloud Sync).';
        await updatePendingCount();
        return false;
      }

      final db = await DatabaseHelper.instance.database;

      // STEP 1: PUSH PENDING MUTATIONS TO CLOUD
      final pendingRows = await db.query(
        'sync_log',
        where: "synced_at IS NULL OR synced_at = ''",
        orderBy: 'id ASC',
        limit: 100,
      );

      if (pendingRows.isNotEmpty) {
        _lastSyncStatus = 'Uploading ${pendingRows.length} offline records...';
        notifyListeners();

        final items = pendingRows.map((row) {
          Map<String, dynamic> decodedPayload = {};
          try {
            decodedPayload =
                jsonDecode(row['payload'] as String? ?? '{}') as Map<String, dynamic>;
          } catch (_) {}
          return {
            'uuid': row['uuid'],
            'user_id': row['user_id'],
            'captured_at': row['captured_at'],
            'action': decodedPayload['action'] ?? 'offline_action',
            'data': decodedPayload['data'] ?? {},
          };
        }).toList();

        final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
        final request = await client.postUrl(Uri.parse(endpoint));
        request.headers.contentType = ContentType.json;
        request.headers.set('Authorization', 'Bearer $token');
        request.write(jsonEncode({'items': items}));

        final response = await request.close().timeout(const Duration(seconds: 20));
        final responseBody = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode == 401) {
          _isCloudOnline = false;
          _lastSyncStatus = 'Cloud token expired; please sign in again.';
          return false;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> result =
              (jsonDecode(responseBody) as Map<String, dynamic>?) ?? {};
          final accepted = (result['accepted_uuids'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              {};
          final serverTime = (result['server_timestamp'] as String?) ??
              DateTime.now().toIso8601String().substring(0, 19);

          await db.transaction((txn) async {
            for (final row in pendingRows) {
              final uuid = row['uuid'] as String;
              if (accepted.contains(uuid)) {
                await txn.update(
                  'sync_log',
                  {'synced_at': serverTime},
                  where: 'uuid = ?',
                  whereArgs: [uuid],
                );
              }
            }
          });
        }
      }

      // STEP 2: PULL LATEST BRANCH/ROLE CLOUD SNAPSHOT INTO LOCAL ENCRYPTED DB
      _lastSyncStatus = 'Syncing latest records from Hostinger Cloud...';
      notifyListeners();

      final pullClient = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final pullReq = await pullClient.getUrl(Uri.parse(pullSyncEndpoint));
      pullReq.headers.set('Authorization', 'Bearer $token');
      pullReq.headers.set('Accept', 'application/json');

      final pullResp = await pullReq.close().timeout(const Duration(seconds: 25));
      final pullBody = await pullResp.transform(utf8.decoder).join();
      pullClient.close();

      if (pullResp.statusCode == 401) {
        _isCloudOnline = false;
        _lastSyncStatus = 'Cloud session unauthorized; sign in again.';
        return false;
      }

      if (pullResp.statusCode >= 200 && pullResp.statusCode < 300) {
        final decoded = jsonDecode(pullBody) as Map<String, dynamic>? ?? {};
        if (decoded['ok'] == true && decoded['data'] is Map) {
          final data = Map<String, dynamic>.from(decoded['data'] as Map);
          await _applyCloudSnapshot(db, data);
          final serverTs = (decoded['server_timestamp'] as String?) ??
              DateTime.now().toIso8601String().substring(0, 19);
          _lastSyncedAt = serverTs;
          await db.insert('app_meta', {
            'key': 'last_cloud_synced_at',
            'value': serverTs,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          _isCloudOnline = true;
          _lastSyncStatus = 'Cloud Synced ($serverTs)';
          await updatePendingCount();
          return true;
        }
      }

      _lastSyncStatus = 'Cloud sync partial (${pullResp.statusCode}).';
      await updatePendingCount();
      return false;
    } catch (e) {
      debugPrint('Cloud sync offline/deferred: $e');
      _isCloudOnline = false;
      _lastSyncStatus = 'Offline mode: queued safely on device.';
      await updatePendingCount();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  int _toPaise(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final numVal = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (numVal == null || !numVal.isFinite) return fallback;
    return (numVal * 100).round();
  }

  double _normMoney(dynamic v, {double fallback = 0.0}) {
    final paise = _toPaise(v, fallback: (fallback * 100).round());
    return paise / 100.0;
  }

  Future<void> _upsertById(
    Transaction txn,
    String table,
    Map<String, Object?> values,
  ) async {
    final id = values['id'];
    if (id != null) {
      final existing = await txn.query(
        table,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final updateMap = Map<String, Object?>.from(values)..remove('id');
        await txn.update(table, updateMap, where: 'id = ?', whereArgs: [id]);
        return;
      }
    }
    await txn.insert(table, values, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _applyCloudSnapshot(Database db, Map<String, dynamic> data) async {
    await db.transaction((txn) async {
      // 1. Branches
      for (final item in (data['branches'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          await _upsertById(txn, 'branches', {
            'id': m['id'],
            'name': m['name'],
            'code': m['code'] ?? '',
            'address': m['address'] ?? '',
            'phone': m['phone'] ?? '',
            'head_name': m['head_name'] ?? '',
            'lat': m['lat'],
            'lng': m['lng'],
            'radius_m': m['radius_m'] ?? 2000,
            'active': m['active'] ?? 1,
          });
        } catch (_) {}
      }

      // 2. Products
      for (final item in (data['products'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final minAmt = _normMoney(m['min_amt'], fallback: 5000.0).clamp(1.0, 10000000.0).toDouble();
          final maxAmt = _normMoney(m['max_amt'], fallback: 50000.0).clamp(minAmt, 10000000.0).toDouble();
          await _upsertById(txn, 'products', {
            'id': m['id'],
            'name': m['name'],
            'min_amt': minAmt,
            'min_amt_paise': (minAmt * 100).round(),
            'max_amt': maxAmt,
            'max_amt_paise': (maxAmt * 100).round(),
            'min_tenure': m['min_tenure'] ?? 3,
            'max_tenure': m['max_tenure'] ?? 24,
            'rate': m['rate'] ?? 18.0,
            'method': m['method'] ?? 'reducing',
            'fee_pct': m['fee_pct'] ?? 1.0,
            'active': m['active'] ?? 1,
          });
        } catch (_) {}
      }

      // 3. Holidays & Settings
      for (final item in (data['holidays'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          await txn.insert('holidays', {
            'day': m['day'],
            'name': m['name'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }
      for (final item in (data['settings'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          await txn.insert('settings', {
            'key': m['key'],
            'value': m['value']?.toString() ?? '',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 4. Roster Users (preserve existing local PBKDF2 password_hash!)
      for (final item in (data['users'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final existing = await txn.query('users', where: 'id = ?', whereArgs: [m['id']], limit: 1);
          if (existing.isNotEmpty) {
            await txn.update('users', {
              'name': m['name'],
              'role': m['role'],
              'branch': m['branch'] ?? '',
              'phone': m['phone'] ?? '',
              'customer_id': m['customer_id'],
              'lat': m['lat'],
              'lng': m['lng'],
              'loc_at': m['loc_at'],
              'must_change': m['must_change'] ?? 0,
            }, where: 'id = ?', whereArgs: [m['id']]);
          }
        } catch (_) {}
      }

      // 5. Employees
      for (final item in (data['employees'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final sal = _normMoney(m['salary'], fallback: 0.0);
          await _upsertById(txn, 'employees', {
            'id': m['id'],
            'user_id': m['user_id'],
            'name': m['name'],
            'designation': m['designation'],
            'branch': m['branch'],
            'manager_id': m['manager_id'],
            'phone': m['phone'],
            'email': m['email'],
            'joined': m['joined'],
            'status': m['status'] ?? 'active',
            'bg_check': m['bg_check'] ?? 'cleared',
            'docs': m['docs'],
            'salary': sal,
            'salary_paise': (sal * 100).round(),
          });
        } catch (_) {}
      }

      // 6. Customers (UIDAI Aadhaar masked last-4 only)
      for (final item in (data['customers'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final last4 = m['aadhaar_last4']?.toString();
          final maskedAadhaar = (last4 != null && last4.isNotEmpty) ? 'XXXX-XXXX-$last4' : null;
          await _upsertById(txn, 'customers', {
            'id': m['id'],
            'name': m['name'],
            'phone': m['phone'],
            'dob': m['dob'],
            'address': m['address'],
            'branch': m['branch'],
            'agent_id': m['agent_id'],
            'stage': m['stage'] ?? 'lead',
            'aadhaar': maskedAadhaar,
            'pan': m['pan'],
            'voter': m['voter'],
            'kyc_status': m['kyc_status'] ?? 'pending',
            'wa_verified': m['wa_verified'] ?? 0,
            'created': m['created'],
          });
        } catch (_) {}
      }

      // 7. KYC Forms
      for (final item in (data['kyc_forms'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final annInc = _normMoney(m['annual_income'], fallback: 120000.0);
          final safeAnnual = annInc > 0 ? annInc : 120000.0;
          final curDebt = _normMoney(m['current_debt'], fallback: 0.0);
          final coInc = _normMoney(m['co_income'], fallback: 0.0);
          final acct = m['bank_acct']?.toString() ?? '';
          final last4 = acct.length >= 4 ? acct.substring(acct.length - 4) : acct;
          await _upsertById(txn, 'kyc_forms', {
            'id': m['id'],
            'customer_id': m['customer_id'],
            'created_by': m['created_by'],
            'created_at': m['created_at'],
            'updated_at': m['updated_at'],
            'form_date': m['form_date'],
            'center_no': m['center_no'],
            'group_no': m['group_no'],
            'guardian_type': m['guardian_type'],
            'guardian_name': m['guardian_name'],
            'education': m['education'],
            'religion': m['religion'],
            'category': m['category'],
            'house_no': m['house_no'],
            'village': m['village'],
            'post_office': m['post_office'],
            'district': m['district'],
            'state': m['state'],
            'pincode': m['pincode'],
            'family': m['family'],
            'house_type': m['house_type'],
            'land_ha': m['land_ha'],
            'livestock': m['livestock'],
            'bank_name': m['bank_name'],
            'bank_acct_last4': last4,
            'passbook_name': m['passbook_name'],
            'poverty_line': m['poverty_line'],
            'dist_center_m': m['dist_center_m'],
            'dist_branch_km': m['dist_branch_km'],
            'relative_in_center': m['relative_in_center'],
            'relative_name': m['relative_name'],
            'annual_income': safeAnnual,
            'annual_income_paise': (safeAnnual * 100).round(),
            'other_loans': m['other_loans'] ?? 0,
            'current_debt': curDebt,
            'current_debt_paise': (curDebt * 100).round(),
            'repay_freq': m['repay_freq'],
            'h_name': m['h_name'],
            'h_father': m['h_father'],
            'h_dob': m['h_dob'],
            'h_address': m['h_address'],
            'consent_given': m['consent_given'] ?? 0,
            'consent_date': m['consent_date'],
            'declaration': m['declaration'] ?? 0,
            'bureau_consent': m['bureau_consent'] ?? 0,
            'address_verified': m['address_verified'] ?? 0,
            'verified_by': m['verified_by'],
            'verified_on': m['verified_on'],
            'verify_remarks': m['verify_remarks'],
            'co_name': m['co_name'],
            'co_phone': m['co_phone'],
            'co_relation': m['co_relation'],
            'co_income': coInc,
            'co_income_paise': (coInc * 100).round(),
          });
        } catch (_) {}
      }

      // 8. Pre-GRT & Members
      for (final item in (data['pregrt'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          await _upsertById(txn, 'pregrt', {
            'id': m['id'],
            'branch': m['branch'],
            'center_no': m['center_no'],
            'group_no': m['group_no'],
            'village': m['village'],
            'district': m['district'],
            'form_date': m['form_date'],
            'pso_name': m['pso_name'],
            'pso_empid': m['pso_empid'],
            'bm_name': m['bm_name'],
            'bm_empid': m['bm_empid'],
            'leader_knows_duties': m['leader_knows_duties'],
            'notes': m['notes'],
            'agent_id': m['agent_id'],
            'status': m['status'] ?? 'draft',
            'created_at': m['created_at'],
            'verified_by': m['verified_by'],
            'verified_on': m['verified_on'],
            'review_remarks': m['review_remarks'],
          });
        } catch (_) {}
      }
      for (final item in (data['pregrt_members'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final annInc = _normMoney(m['annual_income'], fallback: 0.0);
          final loanAmt = _normMoney(m['loan_amount'], fallback: 0.0);
          await txn.insert('pregrt_members', {
            'id': m['id'],
            'pregrt_id': m['pregrt_id'],
            'sno': m['sno'],
            'customer_id': m['customer_id'],
            'name': m['name'],
            'husband_name': m['husband_name'],
            'age': m['age'],
            'aadhaar4': m['aadhaar4'],
            'family_in_group': m['family_in_group'],
            'house_type': m['house_type'],
            'land_ha': m['land_ha'],
            'livestock': m['livestock'],
            'annual_income': annInc,
            'annual_income_paise': (annInc * 100).round(),
            'family_size': m['family_size'],
            'category': m['category'],
            'loan_amount': loanAmt,
            'loan_amount_paise': (loanAmt * 100).round(),
            'purpose': m['purpose'],
            'frequency': m['frequency'],
            'instalments': m['instalments'],
            'c_meeting': m['c_meeting'] ?? 1,
            'c_joint': m['c_joint'] ?? 1,
            'c_fee': m['c_fee'] ?? 1,
            'c_rate': m['c_rate'] ?? 1,
            'c_insurance': m['c_insurance'] ?? 1,
            'c_company': m['c_company'] ?? 1,
            'c_group': m['c_group'] ?? 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 9. Applications (respecting status transition trigger cleanly)
      for (final item in (data['applications'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final amt = _normMoney(m['amount'], fallback: 10000.0);
          final inc = _normMoney(m['income'], fallback: 0.0);
          final coInc = _normMoney(m['co_income'], fallback: 0.0);
          final existing = await txn.query(
            'applications',
            columns: ['status'],
            where: 'id = ?',
            whereArgs: [m['id']],
            limit: 1,
          );
          final rowData = <String, Object?>{
            'id': m['id'],
            'customer_id': m['customer_id'],
            'product_id': m['product_id'],
            'amount': amt,
            'amount_paise': (amt * 100).round(),
            'tenure': m['tenure'] ?? 12,
            'rate': m['rate'] ?? 18.0,
            'purpose': m['purpose'] ?? '',
            'income': inc,
            'income_paise': (inc * 100).round(),
            'occupation': m['occupation'],
            'employer': m['employer'],
            'co_name': m['co_name'],
            'co_phone': m['co_phone'],
            'co_relation': m['co_relation'],
            'co_income': coInc,
            'co_income_paise': (coInc * 100).round(),
            'status': m['status'] ?? 'submitted',
            'agent_id': m['agent_id'],
            'branch': m['branch'],
            'created': m['created'],
            'remarks': m['remarks'],
            'docs': m['docs'],
            'group_id': m['group_id'],
          };
          if (existing.isEmpty) {
            await txn.insert('applications', rowData, conflictAlgorithm: ConflictAlgorithm.ignore);
          } else {
            // Update non-status columns without tripping strict transition trigger
            final oldStatus = existing.first['status'] as String?;
            final newStatus = m['status'] as String?;
            if (oldStatus == newStatus) {
              await txn.update('applications', rowData, where: 'id = ?', whereArgs: [m['id']]);
            }
          }
        } catch (_) {}
      }

      // 10. Loans
      for (final item in (data['loans'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final prin = _normMoney(m['principal'], fallback: 10000.0);
          final emi = _normMoney(m['emi'], fallback: 1000.0);
          await _upsertById(txn, 'loans', {
            'id': m['id'],
            'application_id': m['application_id'],
            'customer_id': m['customer_id'],
            'product_id': m['product_id'],
            'principal': prin,
            'principal_paise': (prin * 100).round(),
            'rate': m['rate'] ?? 18.0,
            'tenure': m['tenure'] ?? 12,
            'method': m['method'] ?? 'reducing',
            'emi': emi,
            'emi_paise': (emi * 100).round(),
            'start_date': m['start_date'],
            'status': m['status'] ?? 'active',
            'closure_date': m['closure_date'],
            'branch': m['branch'],
            'agent_id': m['agent_id'],
          });
        } catch (_) {}
      }

      // 11. Schedule
      for (final item in (data['schedule'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final emi = _normMoney(m['emi']);
          final prin = _normMoney(m['principal']);
          final intr = _normMoney(m['interest']);
          final bal = _normMoney(m['balance']);
          await _upsertById(txn, 'schedule', {
            'id': m['id'],
            'loan_id': m['loan_id'],
            'no': m['no'],
            'due_date': m['due_date'],
            'emi': emi,
            'emi_paise': (emi * 100).round(),
            'principal': prin,
            'principal_paise': (prin * 100).round(),
            'interest': intr,
            'interest_paise': (intr * 100).round(),
            'balance': bal,
            'balance_paise': (bal * 100).round(),
            'paid': m['paid'] ?? 0,
            'paid_on': m['paid_on'],
          });
        } catch (_) {}
      }

      // 12. Payments
      for (final item in (data['payments'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final amt = _normMoney(m['amount']);
          await txn.insert('payments', {
            'id': m['id'],
            'loan_id': m['loan_id'],
            'schedule_id': m['schedule_id'],
            'amount': amt,
            'amount_paise': (amt * 100).round(),
            'channel': m['channel'] ?? 'CASH',
            'ref': m['ref'],
            'at': m['at'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 13. Tasks, Attendance, Requests, Leaves, Grievances
      for (final item in (data['tasks'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          final col = _normMoney(m['collected']);
          await txn.insert('tasks', {
            'id': m['id'],
            'title': m['title'],
            'customer_id': m['customer_id'],
            'ttype': m['ttype'],
            'lat': m['lat'],
            'lng': m['lng'],
            'due_date': m['due_date'],
            'officer_id': m['officer_id'],
            'status': m['status'] ?? 'open',
            'collected': col,
            'collected_paise': (col * 100).round(),
            'notes': m['notes'],
            'done_at': m['done_at'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      for (final item in (data['attendance'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          await txn.insert('attendance', {
            'id': m['id'],
            'user_id': m['user_id'],
            'day': m['day'],
            'in_time': m['in_time'],
            'out_time': m['out_time'],
            'lat': m['lat'],
            'lng': m['lng'],
            'regularised': m['regularised'] ?? 0,
            'out_lat': m['out_lat'],
            'out_lng': m['out_lng'],
            'in_dist': m['in_dist'],
            'out_dist': m['out_dist'],
            'note': m['note'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      for (final item in (data['att_requests'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          await txn.insert('att_requests', {
            'id': m['id'],
            'user_id': m['user_id'],
            'branch': m['branch'],
            'day': m['day'],
            'in_time': m['in_time'],
            'out_time': m['out_time'],
            'reason': m['reason'],
            'status': m['status'] ?? 'pending',
            'approver_role': m['approver_role'],
            'approver_id': m['approver_id'],
            'requested_at': m['requested_at'],
            'decided_by': m['decided_by'],
            'decided_at': m['decided_at'],
            'remarks': m['remarks'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      for (final item in (data['leaves'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          await txn.insert('leaves', {
            'id': m['id'],
            'user_id': m['user_id'],
            'from_d': m['from_d'],
            'to_d': m['to_d'],
            'reason': m['reason'],
            'status': m['status'] ?? 'pending',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      for (final item in (data['grievances'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        try {
          await txn.insert('grievances', {
            'id': m['id'],
            'ticket_no': m['ticket_no'],
            'customer_id': m['customer_id'],
            'name': m['name'],
            'phone': m['phone'],
            'category': m['category'],
            'details': m['details'],
            'status': m['status'] ?? 'open',
            'assigned_to': m['assigned_to'],
            'branch': m['branch'] ?? 'Bhopal Head Office',
            'resolution_notes': m['resolution_notes'],
            'resolved_at': m['resolved_at'],
            'created_at': m['created_at'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }
    });
  }
}
