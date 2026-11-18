import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/customer_model.dart';
import '../services/local_sensitive_data_service.dart';
import '../services/secure_attachment_service.dart';
import '../services/currency_amount.dart';

class CustomerProvider extends ChangeNotifier {
  static const _kycConsentNoticeVersion = 'mfi-kyc-existing-copy-v1';

  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  int _sessionGeneration = 0;

  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;

  void clearSessionData() {
    _sessionGeneration++;
    _customers = [];
    _isLoading = false;
    notifyListeners();
  }

  int _ageOn(DateTime today, DateTime birthDate) {
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> fetchCustomers({required int actorUserId}) async {
    final sessionGeneration = _sessionGeneration;
    _customers = [];
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery(
        '''
        SELECT c.*, 
               k.center_no, k.group_no, k.guardian_type, k.guardian_name, k.education,
               k.religion, k.category, k.house_type, k.land_ha, k.livestock,
               k.bank_name, k.bank_acct_last4, k.passbook_name, k.poverty_line,
               k.dist_center_m, k.dist_branch_km, k.relative_in_center, k.relative_name,
               k.annual_income, k.annual_income_paise,
               k.other_loans, k.current_debt, k.current_debt_paise, k.repay_freq,
               k.photo, k.h_name, k.h_father, k.h_dob, k.h_address, k.h_photo,
               k.consent_given, k.consent_date, k.declaration, k.bureau_consent,
               k.address_verified, k.verified_by, k.verified_on, k.verify_remarks,
               k.signed_copy, k.co_name, k.co_phone, k.co_relation,
               k.co_income, k.co_income_paise,
               k.family
        FROM customers c
        JOIN users actor ON actor.id = ?
        LEFT JOIN kyc_forms k ON c.id = k.customer_id
        WHERE actor.auth_status = 'active' AND (
          actor.role = 'admin' OR
          (actor.role IN ('manager', 'underwriter')
            AND trim(actor.branch) <> '' AND c.branch = actor.branch) OR
          (actor.role = 'field_agent' AND c.agent_id = actor.id
            AND trim(actor.branch) <> '' AND c.branch = actor.branch)
        )
        ORDER BY c.id ASC
      ''',
        [actorUserId],
      );
      if (sessionGeneration != _sessionGeneration) return;
      _customers = results.map((m) {
        final customerRow = Map<String, dynamic>.from(m);
        final lastFour = customerRow.remove('bank_acct_last4') as String?;
        customerRow['bank_acct'] = lastFour == null || lastFour.isEmpty
            ? null
            : '••••$lastFour';
        return CustomerModel.fromMap(customerRow);
      }).toList();
    } catch (_) {
      debugPrint('Customer records could not be loaded.');
    } finally {
      if (sessionGeneration == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Map<String, Object?>?> getKycForm(
    int customerId, {
    required int actorUserId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT k.*
      FROM kyc_forms k
      JOIN customers c ON c.id = k.customer_id
      JOIN users u ON u.id = ?
      WHERE k.customer_id = ? AND u.auth_status = 'active' AND (
        u.role = 'admin' OR
        (u.role IN ('manager', 'underwriter')
          AND trim(u.branch) <> '' AND c.branch = u.branch) OR
        (u.role = 'field_agent' AND c.agent_id = u.id
          AND trim(u.branch) <> '' AND c.branch = u.branch)
      )
      LIMIT 1
      ''',
      [actorUserId, customerId],
    );
    if (rows.isEmpty) return null;
    final form = Map<String, Object?>.from(rows.first);
    final lastFour = form['bank_acct_last4']?.toString() ?? '';
    form['bank_acct_masked'] = lastFour.isEmpty ? null : '••••$lastFour';
    // The edit form accepts a replacement value; callers do not need the
    // decrypted account number just to review or save unrelated KYC fields.
    form['bank_acct'] = '';
    return form;
  }

  Future<Uint8List?> readKycAttachment({
    required int customerId,
    required int actorUserId,
    required String reference,
    required bool husbandPhoto,
  }) async {
    final attachments = SecureAttachmentService();
    final column = husbandPhoto ? 'h_photo' : 'photo';
    if (customerId <= 0 ||
        actorUserId <= 0 ||
        !attachments.isAttachmentReference(reference)) {
      return null;
    }

    try {
      if (!await _canAccessCustomer(customerId, actorUserId)) return null;
      final db = await DatabaseHelper.instance.database;
      final forms = await db.query(
        'kyc_forms',
        columns: [column],
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (forms.isEmpty || forms.first[column] != reference) return null;

      final image = await attachments.readImage(reference);
      final occurredAt = DateTime.now().toIso8601String().substring(0, 19);
      final authorizedAndAudited = await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        final customers = await txn.query(
          'customers',
          columns: ['branch', 'agent_id'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (actors.isEmpty ||
            customers.isEmpty ||
            actors.first['auth_status'] != 'active') {
          return false;
        }
        final actor = actors.first;
        final role = actor['role'] as String? ?? '';
        final customerBranch = (customers.first['branch'] as String? ?? '')
            .trim();
        final inScope =
            role == 'admin' ||
            ((role == 'manager' || role == 'underwriter') &&
                (actor['branch'] as String? ?? '').trim().isNotEmpty &&
                (actor['branch'] as String? ?? '').trim() == customerBranch) ||
            (role == 'field_agent' &&
                customers.first['agent_id'] == actorUserId &&
                (actor['branch'] as String? ?? '').trim().isNotEmpty &&
                (actor['branch'] as String? ?? '').trim() == customerBranch);
        if (!inScope) return false;
        final currentForm = await txn.query(
          'kyc_forms',
          columns: [column],
          where: 'customer_id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (currentForm.isEmpty || currentForm.first[column] != reference) {
          return false;
        }
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'customer',
          'entity_id': customerId,
          'action': 'kyc_attachment_viewed',
          'actor_user_id': actorUserId,
          'actor_role': role,
          'actor_name': actor['name'],
          'occurred_at': occurredAt,
          'details': jsonEncode({'slot': column}),
        });
        return true;
      });
      return authorizedAndAudited ? image : null;
    } catch (_) {
      debugPrint('KYC image could not be opened securely.');
      return null;
    }
  }

  Future<List<CommLogModel>> getCommLogs(
    int customerId, {
    required int actorUserId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery(
      '''
      SELECT l.*
      FROM comm_logs l
      JOIN customers c ON c.id = l.customer_id
      JOIN users u ON u.id = ?
      WHERE l.customer_id = ? AND u.auth_status = 'active' AND (
        u.role = 'admin' OR
        (u.role IN ('manager', 'underwriter')
          AND trim(u.branch) <> '' AND c.branch = u.branch) OR
        (u.role = 'field_agent' AND c.agent_id = u.id
          AND trim(u.branch) <> '' AND c.branch = u.branch)
      )
      ORDER BY l.id DESC
      ''',
      [actorUserId, customerId],
    );
    return results.map((m) => CommLogModel.fromMap(m)).toList();
  }

  Future<bool> _canAccessCustomer(int customerId, int actorUserId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT 1
      FROM customers c
      JOIN users u ON u.id = ?
      WHERE c.id = ? AND u.auth_status = 'active' AND (
        u.role = 'admin' OR
        (u.role IN ('manager', 'underwriter') AND trim(u.branch) <> '' AND c.branch = u.branch) OR
        (u.role = 'field_agent' AND c.agent_id = u.id
          AND trim(u.branch) <> '' AND c.branch = u.branch)
      )
      LIMIT 1
    ''',
      [actorUserId, customerId],
    );
    return rows.isNotEmpty;
  }

  Future<void> addCommLog({
    required int customerId,
    required String channel,
    required String note,
    required int actorUserId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final nowIso = DateTime.now().toIso8601String().substring(0, 19);
    if (note.trim().isEmpty) return;
    final saved = await db.transaction<bool>((txn) async {
      final actors = await txn.query(
        'users',
        columns: ['name', 'role', 'branch', 'auth_status'],
        where: 'id = ?',
        whereArgs: [actorUserId],
        limit: 1,
      );
      final customers = await txn.query(
        'customers',
        columns: ['branch', 'agent_id'],
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (actors.isEmpty ||
          customers.isEmpty ||
          actors.first['auth_status'] != 'active' ||
          !{'admin', 'manager', 'field_agent'}.contains(actors.first['role']) ||
          (actors.first['role'] == 'field_agent' &&
              customers.first['agent_id'] != actorUserId) ||
          (actors.first['role'] != 'admin' &&
              ((actors.first['branch'] as String? ?? '').trim().isEmpty ||
                  (customers.first['branch'] as String? ?? '').trim() !=
                      (actors.first['branch'] as String? ?? '').trim()))) {
        return false;
      }
      final actor = actors.first;
      await txn.insert('comm_logs', {
        'customer_id': customerId,
        'channel': channel,
        'note': note.trim(),
        'by_name': actor['name'],
        'at': nowIso,
      });
      await txn.insert('audit_log', {
        'operation_id': const Uuid().v4(),
        'entity_type': 'customer',
        'entity_id': customerId,
        'action': 'communication_logged',
        'actor_user_id': actorUserId,
        'actor_role': actor['role'],
        'actor_name': actor['name'],
        'occurred_at': nowIso,
        'details': jsonEncode({'channel': channel}),
      });
      return true;
    });
    if (saved) notifyListeners();
  }

  Future<int?> createCustomer({
    required String name,
    required String phone,
    required String address,
    required String branch,
    required int actorUserId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final actors = await db.query(
        'users',
        where: 'id = ? AND auth_status = ?',
        whereArgs: [actorUserId, 'active'],
        limit: 1,
      );
      if (actors.isEmpty ||
          !{'admin', 'manager', 'field_agent'}.contains(actors.first['role'])) {
        return null;
      }
      final actor = actors.first;
      final actorRole = actor['role'] as String;
      final actorBranch = (actor['branch'] as String?)?.trim() ?? '';
      final requestedBranch = branch.trim();
      if (name.trim().isEmpty ||
          address.trim().isEmpty ||
          !RegExp(r'^\d{10}$').hasMatch(phone.trim()) ||
          requestedBranch.isEmpty ||
          (actorRole != 'admin' && requestedBranch != actorBranch)) {
        return null;
      }
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      late int id;
      await db.transaction((txn) async {
        final currentActors = await txn.query(
          'users',
          where: 'id = ? AND auth_status = ?',
          whereArgs: [actorUserId, 'active'],
          limit: 1,
        );
        if (currentActors.isEmpty ||
            !{
              'admin',
              'manager',
              'field_agent',
            }.contains(currentActors.first['role'])) {
          throw StateError('Customer creation access denied.');
        }
        final currentActor = currentActors.first;
        final currentRole = currentActor['role'] as String;
        final currentBranch = (currentActor['branch'] as String?)?.trim() ?? '';
        if (currentRole != 'admin' && currentBranch != requestedBranch) {
          throw StateError('Customer is outside this branch assignment.');
        }
        final branches = await txn.query(
          'branches',
          columns: ['id'],
          where: 'name = ? AND active = 1',
          whereArgs: [requestedBranch],
          limit: 1,
        );
        if (branches.isEmpty) {
          throw StateError('Selected branch is not active.');
        }
        final duplicatePhones = await txn.query(
          'customers',
          columns: ['phone'],
        );
        if (duplicatePhones.any(
          (row) =>
              (row['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '') ==
              phone.trim(),
        )) {
          throw StateError('This mobile number is already registered.');
        }
        id = await txn.insert('customers', {
          'name': name.trim(),
          'phone': phone.trim(),
          'dob': '',
          'address': address.trim(),
          'branch': requestedBranch,
          'agent_id': actorUserId,
          'stage': 'lead',
          'kyc_status': 'pending',
          'wa_verified': 0,
          'created': nowIso,
        });
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'customer',
          'entity_id': id,
          'action': 'customer_created',
          'actor_user_id': actorUserId,
          'actor_role': currentRole,
          'actor_name': (currentActor['name'] as String?) ?? '',
          'occurred_at': nowIso,
          'details': jsonEncode({'branch': requestedBranch, 'stage': 'lead'}),
        });
      });
      await fetchCustomers(actorUserId: actorUserId);
      return id;
    } catch (_) {
      debugPrint('Customer record could not be created.');
      return null;
    }
  }

  Future<bool> saveKycForm({
    required int customerId,
    required int agentId,
    required String name,
    required String phone,
    required String dob,
    required String address,
    required String centerNo,
    required String groupNo,
    required String guardianType,
    required String guardianName,
    required String education,
    required String religion,
    required String category,
    required String houseNo,
    required String village,
    required String postOffice,
    required String district,
    required String state,
    required String pincode,
    required String houseType,
    double? landHa,
    required String livestock,
    required String bankName,
    required String bankAcct,
    required String passbookName,
    required String povertyLine,
    required double annualIncome,
    double? distCenterM,
    double? distBranchKm,
    String relativeInCenter = '',
    String relativeName = '',
    int? otherLoans,
    double? currentDebt,
    String repayFreq = '',
    String coName = '',
    String coPhone = '',
    String coRelation = '',
    double? coIncome,
    String? photo,
    String husbandName = '',
    String husbandFather = '',
    String husbandDob = '',
    String husbandAddress = '',
    String? husbandPhoto,
    int consentGiven = 0,
    int declaration = 0,
    int bureauConsent = 0,
    int addressVerified = 0,
    String? signedCopy,
    List<Map<String, dynamic>> family = const [],
  }) async {
    try {
      final possibleOrphanedAttachments = <String>{};
      if (agentId <= 0 ||
          declaration != 1 ||
          !{0, 1}.contains(consentGiven) ||
          !{0, 1}.contains(bureauConsent) ||
          !{0, 1}.contains(addressVerified) ||
          !annualIncome.isFinite ||
          annualIncome <= 0 ||
          !CurrencyAmount.hasPaisePrecision(annualIncome) ||
          (landHa != null && (!landHa.isFinite || landHa < 0)) ||
          (distCenterM != null && (!distCenterM.isFinite || distCenterM < 0)) ||
          (distBranchKm != null &&
              (!distBranchKm.isFinite || distBranchKm < 0)) ||
          (currentDebt != null &&
              (!currentDebt.isFinite ||
                  currentDebt < 0 ||
                  !CurrencyAmount.hasPaisePrecision(currentDebt))) ||
          (coIncome != null &&
              (!coIncome.isFinite ||
                  coIncome < 0 ||
                  !CurrencyAmount.hasPaisePrecision(coIncome))) ||
          (otherLoans != null && otherLoans < 0) ||
          !{'husband', 'father'}.contains(guardianType) ||
          guardianName.trim().isEmpty ||
          name.trim().isEmpty ||
          !RegExp(r'^\+?[0-9\s()-]{10,20}$').hasMatch(phone.trim()) ||
          DateTime.tryParse(dob.trim()) == null ||
          address.trim().isEmpty ||
          (guardianType == 'husband' && consentGiven != 1) ||
          (guardianType != 'husband' && consentGiven != 0)) {
        return false;
      }
      final db = await DatabaseHelper.instance.database;
      final attachments = SecureAttachmentService();
      for (final reference in [photo, husbandPhoto]) {
        if (attachments.isAttachmentReference(reference)) {
          await attachments.validateImageReference(reference!);
        }
      }
      final sensitiveData = LocalSensitiveDataService();
      final clearBankAccount = bankAcct.trim();
      final protectedNewBankAccount = clearBankAccount.isEmpty
          ? null
          : await sensitiveData.encrypt(clearBankAccount);
      final newBankAccountLastFour = clearBankAccount.isEmpty
          ? null
          : sensitiveData.lastFour(clearBankAccount);
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final todayStr = nowIso.substring(0, 10);

      await db.transaction((txn) async {
        final agents = await txn.query(
          'users',
          columns: ['role', 'name', 'branch'],
          where: "id = ? AND auth_status = 'active'",
          whereArgs: [agentId],
          limit: 1,
        );
        if (agents.isEmpty ||
            !{
              'admin',
              'manager',
              'field_agent',
            }.contains(agents.first['role'])) {
          throw StateError('This account cannot capture KYC forms.');
        }
        final customers = await txn.query(
          'customers',
          columns: [
            'id',
            'branch',
            'agent_id',
            'name',
            'phone',
            'dob',
            'address',
          ],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customers.isEmpty) throw StateError('Customer does not exist.');
        final customer = customers.first;
        final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
        final parsedDob = DateTime.tryParse(dob.trim());
        if (digits.length != 10 ||
            village.trim().isEmpty ||
            district.trim().isEmpty ||
            state.trim().isEmpty ||
            !RegExp(r'^[0-9]{6}$').hasMatch(pincode.trim())) {
          throw StateError(
            'Required customer identity or address fields are missing.',
          );
        }
        if (parsedDob == null ||
            _ageOn(DateTime.now(), parsedDob) < 18 ||
            _ageOn(DateTime.now(), parsedDob) > 65) {
          throw StateError('Applicant must be between 18 and 65 years old.');
        }
        final customerBranch = (customer['branch'] as String? ?? '').trim();
        final role = agents.first['role'] as String;
        final existingPhoneRows = await txn.query(
          'customers',
          columns: ['id', 'phone'],
          where: 'id != ?',
          whereArgs: [customerId],
        );
        if (existingPhoneRows.any(
          (row) =>
              (row['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '') ==
              digits,
        )) {
          throw StateError('This mobile number is already registered.');
        }
        if (role == 'field_agent' && customer['agent_id'] != agentId) {
          throw StateError('Customer is outside this officer assignment.');
        }
        if (role != 'admin' &&
            ((agents.first['branch'] as String? ?? '').trim().isEmpty ||
                (agents.first['branch'] as String? ?? '').trim() !=
                    customerBranch)) {
          throw StateError('Customer is outside this account branch.');
        }

        final existing = await txn.query(
          'kyc_forms',
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
        final protectedBankAccount = clearBankAccount.isEmpty
            ? (existing.isEmpty ? null : existing.first['bank_acct'])
            : protectedNewBankAccount;
        final bankAccountLastFour = clearBankAccount.isEmpty
            ? (existing.isEmpty ? null : existing.first['bank_acct_last4'])
            : newBankAccountLastFour;
        if (existing.isNotEmpty) {
          for (final (column, replacement) in [
            ('photo', photo),
            ('h_photo', husbandPhoto),
          ]) {
            final oldReference = existing.first[column]?.toString() ?? '';
            final newReference = replacement ?? oldReference;
            if (oldReference != newReference &&
                SecureAttachmentService().isAttachmentReference(oldReference)) {
              possibleOrphanedAttachments.add(oldReference);
            }
          }
        }

        final formMap = {
          'customer_id': customerId,
          'created_by': existing.isEmpty
              ? agentId
              : existing.first['created_by'] ?? agentId,
          'updated_by': agentId,
          'created_at': existing.isEmpty
              ? nowIso
              : existing.first['created_at'] ?? nowIso,
          'updated_at': nowIso,
          'form_date': todayStr,
          'center_no': centerNo,
          'group_no': groupNo,
          'guardian_type': guardianType,
          'guardian_name': guardianName,
          'education': education,
          'religion': religion,
          'category': category,
          'house_no': houseNo,
          'village': village,
          'post_office': postOffice,
          'district': district,
          'state': state,
          'pincode': pincode,
          'family': jsonEncode(family),
          'house_type': houseType,
          'land_ha': landHa,
          'livestock': livestock,
          'bank_name': bankName,
          'bank_acct': protectedBankAccount,
          'bank_acct_last4': bankAccountLastFour,
          'passbook_name': passbookName,
          'poverty_line': povertyLine,
          'dist_center_m': distCenterM,
          'dist_branch_km': distBranchKm,
          'relative_in_center': relativeInCenter,
          'relative_name': relativeName,
          'annual_income': annualIncome,
          'annual_income_paise': CurrencyAmount.toMinorUnits(annualIncome),
          'other_loans': otherLoans,
          'current_debt': currentDebt,
          'current_debt_paise': currentDebt == null
              ? null
              : CurrencyAmount.toMinorUnits(currentDebt),
          'repay_freq': repayFreq,
          'photo':
              photo ?? (existing.isNotEmpty ? existing.first['photo'] : null),
          'h_name': husbandName,
          'h_father': husbandFather,
          'h_dob': husbandDob,
          'h_address': husbandAddress,
          'h_photo':
              husbandPhoto ??
              (existing.isNotEmpty ? existing.first['h_photo'] : null),
          'consent_given': consentGiven,
          'consent_date': consentGiven == 1 ? todayStr : '',
          'declaration': declaration,
          'bureau_consent': bureauConsent,
          'address_verified': addressVerified,
          // Form capture and address visit are not a KYC approval. A separate
          // authorized reviewer fills these fields after checking originals.
          'verified_by': '',
          'verified_on': '',
          'verify_remarks': '',
          'signed_copy':
              signedCopy ??
              (existing.isNotEmpty ? existing.first['signed_copy'] : null),
          'co_name': coName,
          'co_phone': coPhone,
          'co_relation': coRelation,
          'co_income': coIncome,
          'co_income_paise': coIncome == null
              ? null
              : CurrencyAmount.toMinorUnits(coIncome),
        };

        if (existing.isEmpty) {
          await txn.insert('kyc_forms', formMap);
        } else {
          await txn.update(
            'kyc_forms',
            formMap,
            where: 'customer_id = ?',
            whereArgs: [customerId],
          );
        }

        await txn.update(
          'customers',
          {
            'name': name.trim(),
            'phone': phone.trim(),
            'dob': dob.trim(),
            'address': address.trim(),
            'kyc_status': 'pending',
            'stage': 'customer',
          },
          where: 'id = ?',
          whereArgs: [customerId],
        );
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'customer',
          'entity_id': customerId,
          'action': 'kyc_form_saved',
          'actor_user_id': agentId,
          'actor_role': role,
          'actor_name': agents.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({'status': 'pending'}),
        });
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'customer',
          'entity_id': customerId,
          'action': 'kyc_consent_snapshot_captured',
          'actor_user_id': agentId,
          'actor_role': role,
          'actor_name': agents.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'notice_version': _kycConsentNoticeVersion,
            'notice_approval': 'pending_owner_legal_review',
            'capture_method': 'field_officer_entered_in_app',
            'applicant_declaration_given': declaration == 1,
            'husband_loan_consent_applicable': guardianType == 'husband',
            'husband_loan_consent_given':
                guardianType == 'husband' && consentGiven == 1,
            'credit_bureau_insurance_sharing_consent_given': bureauConsent == 1,
            'address_visit_attested': addressVerified == 1,
          }),
        });
      });

      for (final reference in possibleOrphanedAttachments) {
        try {
          final stillUsed = await db.rawQuery(
            'SELECT COUNT(*) AS count FROM kyc_forms WHERE photo = ? OR h_photo = ?',
            [reference, reference],
          );
          if ((stillUsed.first['count'] as int? ?? 0) == 0) {
            await attachments.deleteImage(reference);
          }
        } catch (_) {
          // A failed cleanup leaves an encrypted orphan and does not undo the
          // committed KYC data.
        }
      }

      await fetchCustomers(actorUserId: agentId);
      return true;
    } catch (_) {
      debugPrint('KYC information could not be saved.');
      return false;
    }
  }

  Future<bool> verifyKycDocuments({
    required int customerId,
    required int actorUserId,
    required String aadhaar,
    required String pan,
    required String voter,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final normalizedAadhaar = aadhaar.replaceAll(' ', '');
      final normalizedPan = pan.toUpperCase().trim();
      final normalizedVoter = voter.toUpperCase().trim();
      if (normalizedAadhaar.length != 12 ||
          int.tryParse(normalizedAadhaar) == null ||
          !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(normalizedPan) ||
          (normalizedVoter.isNotEmpty &&
              !RegExp(r'^[A-Z]{3}[0-9]{7}$').hasMatch(normalizedVoter))) {
        return false;
      }
      final maskedAadhaar = 'XXXXXXXX${normalizedAadhaar.substring(8)}';
      final maskedPan = 'XXXXX${normalizedPan.substring(9)}';
      final maskedVoter = normalizedVoter.isEmpty
          ? null
          : 'XXXXXXX${normalizedVoter.substring(7)}';

      final update = <String, Object?>{
        'aadhaar': maskedAadhaar,
        'pan': maskedPan,
        'kyc_status': 'pending',
      };
      if (maskedVoter != null) update['voter'] = maskedVoter;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch'],
          where: "id = ? AND auth_status = 'active'",
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty ||
            !{
              'admin',
              'manager',
              'field_agent',
            }.contains(actors.first['role'])) {
          throw StateError('This account cannot record KYC documents.');
        }
        final customerRows = await txn.query(
          'customers',
          columns: ['branch', 'agent_id'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customerRows.isEmpty) throw StateError('Customer does not exist.');
        final role = actors.first['role'] as String;
        final customerBranch = (customerRows.first['branch'] as String? ?? '')
            .trim();
        if ((role == 'field_agent' &&
                customerRows.first['agent_id'] != actorUserId) ||
            (role != 'admin' &&
                ((actors.first['branch'] as String? ?? '').trim().isEmpty ||
                    (actors.first['branch'] as String? ?? '').trim() !=
                        customerBranch))) {
          throw StateError('Customer is outside this account scope.');
        }
        final updated = await txn.update(
          'customers',
          update,
          where: "id = ? AND lower(kyc_status) != 'verified'",
          whereArgs: [customerId],
        );
        if (updated != 1) {
          throw StateError('Customer is not eligible for update.');
        }
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'customer',
          'entity_id': customerId,
          'action': 'kyc_documents_recorded',
          'actor_user_id': actorUserId,
          'actor_role': role,
          'actor_name': actors.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'document_types': [
              'aadhaar',
              'pan',
              if (maskedVoter != null) 'voter',
            ],
            'status': 'pending',
            'issuer_check': false,
          }),
        });
      });

      await fetchCustomers(actorUserId: actorUserId);
      return true;
    } catch (_) {
      debugPrint('KYC document review could not be recorded.');
      return false;
    }
  }

  Future<bool> approveKyc({
    required int customerId,
    required int reviewerId,
    required String remarks,
    required bool originalDocumentsChecked,
  }) async {
    final cleanRemarks = remarks.trim();
    if (reviewerId <= 0 ||
        cleanRemarks.length < 10 ||
        !originalDocumentsChecked) {
      return false;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final operationId = const Uuid().v4();

      await db.transaction((txn) async {
        final reviewers = await txn.query(
          'users',
          columns: ['id', 'name', 'role', 'branch'],
          where: "id = ? AND auth_status = 'active'",
          whereArgs: [reviewerId],
          limit: 1,
        );
        if (reviewers.isEmpty) throw StateError('Reviewer is not active.');
        final reviewer = reviewers.first;
        final role = reviewer['role'] as String? ?? '';
        if (!{'admin', 'manager', 'underwriter'}.contains(role)) {
          throw StateError('Reviewer cannot approve KYC.');
        }
        final customerRows = await txn.query(
          'customers',
          columns: ['branch'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customerRows.isEmpty) throw StateError('Customer does not exist.');
        if (role != 'admin' &&
            ((reviewer['branch'] as String? ?? '').trim().isEmpty ||
                (reviewer['branch'] as String? ?? '').trim() !=
                    (customerRows.first['branch'] as String? ?? '').trim())) {
          throw StateError('Customer is outside this reviewer branch.');
        }

        final forms = await txn.query(
          'kyc_forms',
          columns: [
            'created_by',
            'updated_by',
            'declaration',
            'address_verified',
          ],
          where: 'customer_id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (forms.isEmpty ||
            ((forms.first['updated_by'] as int?) ??
                    (forms.first['created_by'] as int?)) ==
                reviewerId ||
            (forms.first['declaration'] as int? ?? 0) != 1 ||
            (forms.first['address_verified'] as int? ?? 0) != 1) {
          throw StateError('KYC prerequisites or maker-checker rule failed.');
        }

        final changed = await txn.update(
          'customers',
          {'kyc_status': 'verified'},
          where: "id = ? AND kyc_status = 'pending'",
          whereArgs: [customerId],
        );
        if (changed != 1) throw StateError('KYC is not pending review.');

        await txn.update(
          'kyc_forms',
          {
            'verified_by': reviewer['name'],
            'verified_on': nowIso.substring(0, 10),
            'verify_remarks': cleanRemarks,
          },
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
        await txn.insert('audit_log', {
          'operation_id': operationId,
          'entity_type': 'customer',
          'entity_id': customerId,
          'action': 'kyc_approved',
          'actor_user_id': reviewerId,
          'actor_role': role,
          'actor_name': reviewer['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'original_documents_checked': true,
            'remarks': cleanRemarks,
          }),
        });
      });

      await fetchCustomers(actorUserId: reviewerId);
      return true;
    } catch (_) {
      debugPrint('KYC review could not be approved.');
      return false;
    }
  }

  Future<bool> verifyWhatsAppOtp({
    required int customerId,
    required String otp,
    required int actorUserId,
  }) async {
    if (!await _canAccessCustomer(customerId, actorUserId)) return false;
    // Development-only UI exercise. It never changes verification state.
    return kDebugMode && otp == '123456';
  }
}
