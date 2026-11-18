import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/pregrt_model.dart';
import '../services/currency_amount.dart';

class PreGrtProvider extends ChangeNotifier {
  List<PreGrtModel> _preGrts = [];
  bool _isLoading = false;
  int _sessionGeneration = 0;

  List<PreGrtModel> get preGrts => _preGrts;
  bool get isLoading => _isLoading;

  void clearSessionData() {
    _sessionGeneration++;
    _preGrts = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPreGrts(int actorUserId) async {
    final sessionGeneration = _sessionGeneration;
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final list = await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty || actors.first['auth_status'] != 'active') {
          return <PreGrtModel>[];
        }
        final actor = actors.first;
        final role = actor['role'] as String? ?? '';
        final branch = (actor['branch'] as String? ?? '').trim();
        if (!{
              'admin',
              'manager',
              'underwriter',
              'field_agent',
            }.contains(role) ||
            (role != 'admin' && branch.isEmpty)) {
          return <PreGrtModel>[];
        }

        final where = role == 'admin'
            ? null
            : role == 'field_agent'
            ? 'agent_id = ? AND branch = ?'
            : 'branch = ?';
        final whereArgs = role == 'admin'
            ? null
            : role == 'field_agent'
            ? <Object?>[actorUserId, branch]
            : <Object?>[branch];
        final groupRows = await txn.query(
          'pregrt',
          where: where,
          whereArgs: whereArgs,
          orderBy: 'id DESC',
        );

        final result = <PreGrtModel>[];
        for (final group in groupRows) {
          final members = await txn.query(
            'pregrt_members',
            where: 'pregrt_id = ?',
            whereArgs: [group['id']],
            orderBy: 'sno ASC',
          );
          result.add(
            PreGrtModel.fromMap(
              group,
              members: members
                  .map((member) => PreGrtMemberModel.fromMap(member))
                  .toList(),
            ),
          );
        }
        return result;
      });
      if (sessionGeneration != _sessionGeneration) return;
      _preGrts = list;
    } catch (_) {
      debugPrint('Pre-GRT records could not be loaded.');
    } finally {
      if (sessionGeneration == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> reviewPreGrt({
    required int pregrtId,
    required String status, // 'verified' or 'returned'
    required String reviewRemarks,
    required int actorUserId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (pregrtId <= 0 ||
          actorUserId <= 0 ||
          !{'verified', 'returned'}.contains(status) ||
          reviewRemarks.trim().isEmpty) {
        return false;
      }
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final operationId = const Uuid().v4();
      await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty || actors.first['auth_status'] != 'active') {
          throw StateError('Reviewer account is not active.');
        }
        final actor = actors.first;
        final role = actor['role'] as String? ?? '';
        final branch = (actor['branch'] as String? ?? '').trim();
        if (!{'admin', 'manager'}.contains(role) ||
            (role == 'manager' && branch.isEmpty)) {
          throw StateError('This account cannot review Pre-GRT.');
        }
        final groups = await txn.query(
          'pregrt',
          columns: ['branch', 'agent_id'],
          where: "id = ? AND status = 'submitted'",
          whereArgs: [pregrtId],
          limit: 1,
        );
        if (groups.isEmpty) throw StateError('Group is no longer pending.');
        final group = groups.first;
        if ((role == 'manager' &&
                (group['branch'] as String? ?? '').trim() != branch) ||
            group['agent_id'] == actorUserId) {
          throw StateError('This group is outside the reviewer scope.');
        }
        final memberChecks = await txn.query(
          'pregrt_members',
          columns: [
            'c_meeting',
            'c_joint',
            'c_fee',
            'c_rate',
            'c_insurance',
            'c_company',
            'c_group',
          ],
          where: 'pregrt_id = ?',
          whereArgs: [pregrtId],
        );
        if (memberChecks.isEmpty ||
            memberChecks.any(
              (member) => member.values.any((value) => value != 1),
            )) {
          throw StateError('All member declarations must be complete.');
        }
        final changed = await txn.update(
          'pregrt',
          {
            'status': status,
            'review_remarks': reviewRemarks.trim(),
            'verified_by': actors.first['name'],
            'verified_on': todayStr,
          },
          where: "id = ? AND status = 'submitted'",
          whereArgs: [pregrtId],
        );
        if (changed != 1) throw StateError('Group is no longer pending.');
        await txn.insert('audit_log', {
          'operation_id': operationId,
          'entity_type': 'pregrt',
          'entity_id': pregrtId,
          'action': 'pregrt_$status',
          'actor_user_id': actorUserId,
          'actor_role': role,
          'actor_name': actor['name'],
          'occurred_at': DateTime.now().toIso8601String().substring(0, 19),
          'details': jsonEncode({
            'from_status': 'submitted',
            'to_status': status,
            'maker_user_id': group['agent_id'],
            'remarks': reviewRemarks.trim(),
          }),
        });
      });

      await fetchPreGrts(actorUserId);
      return true;
    } catch (_) {
      debugPrint('Pre-GRT review could not be recorded.');
      return false;
    }
  }

  Future<int?> createPreGrt({
    required int actorUserId,
    required String centerNo,
    required String groupNo,
    required String village,
    required String district,
    required String notes,
    required List<Map<String, dynamic>> members,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (centerNo.trim().isEmpty ||
          groupNo.trim().isEmpty ||
          village.trim().isEmpty ||
          district.trim().isEmpty ||
          members.length < 5 ||
          members.length > 10) {
        return null;
      }
      final actors = await db.query(
        'users',
        columns: ['name', 'role', 'branch', 'auth_status'],
        where: 'id = ?',
        whereArgs: [actorUserId],
        limit: 1,
      );
      if (actors.isEmpty ||
          actors.first['auth_status'] != 'active' ||
          !{'admin', 'manager', 'field_agent'}.contains(actors.first['role'])) {
        return null;
      }
      final actor = actors.first;
      final branch = (actor['branch'] as String?)?.trim() ?? '';
      if (branch.isEmpty) return null;

      final normalizedMembers = <Map<String, dynamic>>[];
      final seenCustomerIds = <int>{};
      for (final member in members) {
        final customerId = member['customer_id'];
        final loanAmountValue = member['loan_amount'];
        final loanAmount = loanAmountValue is num
            ? loanAmountValue.toDouble()
            : double.nan;
        if (customerId is! int ||
            !seenCustomerIds.add(customerId) ||
            !loanAmount.isFinite ||
            loanAmount <= 0 ||
            !CurrencyAmount.hasPaisePrecision(loanAmount) ||
            (member['purpose'] as String?)?.trim().isNotEmpty != true ||
            ![
              'c_meeting',
              'c_joint',
              'c_fee',
              'c_rate',
              'c_insurance',
              'c_company',
              'c_group',
            ].every((field) => member[field] == 1)) {
          return null;
        }
        final customerRows = await db.rawQuery(
          '''
          SELECT c.id, c.name, c.branch, c.agent_id, c.kyc_status, c.dob,
                 c.aadhaar, c.voter, k.center_no, k.group_no, k.village,
                 k.district, k.guardian_name, k.house_type, k.land_ha,
                 k.livestock, k.annual_income, k.annual_income_paise,
                 k.category
          FROM customers c
          JOIN kyc_forms k ON k.customer_id = c.id
          WHERE c.id = ?
        ''',
          [customerId],
        );
        if (customerRows.isEmpty) return null;
        final customer = customerRows.first;
        final dob = DateTime.tryParse(customer['dob'] as String? ?? '');
        if (dob == null) return null;
        var age = DateTime.now().year - dob.year;
        final now = DateTime.now();
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
        final annualIncome = customer['annual_income_paise'] is num
            ? CurrencyAmount.readStoredValue(
                customer,
                'annual_income_paise',
                'annual_income',
              )
            : (customer['annual_income'] as num?)?.toDouble();
        if (customer['kyc_status'] != 'verified' ||
            customer['name'] == null ||
            age < 18 ||
            age > 65 ||
            annualIncome == null ||
            annualIncome <= 0 ||
            customer['center_no'] != centerNo.trim() ||
            customer['group_no'] != groupNo.trim() ||
            customer['village'] != village.trim() ||
            customer['district'] != district.trim() ||
            (actor['role'] != 'admin' && customer['branch'] != branch) ||
            (actor['role'] == 'field_agent' &&
                customer['agent_id'] != actorUserId)) {
          return null;
        }
        final aadhaar = customer['aadhaar'] as String? ?? '';
        final voter = customer['voter'] as String? ?? '';
        normalizedMembers.add({
          '_customer_snapshot': jsonEncode(customer),
          'customer_id': customerId,
          'name': customer['name'],
          'husband_name': customer['guardian_name'],
          'age': age,
          'voter_id': voter.isEmpty
              ? null
              : voter.substring(voter.length > 4 ? voter.length - 4 : 0),
          'aadhaar4': aadhaar.length >= 4
              ? aadhaar.substring(aadhaar.length - 4)
              : null,
          'house_type': customer['house_type'],
          'land_ha': customer['land_ha'],
          'livestock': customer['livestock'],
          'annual_income': annualIncome,
          'annual_income_paise': CurrencyAmount.toMinorUnits(annualIncome),
          'category': customer['category'],
          'loan_amount': loanAmount,
          'loan_amount_paise': CurrencyAmount.toMinorUnits(loanAmount),
          'purpose': (member['purpose'] as String).trim(),
          for (final field in [
            'c_meeting',
            'c_joint',
            'c_fee',
            'c_rate',
            'c_insurance',
            'c_company',
            'c_group',
          ])
            field: member[field],
        });
      }

      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final todayStr = nowIso.substring(0, 10);
      late int pgId;
      await db.transaction((txn) async {
        final currentActors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (currentActors.isEmpty ||
            currentActors.first['auth_status'] != 'active' ||
            !{
              'admin',
              'manager',
              'field_agent',
            }.contains(currentActors.first['role'])) {
          throw StateError('This account cannot create a Pre-GRT group.');
        }
        final currentActor = currentActors.first;
        final currentBranch = (currentActor['branch'] as String? ?? '').trim();
        if (currentBranch.isEmpty ||
            currentBranch != branch ||
            currentActor['role'] != actor['role']) {
          throw StateError('The account branch changed. Reload and try again.');
        }
        final activeBranches = await txn.query(
          'branches',
          columns: ['id'],
          where: 'name = ? AND active = 1',
          whereArgs: [currentBranch],
          limit: 1,
        );
        if (activeBranches.isEmpty) {
          throw StateError('Selected branch is no longer active.');
        }

        for (final member in normalizedMembers) {
          final currentCustomers = await txn.rawQuery(
            '''
            SELECT c.id, c.name, c.branch, c.agent_id, c.kyc_status, c.dob,
                   c.aadhaar, c.voter, k.center_no, k.group_no, k.village,
                   k.district, k.guardian_name, k.house_type, k.land_ha,
                   k.livestock, k.annual_income, k.annual_income_paise,
                   k.category
            FROM customers c
            JOIN kyc_forms k ON k.customer_id = c.id
            WHERE c.id = ?
            ''',
            [member['customer_id']],
          );
          if (currentCustomers.isEmpty ||
              jsonEncode(currentCustomers.first) !=
                  member['_customer_snapshot'] ||
              (currentActor['role'] == 'field_agent' &&
                  currentCustomers.first['agent_id'] != actorUserId)) {
            throw StateError(
              'A member record changed or left this assignment. Reload the group.',
            );
          }
        }

        pgId = await txn.insert('pregrt', {
          'branch': branch,
          'center_no': centerNo.trim(),
          'group_no': groupNo.trim(),
          'village': village.trim(),
          'district': district.trim(),
          'form_date': todayStr,
          'pso_name': currentActor['name'],
          'pso_empid': '',
          'bm_name': null,
          'bm_empid': null,
          'leader_knows_duties': null,
          'notes': notes.trim(),
          'agent_id': actorUserId,
          'status': 'submitted',
          'created_at': nowIso,
        });

        for (int i = 0; i < normalizedMembers.length; i++) {
          final member = normalizedMembers[i];
          await txn.insert('pregrt_members', {
            'pregrt_id': pgId,
            'sno': i + 1,
            'customer_id': member['customer_id'],
            'name': member['name'],
            'husband_name': member['husband_name'],
            'age': member['age'],
            'voter_id': member['voter_id'],
            'aadhaar4': member['aadhaar4'],
            'family_in_group': null,
            'house_type': member['house_type'],
            'land_ha': member['land_ha'],
            'livestock': member['livestock'],
            'annual_income': member['annual_income'],
            'annual_income_paise': member['annual_income_paise'],
            'family_size': null,
            'category': member['category'],
            'loan_amount': member['loan_amount'],
            'loan_amount_paise': member['loan_amount_paise'],
            'purpose': (member['purpose'] as String).trim(),
            'frequency': null,
            'instalments': null,
            'c_meeting': member['c_meeting'],
            'c_joint': member['c_joint'],
            'c_fee': member['c_fee'],
            'c_rate': member['c_rate'],
            'c_insurance': member['c_insurance'],
            'c_company': member['c_company'],
            'c_group': member['c_group'],
          });
        }
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'pregrt',
          'entity_id': pgId,
          'action': 'pregrt_submitted',
          'actor_user_id': actorUserId,
          'actor_role': currentActor['role'],
          'actor_name': currentActor['name'],
          'occurred_at': nowIso,
          'details': '{}',
        });
      });

      await fetchPreGrts(actorUserId);
      return pgId;
    } catch (_) {
      debugPrint('Pre-GRT record could not be created.');
      return null;
    }
  }
}
