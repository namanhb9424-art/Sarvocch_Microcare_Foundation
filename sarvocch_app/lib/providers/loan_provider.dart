import 'dart:math' show max, min, pow;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/application_model.dart';
import '../models/loan_model.dart';
import '../models/loan_product_model.dart';
import '../services/currency_amount.dart';
import '../services/sync_service.dart';

class LoanProvider extends ChangeNotifier {
  List<ApplicationModel> _applications = [];
  List<LoanModel> _loans = [];
  List<LoanProductModel> _products = [];
  bool _isLoading = false;
  int _sessionGeneration = 0;

  // KPI Metrics
  double _totalDisbursed = 0.0;
  double _totalOutstanding = 0.0;
  double _totalOverdue = 0.0;
  int _activeLoansCount = 0;
  int _overdueLoansCount = 0;
  double _recoveryRate = 0.0;
  Map<String, double> _branchPortfolio = {};

  List<ApplicationModel> get applications => _applications;
  List<LoanModel> get loans => _loans;
  List<LoanProductModel> get products => _products;
  bool get isLoading => _isLoading;

  double get totalDisbursed => _totalDisbursed;
  double get totalOutstanding => _totalOutstanding;
  double get totalOverdue => _totalOverdue;
  int get activeLoansCount => _activeLoansCount;
  int get overdueLoansCount => _overdueLoansCount;
  double get recoveryRate => _recoveryRate;
  Map<String, double> get branchPortfolio => _branchPortfolio;

  void clearSessionData() {
    _sessionGeneration++;
    _applications = [];
    _loans = [];
    _products = [];
    _isLoading = false;
    _calculateKpis(0);
    notifyListeners();
  }

  Future<void> fetchAll({required int actorUserId}) async {
    final sessionGeneration = _sessionGeneration;
    _applications = [];
    _loans = [];
    _products = [];
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final snapshot = await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty || actors.first['auth_status'] != 'active') {
          return null;
        }
        final role = actors.first['role'] as String? ?? '';
        final branch = (actors.first['branch'] as String? ?? '').trim();
        if (!{
              'admin',
              'manager',
              'underwriter',
              'field_agent',
            }.contains(role) ||
            (role != 'admin' && branch.isEmpty)) {
          return null;
        }

        final applicationScope = role == 'admin'
            ? ''
            : role == 'field_agent'
            ? 'WHERE a.agent_id = ? AND a.branch = ?'
            : 'WHERE a.branch = ?';
        final loanScope = role == 'admin'
            ? ''
            : role == 'field_agent'
            ? 'WHERE l.agent_id = ? AND l.branch = ?'
            : 'WHERE l.branch = ?';
        final scopeArgs = role == 'admin'
            ? <Object?>[]
            : role == 'field_agent'
            ? <Object?>[actorUserId, branch]
            : <Object?>[branch];

        final prodRows = await txn.query('products', where: 'active = 1');
        final appRows = await txn.rawQuery('''
          SELECT a.*, c.name as customer_name, c.phone as customer_phone,
                 COALESCE(a.product_name_snapshot, p.name) as product_name,
                 ae.income_total, ae.income_total_paise,
                 ae.expense_total, ae.expense_total_paise,
                 ae.net_saving, ae.net_saving_paise
          FROM applications a
          LEFT JOIN customers c ON a.customer_id = c.id
          LEFT JOIN products p ON a.product_id = p.id
          LEFT JOIN app_extra ae ON a.id = ae.application_id
          $applicationScope
          ORDER BY a.id DESC
        ''', scopeArgs);
        final loanRows = await txn.rawQuery('''
          SELECT l.*, c.name as customer_name, c.phone as customer_phone, p.name as product_name,
                 (SELECT COUNT(*) FROM schedule WHERE loan_id = l.id AND paid = 1) as paid_count,
                 (SELECT COUNT(*) FROM schedule WHERE loan_id = l.id) as total_count,
                 (SELECT IFNULL(SUM(COALESCE(amount_paise, CAST(ROUND(amount * 100) AS INTEGER))), 0) FROM payments WHERE loan_id = l.id) as paid_total_paise,
                 (SELECT IFNULL(SUM(COALESCE(principal_paise, CAST(ROUND(principal * 100) AS INTEGER))), 0) FROM schedule WHERE loan_id = l.id AND paid = 0) as outstanding_paise,
                 (SELECT due_date FROM schedule WHERE loan_id = l.id AND paid = 0 ORDER BY no ASC LIMIT 1) as next_due_date,
                 (SELECT COALESCE(emi_paise, CAST(ROUND(emi * 100) AS INTEGER)) FROM schedule WHERE loan_id = l.id AND paid = 0 ORDER BY no ASC LIMIT 1) as next_due_amount_paise,
                 (SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END FROM schedule WHERE loan_id = l.id AND paid = 0 AND due_date < date('now')) as has_overdue
          FROM loans l
          LEFT JOIN customers c ON l.customer_id = c.id
          LEFT JOIN products p ON l.product_id = p.id
          $loanScope
          ORDER BY l.id DESC
        ''', scopeArgs);
        final overdueResult = await txn.rawQuery('''
          SELECT COALESCE(SUM(COALESCE(
            s.emi_paise, CAST(ROUND(s.emi * 100) AS INTEGER)
          )), 0) as overdue_paise
          FROM schedule s
          JOIN loans l ON s.loan_id = l.id
          WHERE s.paid = 0 AND s.due_date < date('now') AND l.status = 'active'
            ${role == 'admin'
            ? ''
            : role == 'field_agent'
            ? 'AND l.agent_id = ? AND l.branch = ?'
            : 'AND l.branch = ?'}
        ''', scopeArgs);
        return (
          products: prodRows,
          applications: appRows,
          loans: loanRows,
          overduePaise:
              (overdueResult.first['overdue_paise'] as num?)?.toInt() ?? 0,
        );
      });
      if (sessionGeneration != _sessionGeneration) return;
      if (snapshot == null) {
        _calculateKpis(0);
        return;
      }
      _products = snapshot.products
          .map((row) => LoanProductModel.fromMap(row))
          .toList();
      _applications = snapshot.applications
          .map((row) => ApplicationModel.fromMap(row))
          .toList();
      _loans = snapshot.loans.map((row) => LoanModel.fromMap(row)).toList();
      _calculateKpis(snapshot.overduePaise);
    } catch (_) {
      debugPrint('Loan portfolio data could not be loaded.');
      if (sessionGeneration == _sessionGeneration) {
        _applications = [];
        _loans = [];
        _products = [];
        _calculateKpis(0);
      }
    } finally {
      if (sessionGeneration == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchCustomerLoans(int actorUserId) async {
    final sessionGeneration = _sessionGeneration;
    _applications = [];
    _loans = [];
    _products = [];
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      final snapshot = await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['role', 'customer_id', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty ||
            actors.first['auth_status'] != 'active' ||
            actors.first['role'] != 'customer' ||
            actors.first['customer_id'] == null) {
          return null;
        }
        final customerId = actors.first['customer_id'] as int;
        final loanRows = await txn.rawQuery(
          '''
          SELECT l.*, c.name as customer_name, c.phone as customer_phone,
                 p.name as product_name,
                 (SELECT COUNT(*) FROM schedule WHERE loan_id = l.id AND paid = 1) as paid_count,
                 (SELECT COUNT(*) FROM schedule WHERE loan_id = l.id) as total_count,
                 (SELECT IFNULL(SUM(COALESCE(amount_paise, CAST(ROUND(amount * 100) AS INTEGER))), 0) FROM payments WHERE loan_id = l.id) as paid_total_paise,
                 (SELECT IFNULL(SUM(COALESCE(principal_paise, CAST(ROUND(principal * 100) AS INTEGER))), 0) FROM schedule WHERE loan_id = l.id AND paid = 0) as outstanding_paise,
                 (SELECT due_date FROM schedule WHERE loan_id = l.id AND paid = 0 ORDER BY no ASC LIMIT 1) as next_due_date,
                 (SELECT COALESCE(emi_paise, CAST(ROUND(emi * 100) AS INTEGER)) FROM schedule WHERE loan_id = l.id AND paid = 0 ORDER BY no ASC LIMIT 1) as next_due_amount_paise,
                 (SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END FROM schedule WHERE loan_id = l.id AND paid = 0 AND due_date < date('now')) as has_overdue
          FROM loans l
          LEFT JOIN customers c ON c.id = l.customer_id
          LEFT JOIN products p ON p.id = l.product_id
          WHERE l.customer_id = ?
          ORDER BY l.id DESC
          ''',
          [customerId],
        );
        final overdueRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(COALESCE(
            s.emi_paise, CAST(ROUND(s.emi * 100) AS INTEGER)
          )), 0) AS overdue_paise
          FROM schedule s
          JOIN loans l ON l.id = s.loan_id
          WHERE s.paid = 0 AND s.due_date < date('now')
            AND l.status = 'active' AND l.customer_id = ?
          ''',
          [customerId],
        );
        return (
          loans: loanRows,
          overduePaise:
              (overdueRows.first['overdue_paise'] as num?)?.toInt() ?? 0,
        );
      });
      if (sessionGeneration != _sessionGeneration) return;
      if (snapshot == null) {
        _loans = [];
        _applications = [];
        _products = [];
        _calculateKpis(0);
        return;
      }
      _loans = snapshot.loans.map((row) => LoanModel.fromMap(row)).toList();
      _applications = [];
      _products = [];
      _calculateKpis(snapshot.overduePaise);
    } catch (_) {
      debugPrint('Unable to load customer loan records.');
      if (sessionGeneration == _sessionGeneration) {
        _loans = [];
        _applications = [];
        _products = [];
        _calculateKpis(0);
      }
    } finally {
      if (sessionGeneration == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _calculateKpis(int dbOverduePaise) {
    var disbursedPaise = 0;
    var outstandingPaise = 0;
    int activeCount = 0;
    int overdueCount = 0;
    final branchMapPaise = <String, int>{};

    for (var l in _loans) {
      disbursedPaise += l.principalPaise;
      branchMapPaise[l.branch] =
          (branchMapPaise[l.branch] ?? 0) + l.principalPaise;

      if (l.status == 'active') {
        activeCount++;
        outstandingPaise += l.outstandingPaise;
        if (l.hasOverdue) {
          overdueCount++;
        }
      }
    }

    _totalDisbursed = CurrencyAmount.fromMinorUnits(disbursedPaise);
    _totalOutstanding = CurrencyAmount.fromMinorUnits(outstandingPaise);
    _totalOverdue = CurrencyAmount.fromMinorUnits(dbOverduePaise);
    _activeLoansCount = activeCount;
    _overdueLoansCount = overdueCount;
    _branchPortfolio = branchMapPaise.map(
      (branch, amount) =>
          MapEntry(branch, CurrencyAmount.fromMinorUnits(amount)),
    );

    if (disbursedPaise > 0) {
      final totalPaidPaise = _loans.fold<int>(
        0,
        (sum, l) => sum + l.paidTotalPaise,
      );
      _recoveryRate = (totalPaidPaise + dbOverduePaise) > 0
          ? double.parse(
              ((totalPaidPaise / (totalPaidPaise + dbOverduePaise)) * 100)
                  .toStringAsFixed(1),
            )
          : 100.0;
    } else {
      _recoveryRate = 0.0;
    }
  }

  Future<List<ScheduleItemModel>> getSchedule(
    int loanId, {
    required int actorUserId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT s.*
      FROM schedule s
      JOIN loans l ON l.id = s.loan_id
      JOIN users u ON u.id = ?
      WHERE l.id = ? AND u.auth_status = 'active' AND (
        u.role = 'admin' OR
        (u.role IN ('manager', 'underwriter')
          AND trim(u.branch) <> '' AND l.branch = u.branch) OR
        (u.role = 'field_agent' AND l.agent_id = u.id
          AND trim(u.branch) <> '' AND l.branch = u.branch) OR
        (u.role = 'customer' AND u.customer_id IS NOT NULL
          AND l.customer_id = u.customer_id)
      )
      ORDER BY s.no ASC
      ''',
      [actorUserId, loanId],
    );
    return rows.map((r) => ScheduleItemModel.fromMap(r)).toList();
  }

  Future<List<PaymentModel>> getPayments(
    int loanId, {
    required int actorUserId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT p.*
      FROM payments p
      JOIN loans l ON l.id = p.loan_id
      JOIN users u ON u.id = ?
      WHERE l.id = ? AND u.auth_status = 'active' AND (
        u.role = 'admin' OR
        (u.role IN ('manager', 'underwriter')
          AND trim(u.branch) <> '' AND l.branch = u.branch) OR
        (u.role = 'field_agent' AND l.agent_id = u.id
          AND trim(u.branch) <> '' AND l.branch = u.branch) OR
        (u.role = 'customer' AND u.customer_id IS NOT NULL
          AND l.customer_id = u.customer_id)
      )
      ORDER BY p.id DESC
      ''',
      [actorUserId, loanId],
    );
    return rows.map((r) => PaymentModel.fromMap(r)).toList();
  }

  /// Rechecks the actor and loan scope, then audits a payment-record export.
  /// The returned data is read from the same transaction as the audit event.
  Future<Map<String, Object?>?> getPaymentRecordForExport(
    int paymentId, {
    required int actorUserId,
  }) async {
    if (paymentId <= 0 || actorUserId <= 0) return null;
    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) async {
      final actors = await txn.query(
        'users',
        columns: ['name', 'role', 'branch', 'customer_id', 'auth_status'],
        where: 'id = ?',
        whereArgs: [actorUserId],
        limit: 1,
      );
      if (actors.isEmpty || actors.first['auth_status'] != 'active') {
        return null;
      }

      final actor = actors.first;
      final role = actor['role'] as String? ?? '';
      final branch = (actor['branch'] as String? ?? '').trim();
      final actorCustId = actor['customer_id'] as int?;
      if (!{'admin', 'manager', 'underwriter', 'field_agent', 'customer'}.contains(role) ||
          (!{'admin', 'customer'}.contains(role) && branch.isEmpty)) {
        return null;
      }

      final rows = await txn.rawQuery(
        '''
        SELECT pay.id AS payment_id, pay.loan_id, pay.schedule_id,
               pay.amount, pay.amount_paise, pay.channel, pay.ref, pay.at,
               s.no AS installment_no, c.name AS customer_name,
               l.branch, COALESCE(a.product_name_snapshot, pr.name) AS product_name
        FROM payments pay
        JOIN loans l ON l.id = pay.loan_id
        LEFT JOIN schedule s ON s.id = pay.schedule_id AND s.loan_id = l.id
        LEFT JOIN customers c ON c.id = l.customer_id
        LEFT JOIN products pr ON pr.id = l.product_id
        LEFT JOIN applications a ON a.id = l.application_id
        WHERE pay.id = ? AND (
          ? = 'admin' OR
          (? IN ('manager', 'underwriter') AND l.branch = ?) OR
          (? = 'field_agent' AND l.agent_id = ? AND l.branch = ?) OR
          (? = 'customer' AND ? IS NOT NULL AND l.customer_id = ?)
        )
        LIMIT 1
        ''',
        [paymentId, role, role, branch, role, actorUserId, branch, role, actorCustId, actorCustId],
      );
      if (rows.isEmpty) return null;

      final payment = rows.first;
      await txn.insert('audit_log', {
        'operation_id': const Uuid().v4(),
        'entity_type': 'payment',
        'entity_id': paymentId,
        'action': 'payment_record_exported',
        'actor_user_id': actorUserId,
        'actor_role': role,
        'actor_name': actor['name'],
        'occurred_at': DateTime.now().toIso8601String().substring(0, 19),
        'details': jsonEncode({'reference': payment['ref']}),
      });
      return payment;
    });
  }

  Future<List<Map<String, Object?>>> getFieldTasks({
    required int actorUserId,
  }) async {
    if (actorUserId <= 0) return [];
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty || actors.first['auth_status'] != 'active') {
          return [];
        }
        final role = actors.first['role'] as String? ?? '';
        if (!{'admin', 'manager', 'field_agent'}.contains(role)) return [];
        final branch = (actors.first['branch'] as String? ?? '').trim();
        if (role != 'admin' && branch.isEmpty) return [];
        final scope = role == 'admin'
            ? ''
            : role == 'field_agent'
            ? 'WHERE t.officer_id = ? AND c.branch = ?'
            : 'WHERE c.branch = ?';
        final args = role == 'admin'
            ? <Object?>[]
            : role == 'field_agent'
            ? <Object?>[actorUserId, branch]
            : <Object?>[branch];
        return txn.rawQuery('''
          SELECT t.*, c.name AS customer_name, c.phone AS customer_phone,
                 c.branch AS customer_branch
          FROM tasks t
          LEFT JOIN customers c ON c.id = t.customer_id
          $scope
          ORDER BY t.status ASC, t.id ASC
          ''', args);
      });
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, Object?>>> getCollectionCandidates({
    required int taskId,
    required int actorUserId,
  }) async {
    if (taskId <= 0 || actorUserId <= 0) return [];
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty || actors.first['auth_status'] != 'active') {
          return [];
        }
        final actor = actors.first;
        final role = actor['role'] as String? ?? '';
        if (!{'admin', 'manager', 'field_agent'}.contains(role)) return [];

        final tasks = await txn.query(
          'tasks',
          columns: ['customer_id', 'loan_id', 'officer_id', 'ttype', 'status'],
          where: 'id = ?',
          whereArgs: [taskId],
          limit: 1,
        );
        if (tasks.isEmpty ||
            (tasks.first['ttype'] as String? ?? '').toLowerCase() !=
                'collection' ||
            (tasks.first['status'] as String? ?? 'open').toLowerCase() ==
                'done' ||
            tasks.first['customer_id'] == null ||
            (role == 'field_agent' &&
                tasks.first['officer_id'] != actorUserId)) {
          return [];
        }
        final task = tasks.first;
        final customers = await txn.query(
          'customers',
          columns: ['branch'],
          where: 'id = ?',
          whereArgs: [task['customer_id']],
          limit: 1,
        );
        if (customers.isEmpty) return [];
        final customerBranch = (customers.first['branch'] as String? ?? '')
            .trim();
        final actorBranch = (actor['branch'] as String? ?? '').trim();
        if (role != 'admin' &&
            (actorBranch.isEmpty || actorBranch != customerBranch)) {
          return [];
        }

        final scopeSql = role == 'admin'
            ? ''
            : role == 'field_agent'
            ? 'AND l.agent_id = ? AND l.branch = ?'
            : 'AND l.branch = ?';
        final scopeArgs = role == 'admin'
            ? <Object?>[]
            : role == 'field_agent'
            ? <Object?>[actorUserId, actorBranch]
            : <Object?>[actorBranch];
        final linkedLoanId = task['loan_id'] as int?;
        final linkedSql = linkedLoanId == null ? '' : 'AND l.id = ?';
        final linkedArgs = linkedLoanId == null
            ? <Object?>[]
            : <Object?>[linkedLoanId];
        final today = DateTime.now().toIso8601String().substring(0, 10);
        return txn.rawQuery(
          '''
          SELECT l.id, l.product_id, p.name AS product_name,
                 l.principal, l.principal_paise,
                 (SELECT s.id FROM schedule s
                  WHERE s.loan_id = l.id AND s.paid = 0 AND s.due_date <= ?
                  ORDER BY s.no ASC LIMIT 1) AS next_schedule_id,
                 (SELECT s.due_date FROM schedule s
                  WHERE s.loan_id = l.id AND s.paid = 0 AND s.due_date <= ?
                  ORDER BY s.no ASC LIMIT 1) AS next_due_date,
                 (SELECT s.emi FROM schedule s
                  WHERE s.loan_id = l.id AND s.paid = 0 AND s.due_date <= ?
                  ORDER BY s.no ASC LIMIT 1) AS next_due_amount,
                 (SELECT s.emi_paise FROM schedule s
                  WHERE s.loan_id = l.id AND s.paid = 0 AND s.due_date <= ?
                  ORDER BY s.no ASC LIMIT 1) AS next_due_amount_paise
          FROM loans l
          LEFT JOIN products p ON p.id = l.product_id
          WHERE l.customer_id = ? AND l.status = 'active'
            AND EXISTS (
              SELECT 1 FROM schedule due
              WHERE due.loan_id = l.id AND due.paid = 0 AND due.due_date <= ?
            )
            $scopeSql $linkedSql
          ORDER BY l.id DESC
          ''',
          [
            today,
            today,
            today,
            today,
            task['customer_id'],
            today,
            ...scopeArgs,
            ...linkedArgs,
          ],
        );
      });
    } catch (_) {
      return [];
    }
  }

  Future<bool> completeFieldTask({
    required int taskId,
    required int actorUserId,
    required double collectedAmount,
    required String notes,
    int? collectionLoanId,
    int? collectionScheduleId,
  }) async {
    if (actorUserId <= 0 ||
        !collectedAmount.isFinite ||
        collectedAmount < 0 ||
        !CurrencyAmount.hasPaisePrecision(collectedAmount) ||
        notes.trim().length < 4) {
      return false;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final today = nowIso.substring(0, 10);
      final operationId = const Uuid().v4();
      final paymentRef = 'FIELD-${operationId.substring(0, 8).toUpperCase()}';

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
          throw StateError('This account cannot complete field tasks.');
        }
        final role = actors.first['role'] as String;

        final taskRows = await txn.query(
          'tasks',
          where: "id = ? AND lower(COALESCE(status, 'open')) != 'done'",
          whereArgs: [taskId],
          limit: 1,
        );
        if (taskRows.isEmpty) throw StateError('Task is missing or complete.');
        final task = taskRows.first;
        if (role == 'field_agent' && task['officer_id'] != actorUserId) {
          throw StateError('Task is assigned to another field officer.');
        }
        final taskCustomers = task['customer_id'] == null
            ? <Map<String, Object?>>[]
            : await txn.query(
                'customers',
                columns: ['branch'],
                where: 'id = ?',
                whereArgs: [task['customer_id']],
                limit: 1,
              );
        final taskBranch = taskCustomers.isEmpty
            ? ''
            : (taskCustomers.first['branch'] as String? ?? '').trim();
        final actorBranch = (actors.first['branch'] as String? ?? '').trim();
        if (role != 'admin' &&
            (taskBranch.isEmpty || actorBranch != taskBranch)) {
          throw StateError('Task is outside this account branch.');
        }

        final isCollection =
            (task['ttype'] as String? ?? '').toLowerCase() == 'collection';
        int? loanId = task['loan_id'] as int?;
        if (collectionLoanId != null &&
            (!isCollection || (loanId != null && loanId != collectionLoanId))) {
          throw StateError('Selected loan does not match the task.');
        }
        if (collectionScheduleId != null && !isCollection) {
          throw StateError('A schedule can only be selected for collections.');
        }
        if (loanId == null && isCollection && collectedAmount > 0) {
          if (collectionLoanId != null) {
            loanId = collectionLoanId;
          } else if (task['customer_id'] != null) {
            final loans = await txn.query(
              'loans',
              columns: ['id'],
              where: "customer_id = ? AND status = 'active'",
              whereArgs: [task['customer_id']],
              orderBy: 'id DESC',
              limit: 2,
            );
            if (loans.length == 1) loanId = loans.first['id'] as int?;
            if (loans.length > 1) {
              throw StateError(
                'Select the loan that this collection belongs to.',
              );
            }
          }
        }

        if (collectedAmount > 0) {
          if (!isCollection || loanId == null) {
            throw StateError(
              'A linked active loan is required to record cash.',
            );
          }
          if (collectionScheduleId == null) {
            throw StateError('Select the due installment before collection.');
          }
          final loans = await txn.query(
            'loans',
            columns: ['status', 'branch', 'agent_id', 'customer_id'],
            where: "id = ? AND status = 'active'",
            whereArgs: [loanId],
            limit: 1,
          );
          if (loans.isEmpty ||
              loans.first['customer_id'] != task['customer_id']) {
            throw StateError('Loan is not active for this customer.');
          }
          final loanBranch = (loans.first['branch'] as String? ?? '').trim();
          if ((role == 'field_agent' &&
                  (loans.first['agent_id'] != actorUserId ||
                      actorBranch.isEmpty ||
                      actorBranch != loanBranch)) ||
              (role == 'manager' && actorBranch != loanBranch)) {
            throw StateError('Loan is outside this account scope.');
          }
          final dueRows = await txn.query(
            'schedule',
            columns: ['id', 'emi', 'emi_paise'],
            where: 'id = ? AND loan_id = ? AND paid = 0 AND due_date <= ?',
            whereArgs: [collectionScheduleId, loanId, today],
            limit: 1,
          );
          if (dueRows.isEmpty) {
            throw StateError(
              'There is no due installment available to collect.',
            );
          }
          final collectedMinor = CurrencyAmount.toMinorUnits(collectedAmount);
          final dueMinor = CurrencyAmount.readStoredMinorUnits(
            dueRows.first,
            'emi_paise',
            'emi',
          );
          if (collectedMinor != dueMinor) {
            throw StateError(
              'Cash collected must equal the full due installment.',
            );
          }
          final scheduleId = dueRows.first['id'] as int;
          final changed = await txn.update(
            'schedule',
            {'paid': 1, 'paid_on': today},
            where: 'id = ? AND loan_id = ? AND paid = 0 AND due_date <= ?',
            whereArgs: [scheduleId, loanId, today],
          );
          if (changed != 1) {
            throw StateError('Installment was already processed.');
          }
          await txn.insert('payments', {
            'loan_id': loanId,
            'schedule_id': scheduleId,
            'amount': CurrencyAmount.fromMinorUnits(dueMinor),
            'amount_paise': dueMinor,
            'channel': 'field_cash',
            'ref': paymentRef,
            'at': nowIso,
            'operation_id': operationId,
          });
          await txn.insert('audit_log', {
            'operation_id': operationId,
            'entity_type': 'loan',
            'entity_id': loanId,
            'action': 'field_installment_collected',
            'actor_user_id': actorUserId,
            'actor_role': role,
            'actor_name': actors.first['name'],
            'occurred_at': nowIso,
            'details': jsonEncode({
              'task_id': taskId,
              'schedule_id': scheduleId,
              'amount_paise': dueMinor,
              'reference': paymentRef,
            }),
          });
          final unpaid = await txn.rawQuery(
            'SELECT COUNT(*) AS c FROM schedule WHERE loan_id = ? AND paid = 0',
            [loanId],
          );
          if ((unpaid.first['c'] as int? ?? 0) == 0) {
            await txn.update(
              'loans',
              {'status': 'closed', 'closure_date': today},
              where: "id = ? AND status = 'active'",
              whereArgs: [loanId],
            );
          }
        }

        final taskOperationId = const Uuid().v4();
        final taskChanged = await txn.update(
          'tasks',
          {
            'status': 'done',
            'collected': collectedAmount,
            'collected_paise': CurrencyAmount.toMinorUnits(collectedAmount),
            'notes': notes.trim(),
            'done_at': nowIso,
            if (loanId != null) 'loan_id': loanId,
          },
          where: "id = ? AND lower(COALESCE(status, 'open')) != 'done'",
          whereArgs: [taskId],
        );
        if (taskChanged != 1) throw StateError('Task was already completed.');

        final syncAction = collectedAmount > 0
            ? 'field_collection'
            : 'field_task_completed';
        await txn.insert('sync_log', {
          'uuid': operationId,
          'user_id': actorUserId,
          'payload': jsonEncode({
            'action': syncAction,
            'data': {
              'task_id': taskId,
              if (loanId != null) 'loan_id': loanId,
              'amount_paise': CurrencyAmount.toMinorUnits(collectedAmount),
              'notes': notes.trim(),
            },
          }),
          'captured_at': nowIso,
          'synced_at': null,
        });
        await txn.insert('audit_log', {
          'operation_id': taskOperationId,
          'entity_type': 'field_task',
          'entity_id': taskId,
          'action': 'task_completed',
          'actor_user_id': actorUserId,
          'actor_role': role,
          'actor_name': actors.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'collected_paise': CurrencyAmount.toMinorUnits(collectedAmount),
            if (loanId != null) 'loan_id': loanId,
          }),
        });
      });

      await fetchAll(actorUserId: actorUserId);
      return true;
    } catch (_) {
      debugPrint('Field collection task could not be completed.');
      return false;
    }
  }

  Future<List<ApprovalLogModel>> getApprovalTimeline(
    int applicationId, {
    required int actorUserId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.*
      FROM approvals a
      JOIN applications app ON app.id = a.application_id
      JOIN users u ON u.id = ?
      WHERE app.id = ? AND u.auth_status = 'active' AND (
        u.role = 'admin' OR
        (u.role IN ('manager', 'underwriter')
          AND trim(u.branch) <> '' AND app.branch = u.branch) OR
        (u.role = 'field_agent' AND app.agent_id = u.id
          AND trim(u.branch) <> '' AND app.branch = u.branch)
      )
      ORDER BY a.id ASC
      ''',
      [actorUserId, applicationId],
    );
    return rows.map((r) => ApprovalLogModel.fromMap(r)).toList();
  }

  Future<bool> payInstallment({
    required int loanId,
    required int scheduleId,
    required double amount,
    required String channel,
    required int actorUserId,
  }) async {
    if (!amount.isFinite ||
        amount <= 0 ||
        !CurrencyAmount.hasPaisePrecision(amount) ||
        actorUserId <= 0) {
      return false;
    }
    const allowedChannels = {'cash', 'upi', 'neft', 'enach', 'card', 'autopay'};
    if (!allowedChannels.contains(channel.toLowerCase())) {
      return false;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final todayStr = now.toIso8601String().substring(0, 10);
      final operationId = const Uuid().v4();
      final ref = 'PAY-${operationId.substring(0, 8).toUpperCase()}';

      String actorRole = '';
      await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch', 'customer_id'],
          where: "id = ? AND auth_status = 'active'",
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty ||
            !{
              'admin',
              'manager',
              'field_agent',
              'customer',
            }.contains(actors.first['role'])) {
          throw StateError('This account cannot record loan payments.');
        }
        final loans = await txn.query(
          'loans',
          columns: ['status', 'branch', 'agent_id', 'customer_id'],
          where: 'id = ?',
          whereArgs: [loanId],
          limit: 1,
        );
        if (loans.isEmpty || loans.first['status'] != 'active') {
          throw StateError('Loan is not active.');
        }
        actorRole = actors.first['role'] as String;
        final loanBranch = (loans.first['branch'] as String? ?? '').trim();
        if (actorRole == 'customer') {
          final actorCustId = actors.first['customer_id'] as int?;
          final loanCustId = loans.first['customer_id'] as int?;
          if (actorCustId == null || loanCustId != actorCustId) {
            throw StateError('Loan is outside this borrower account.');
          }
          if (channel.toLowerCase() == 'cash') {
            throw StateError('Borrowers must use a digital payment channel.');
          }
        } else if ((actorRole == 'field_agent' &&
                (loans.first['agent_id'] != actorUserId ||
                    (actors.first['branch'] as String? ?? '').trim().isEmpty ||
                    (actors.first['branch'] as String? ?? '').trim() !=
                        loanBranch)) ||
            (actorRole == 'manager' &&
                ((actors.first['branch'] as String? ?? '').trim().isEmpty ||
                    (actors.first['branch'] as String? ?? '').trim() !=
                        loanBranch))) {
          throw StateError('Loan is outside this account scope.');
        }
        final scheduleRows = await txn.query(
          'schedule',
          columns: ['emi', 'emi_paise', 'paid'],
          where: 'id = ? AND loan_id = ?',
          whereArgs: [scheduleId, loanId],
          limit: 1,
        );
        if (scheduleRows.isEmpty ||
            (scheduleRows.first['paid'] as int? ?? 1) != 0) {
          throw StateError('Installment is missing or already paid.');
        }
        final amountMinor = CurrencyAmount.toMinorUnits(amount);
        final dueMinor = CurrencyAmount.readStoredMinorUnits(
          scheduleRows.first,
          'emi_paise',
          'emi',
        );
        if (amountMinor != dueMinor) {
          throw StateError('Payment must equal the full installment amount.');
        }

        final changed = await txn.update(
          'schedule',
          {'paid': 1, 'paid_on': todayStr},
          where: 'id = ? AND loan_id = ? AND paid = 0',
          whereArgs: [scheduleId, loanId],
        );
        if (changed != 1) {
          throw StateError('Installment was already processed.');
        }

        await txn.insert('payments', {
          'loan_id': loanId,
          'schedule_id': scheduleId,
          'amount': CurrencyAmount.fromMinorUnits(dueMinor),
          'amount_paise': dueMinor,
          'channel': channel,
          'ref': ref,
          'at': nowIso,
          'operation_id': operationId,
        });
        await txn.insert('sync_log', {
          'uuid': operationId,
          'user_id': actorUserId,
          'payload': jsonEncode({
            'action': 'installment_payment',
            'data': {
              'loan_id': loanId,
              'schedule_id': scheduleId,
              'amount_paise': dueMinor,
              'channel': channel,
              'reference': ref,
              'captured_at': nowIso,
            },
          }),
          'captured_at': nowIso,
          'synced_at': null,
        });
        await txn.insert('audit_log', {
          'operation_id': operationId,
          'entity_type': 'loan',
          'entity_id': loanId,
          'action': 'installment_paid',
          'actor_user_id': actorUserId,
          'actor_role': actors.first['role'],
          'actor_name': actors.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'schedule_id': scheduleId,
            'amount_paise': dueMinor,
            'channel': channel,
            'reference': ref,
          }),
        });

        final unpaid = await txn.rawQuery(
          'SELECT COUNT(*) AS c FROM schedule WHERE loan_id = ? AND paid = 0',
          [loanId],
        );
        if ((unpaid.first['c'] as int? ?? 0) == 0) {
          await txn.update(
            'loans',
            {'status': 'closed', 'closure_date': todayStr},
            where: "id = ? AND status = 'active'",
            whereArgs: [loanId],
          );
        }
      });

      await SyncService().updatePendingCount();
      SyncService().triggerFullSync(userId: actorUserId);

      if (actorRole == 'customer') {
        await fetchCustomerLoans(actorUserId);
      } else {
        await fetchAll(actorUserId: actorUserId);
      }
      return true;
    } catch (_) {
      debugPrint('Installment payment could not be recorded.');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSettlementQuote(
    int loanId, {
    required int actorUserId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final unpaid = await db.rawQuery(
      '''
      SELECT s.principal, s.principal_paise, s.interest, s.interest_paise
      FROM schedule s
      JOIN loans l ON l.id = s.loan_id
      JOIN users u ON u.id = ?
      WHERE l.id = ? AND s.paid = 0 AND u.auth_status = 'active' AND (
        u.role = 'admin' OR
        (u.role IN ('manager', 'underwriter')
          AND trim(u.branch) <> '' AND l.branch = u.branch) OR
        (u.role = 'field_agent' AND l.agent_id = u.id
          AND trim(u.branch) <> '' AND l.branch = u.branch)
      )
      ORDER BY s.no ASC
      ''',
      [actorUserId, loanId],
    );
    if (unpaid.isEmpty) return null;

    final principalRemainingMinor = unpaid.fold<int>(
      0,
      (sum, row) =>
          sum +
          CurrencyAmount.readStoredMinorUnits(
            row,
            'principal_paise',
            'principal',
          ),
    );
    // Settlement rule: outstanding principal + interest of next installment
    final nextInterestMinor = CurrencyAmount.readStoredMinorUnits(
      unpaid.first,
      'interest_paise',
      'interest',
    );
    final principalRemaining = CurrencyAmount.fromMinorUnits(
      principalRemainingMinor,
    );
    final nextInterest = CurrencyAmount.fromMinorUnits(nextInterestMinor);
    final totalSettlementMinor = principalRemainingMinor + nextInterestMinor;
    final totalSettlement = CurrencyAmount.fromMinorUnits(totalSettlementMinor);

    return {
      'principal_outstanding': principalRemaining,
      'next_interest': nextInterest,
      'total_settlement': totalSettlement,
      'installments_left': unpaid.length,
    };
  }

  Future<bool> settleLoanFull(
    int loanId,
    String channel, {
    required int actorUserId,
  }) async {
    // The current payoff formula is a prototype rule and no payment provider
    // confirms receipt. Keep settlement simulation out of release builds.
    if (!kDebugMode) return false;
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final todayStr = now.toIso8601String().substring(0, 10);
      final operationId = const Uuid().v4();
      final ref = 'SET-${operationId.substring(0, 8).toUpperCase()}';

      await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty ||
            actors.first['auth_status'] != 'active' ||
            !{'admin', 'manager'}.contains(actors.first['role'])) {
          throw StateError('This account cannot record a loan settlement.');
        }
        final loanRows = await txn.query(
          'loans',
          columns: ['status', 'branch'],
          where: "id = ? AND status = 'active'",
          whereArgs: [loanId],
          limit: 1,
        );
        if (loanRows.isEmpty) throw StateError('Loan is not active.');
        if (actors.first['role'] == 'manager' &&
            ((actors.first['branch'] as String? ?? '').trim().isEmpty ||
                actors.first['branch'] != loanRows.first['branch'])) {
          throw StateError('Loan is outside this account branch.');
        }
        final unpaid = await txn.query(
          'schedule',
          columns: [
            'principal',
            'principal_paise',
            'interest',
            'interest_paise',
          ],
          where: 'loan_id = ? AND paid = 0',
          whereArgs: [loanId],
          orderBy: 'no ASC',
        );
        if (unpaid.isEmpty) throw StateError('No unpaid installments remain.');
        final principalMinor = unpaid.fold<int>(
          0,
          (sum, row) =>
              sum +
              CurrencyAmount.readStoredMinorUnits(
                row,
                'principal_paise',
                'principal',
              ),
        );
        final interestMinor = CurrencyAmount.readStoredMinorUnits(
          unpaid.first,
          'interest_paise',
          'interest',
        );
        final amountMinor = principalMinor + interestMinor;
        final amount = CurrencyAmount.fromMinorUnits(amountMinor);
        await txn.update(
          'schedule',
          {'paid': 1, 'paid_on': todayStr},
          where: 'loan_id = ? AND paid = 0',
          whereArgs: [loanId],
        );
        await txn.insert('payments', {
          'loan_id': loanId,
          'schedule_id': null,
          'amount': amount,
          'amount_paise': amountMinor,
          'channel': channel,
          'ref': ref,
          'at': nowIso,
          'operation_id': operationId,
        });
        await txn.insert('audit_log', {
          'operation_id': operationId,
          'entity_type': 'loan',
          'entity_id': loanId,
          'action': 'loan_settlement_simulated',
          'actor_user_id': actorUserId,
          'actor_role': actors.first['role'],
          'actor_name': actors.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({'amount': amount, 'channel': channel}),
        });
        await txn.update(
          'loans',
          {'status': 'closed', 'closure_date': todayStr},
          where: "id = ? AND status = 'active'",
          whereArgs: [loanId],
        );
      });

      await fetchAll(actorUserId: actorUserId);
      return true;
    } catch (_) {
      debugPrint('Loan settlement could not be recorded.');
      return false;
    }
  }

  Future<bool> advanceApplication({
    required int applicationId,
    required String targetStage,
    required int actorUserId,
    required double sanctionedAmount,
    required String remarks,
    String disbursementReference = '',
    String disbursementChannel = '',
  }) async {
    const priorStages = {
      'under_review': {'submitted'},
      'approved': {'under_review'},
      'rejected': {'under_review'},
      'sanctioned': {'approved'},
      'disbursed': {'sanctioned'},
    };
    if (!priorStages.containsKey(targetStage) ||
        actorUserId <= 0 ||
        !sanctionedAmount.isFinite ||
        sanctionedAmount <= 0 ||
        !CurrencyAmount.hasPaisePrecision(sanctionedAmount) ||
        remarks.trim().length < 10) {
      return false;
    }
    if (targetStage == 'disbursed' &&
        (disbursementReference.trim().length < 4 ||
            !RegExp(r'^[A-Za-z0-9._/-]{4,128}$')
                .hasMatch(disbursementReference.trim()) ||
            !{
              'bank_transfer',
              'imps',
              'neft',
              'cash',
            }.contains(disbursementChannel))) {
      return false;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final today = DateTime(now.year, now.month, now.day);
      final operationId = const Uuid().v4();

      await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch'],
          where: "id = ? AND auth_status = 'active'",
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty) throw StateError('Approver is not active.');
        final actor = actors.first;
        final role = actor['role'] as String? ?? '';
        final creditRoles = {'admin', 'manager', 'underwriter'};
        final payoutRoles = {'admin', 'manager'};
        if (({'under_review', 'approved', 'rejected'}.contains(targetStage) &&
                !creditRoles.contains(role)) ||
            ({'sanctioned', 'disbursed'}.contains(targetStage) &&
                !payoutRoles.contains(role))) {
          throw StateError(
            'This role cannot perform the requested transition.',
          );
        }

        final apps = await txn.query(
          'applications',
          where: 'id = ?',
          whereArgs: [applicationId],
          limit: 1,
        );
        if (apps.isEmpty) throw StateError('Application does not exist.');
        final app = apps.first;
        final currentStage = (app['status'] as String? ?? '').toLowerCase();
        if (!priorStages[targetStage]!.contains(currentStage)) {
          throw StateError(
            'Application cannot move from $currentStage to $targetStage.',
          );
        }
        if (app['agent_id'] == actorUserId) {
          throw StateError(
            'The submitting officer cannot approve this application.',
          );
        }
        final appBranch = (app['branch'] as String? ?? '').trim();
        if (role != 'admin' &&
            ((actor['branch'] as String? ?? '').trim().isEmpty ||
                (actor['branch'] as String? ?? '').trim() != appBranch)) {
          throw StateError('Application is outside this account branch.');
        }

        final products = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [app['product_id']],
          limit: 1,
        );
        if (products.isEmpty) throw StateError('Loan product is missing.');
        final product = products.first;
        final requestedMinor = CurrencyAmount.readStoredMinorUnits(
          app,
          'amount_paise',
          'amount',
        );
        final minimumMinor =
            (app['min_amt_paise_snapshot'] as num?)?.toInt() ??
            CurrencyAmount.readStoredMinorUnits(
              product,
              'min_amt_paise',
              'min_amt',
            );
        final maximumMinor =
            (app['max_amt_paise_snapshot'] as num?)?.toInt() ??
            CurrencyAmount.readStoredMinorUnits(
              product,
              'max_amt_paise',
              'max_amt',
            );
        final sanctionedMinor = CurrencyAmount.toMinorUnits(sanctionedAmount);
        final stageAmount =
            const {'under_review', 'rejected'}.contains(targetStage)
            ? CurrencyAmount.fromMinorUnits(requestedMinor)
            : CurrencyAmount.fromMinorUnits(sanctionedMinor);
        if (targetStage != 'under_review' &&
            targetStage != 'rejected' &&
            (sanctionedMinor < minimumMinor ||
                sanctionedMinor > maximumMinor ||
                sanctionedMinor > requestedMinor)) {
          throw StateError(
            'Sanction amount is outside the approved application and product limits.',
          );
        }
        if ((targetStage == 'sanctioned' || targetStage == 'disbursed') &&
            sanctionedMinor != requestedMinor) {
          throw StateError(
            'The sanctioned or disbursed amount must match the approved amount.',
          );
        }

        int? loanId;
        if (targetStage == 'disbursed') {
          final customers = await txn.query(
            'customers',
            columns: ['kyc_status'],
            where: 'id = ?',
            whereArgs: [app['customer_id']],
            limit: 1,
          );
          if (customers.isEmpty ||
              customers.first['kyc_status'] != 'verified') {
            throw StateError('Customer KYC is not approved.');
          }
          final existingLoans = await txn.query(
            'loans',
            columns: ['id'],
            where: 'application_id = ?',
            whereArgs: [applicationId],
            limit: 1,
          );
          if (existingLoans.isNotEmpty) {
            throw StateError('A loan already exists for this application.');
          }
          final tenure = app['tenure'] as int;
          final minTenure =
              (app['min_tenure_snapshot'] as num?)?.toInt() ??
              product['min_tenure'] as int? ??
              0;
          final maxTenure =
              (app['max_tenure_snapshot'] as num?)?.toInt() ??
              product['max_tenure'] as int? ??
              0;
          if (tenure < minTenure || tenure > maxTenure) {
            throw StateError(
              'Application tenure is outside current product limits.',
            );
          }
          final principalMinor = CurrencyAmount.toMinorUnits(sanctionedAmount);
          final principal = CurrencyAmount.fromMinorUnits(principalMinor);
          final rate = (app['rate'] as num).toDouble();
          final method =
              (app['method_snapshot'] as String? ??
                      product['method'] as String? ??
                      'reducing')
                  .toLowerCase();
          if (!rate.isFinite ||
              rate < 0 ||
              !{'flat', 'reducing'}.contains(method)) {
            throw StateError('Invalid product rate.');
          }
          late final int emiMinor;
          if (method == 'flat') {
            final monthlyInterestMinor = (principalMinor * rate / 1200).round();
            emiMinor = (principalMinor / tenure).round() + monthlyInterestMinor;
          } else {
            final monthlyRate = rate / 1200;
            final emi = rate == 0
                ? principalMinor / tenure
                : principalMinor *
                      monthlyRate *
                      pow(1 + monthlyRate, tenure) /
                      (pow(1 + monthlyRate, tenure) - 1);
            emiMinor = emi.round();
          }
          final emi = CurrencyAmount.fromMinorUnits(emiMinor);
          final todayText = today.toIso8601String().substring(0, 10);
          loanId = await txn.insert('loans', {
            'application_id': applicationId,
            'customer_id': app['customer_id'],
            'product_id': app['product_id'],
            'principal': principal,
            'principal_paise': principalMinor,
            'rate': rate,
            'tenure': tenure,
            'method': method,
            'emi': emi,
            'emi_paise': emiMinor,
            'start_date': todayText,
            'status': 'active',
            'branch': app['branch'],
            'agent_id': app['agent_id'],
            'disbursement_ref': disbursementReference.trim(),
            'disbursement_channel': disbursementChannel,
          });

          var balanceMinor = principalMinor;
          for (var number = 1; number <= tenure; number++) {
            final interestMinor = method == 'flat'
                ? (principalMinor * rate / 1200).round()
                : (balanceMinor * rate / 1200).round();
            var principalDueMinor = emiMinor - interestMinor;
            if (number == tenure) {
              principalDueMinor = balanceMinor;
            }
            if (principalDueMinor <= 0 || principalDueMinor > balanceMinor) {
              throw StateError(
                'Generated installment does not reduce the principal balance.',
              );
            }
            balanceMinor = max(0, balanceMinor - principalDueMinor);
            final interest = CurrencyAmount.fromMinorUnits(interestMinor);
            final principalDue = CurrencyAmount.fromMinorUnits(
              principalDueMinor,
            );
            final balance = CurrencyAmount.fromMinorUnits(balanceMinor);

            final month = DateTime(today.year, today.month + number, 1);
            final monthEnd = DateTime(month.year, month.month + 1, 0).day;
            var due = DateTime(
              month.year,
              month.month,
              min(today.day, monthEnd),
            );
            if (due.weekday == DateTime.saturday) {
              due = due.add(const Duration(days: 2));
            } else if (due.weekday == DateTime.sunday) {
              due = due.add(const Duration(days: 1));
            }
            final installmentAmount = CurrencyAmount.fromMinorUnits(
              number == tenure ? principalDueMinor + interestMinor : emiMinor,
            );
            await txn.insert('schedule', {
              'loan_id': loanId,
              'no': number,
              'due_date': due.toIso8601String().substring(0, 10),
              'emi': installmentAmount,
              'emi_paise': number == tenure
                  ? principalDueMinor + interestMinor
                  : emiMinor,
              'principal': principalDue,
              'principal_paise': principalDueMinor,
              'interest': interest,
              'interest_paise': interestMinor,
              'balance': balance,
              'balance_paise': balanceMinor,
              'paid': 0,
            });
          }
          final scheduleCheck = await txn.rawQuery(
            '''
            SELECT COUNT(*) AS installment_count,
                   COALESCE(SUM(COALESCE(
                     principal_paise, CAST(ROUND(principal * 100) AS INTEGER)
                   )), 0) AS principal_paise,
                   (SELECT COALESCE(
                     balance_paise, CAST(ROUND(balance * 100) AS INTEGER)
                   ) FROM schedule
                    WHERE loan_id = ? ORDER BY no DESC LIMIT 1) AS final_balance
            FROM schedule
            WHERE loan_id = ?
            ''',
            [loanId, loanId],
          );
          final generated = scheduleCheck.first;
          if ((generated['installment_count'] as int? ?? 0) != tenure ||
              (generated['principal_paise'] as int? ?? 0) != principalMinor ||
              (generated['final_balance'] as int? ?? -1) != 0) {
            throw StateError(
              'Generated installment schedule does not reconcile to the loan principal.',
            );
          }
          await txn.update(
            'customers',
            {'stage': 'active'},
            where: 'id = ?',
            whereArgs: [app['customer_id']],
          );
        }

        final labels = {
          'under_review': 'Under Review',
          'approved': 'Approved',
          'sanctioned': 'Sanctioned',
          'disbursed': 'Disbursed',
          'rejected': 'Rejected',
        };
        final changed = await txn.update(
          'applications',
          {
            'status': targetStage,
            if (!const {'under_review', 'rejected'}.contains(targetStage)) ...{
              'amount': stageAmount,
              'amount_paise': CurrencyAmount.toMinorUnits(stageAmount),
            },
            'remarks': remarks.trim(),
          },
          where: 'id = ? AND lower(status) = ?',
          whereArgs: [applicationId, currentStage],
        );
        if (changed != 1) throw StateError('Application was already updated.');
        await txn.insert('approvals', {
          'application_id': applicationId,
          'stage': labels[targetStage],
          'by_user': actor['name'],
          'by_role': role,
          'amount': stageAmount,
          'amount_paise': CurrencyAmount.toMinorUnits(stageAmount),
          'remarks': remarks.trim(),
          'at': nowIso,
        });
        await txn.insert('audit_log', {
          'operation_id': operationId,
          'entity_type': 'application',
          'entity_id': applicationId,
          'action': 'application_$targetStage',
          'actor_user_id': actorUserId,
          'actor_role': role,
          'actor_name': actor['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'prior_stage': currentStage,
            'next_stage': targetStage,
            'amount': stageAmount,
            'remarks': remarks.trim(),
            if (loanId != null) 'loan_id': loanId,
            if (targetStage == 'disbursed') ...{
              'disbursement_reference': disbursementReference.trim(),
              'disbursement_channel': disbursementChannel,
            },
          }),
        });
      });

      await fetchAll(actorUserId: actorUserId);
      return true;
    } catch (_) {
      debugPrint('Loan application status could not be updated.');
      return false;
    }
  }

  Future<int?> submitNewLoanApplication({
    required int customerId,
    required int productId,
    required double amount,
    required int tenure,
    required String purpose,
    required double income,
    required String occupation,
    required int agentId,
    required String branch,
    String employer = '',
    String coName = '',
    String coPhone = '',
    String coRelation = '',
    double coIncome = 0.0,
    double incAgri = 0,
    double incBusiness = 0,
    double incJob = 0,
    double incOther = 0,
    double expBasic = 0,
    double expEducation = 0,
    double expFestival = 0,
    double expHealth = 0,
    double expEmi = 0,
    double expOther = 0,
    List<String> docsDeposited = const [],
    String docsOther = '',
    String insuranceWanted = 'no',
    String insuranceFor = 'self',
    double groupRec = 0,
    double centerRec = 0,
    int loanCycle = 1,
    int declaration = 1,
  }) async {
    final amounts = [
      income,
      coIncome,
      incAgri,
      incBusiness,
      incJob,
      incOther,
      expBasic,
      expEducation,
      expFestival,
      expHealth,
      expEmi,
      expOther,
      groupRec,
      centerRec,
    ];
    if (customerId <= 0 ||
        productId <= 0 ||
        agentId <= 0 ||
        !amount.isFinite ||
        amount <= 0 ||
        !CurrencyAmount.hasPaisePrecision(amount) ||
        tenure <= 0 ||
        loanCycle <= 0 ||
        declaration != 1 ||
        docsDeposited.toSet().length < 2 ||
        purpose.trim().isEmpty ||
        occupation.trim().isEmpty ||
        branch.trim().isEmpty ||
        income <= 0 ||
        amounts.any(
          (value) =>
              !value.isFinite ||
              value < 0 ||
              !CurrencyAmount.hasPaisePrecision(value),
        ) ||
        !CurrencyAmount.hasPaisePrecision(income)) {
      return null;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final operationId = const Uuid().v4();
      final totalExpenseMinor =
          [expBasic, expEducation, expFestival, expHealth, expEmi, expOther]
              .map(CurrencyAmount.toMinorUnits)
              .fold<int>(0, (sum, value) => sum + value);
      final categoryIncomeMinor = [incAgri, incBusiness, incJob, incOther]
          .map(CurrencyAmount.toMinorUnits)
          .fold<int>(0, (sum, value) => sum + value);
      final totalIncomeMinor = categoryIncomeMinor > 0
          ? categoryIncomeMinor
          : CurrencyAmount.toMinorUnits(income);
      final netSavingMinor = totalIncomeMinor - totalExpenseMinor;
      final totalExp = CurrencyAmount.fromMinorUnits(totalExpenseMinor);
      final totalInc = CurrencyAmount.fromMinorUnits(totalIncomeMinor);
      final netSav = CurrencyAmount.fromMinorUnits(netSavingMinor);
      late int appId;
      await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch'],
          where: "id = ? AND auth_status = 'active'",
          whereArgs: [agentId],
          limit: 1,
        );
        if (actors.isEmpty ||
            !{
              'admin',
              'manager',
              'field_agent',
            }.contains(actors.first['role'])) {
          throw StateError('This account cannot submit loan applications.');
        }
        final role = actors.first['role'] as String;
        final customers = await txn.query(
          'customers',
          columns: ['kyc_status', 'branch', 'agent_id'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customers.isEmpty || customers.first['kyc_status'] != 'verified') {
          throw StateError('Customer KYC must be manually approved.');
        }
        final customer = customers.first;
        if (role == 'field_agent' && customer['agent_id'] != agentId) {
          throw StateError('Customer is outside this officer assignment.');
        }
        final customerBranch = (customer['branch'] as String? ?? '').trim();
        if (customerBranch.isEmpty || branch.trim() != customerBranch) {
          throw StateError('Application branch must match customer branch.');
        }
        if (role != 'admin' &&
            (actors.first['branch'] as String? ?? '').trim() !=
                customerBranch) {
          throw StateError('Customer is outside this account branch.');
        }

        final products = await txn.query(
          'products',
          where: 'id = ? AND active = 1',
          whereArgs: [productId],
          limit: 1,
        );
        if (products.isEmpty) throw StateError('Product is not active.');
        final product = products.first;
        final amountMinor = CurrencyAmount.toMinorUnits(amount);
        final minAmountMinor = CurrencyAmount.readStoredMinorUnits(
          product,
          'min_amt_paise',
          'min_amt',
        );
        final maxAmountMinor = CurrencyAmount.readStoredMinorUnits(
          product,
          'max_amt_paise',
          'max_amt',
        );
        final minTenure = product['min_tenure'] as int? ?? 0;
        final maxTenure = product['max_tenure'] as int? ?? 0;
        if (amountMinor < minAmountMinor ||
            amountMinor > maxAmountMinor ||
            tenure < minTenure ||
            tenure > maxTenure) {
          throw StateError('Loan terms are outside the active product limits.');
        }
        final pending = await txn.rawQuery(
          '''
          SELECT COUNT(*) AS count FROM applications
          WHERE customer_id = ?
            AND lower(status) IN ('submitted', 'under_review', 'approved', 'sanctioned')
        ''',
          [customerId],
        );
        if ((pending.first['count'] as int? ?? 0) > 0) {
          throw StateError('Customer already has an application in progress.');
        }

        final rate = (product['rate'] as num).toDouble();
        final method = (product['method'] as String? ?? 'reducing')
            .toLowerCase();
        if (!rate.isFinite ||
            rate < 0 ||
            !{'flat', 'reducing'}.contains(method)) {
          throw StateError(
            'Active product rate or calculation method is invalid.',
          );
        }
        final estimatedEmiMinor = method == 'flat'
            ? ((amountMinor + (amountMinor * rate / 100 * tenure / 12)) /
                      tenure)
                  .round()
            : rate == 0
            ? (amountMinor / tenure).round()
            : (amountMinor *
                      (rate / 1200) *
                      pow(1 + rate / 1200, tenure) /
                      (pow(1 + rate / 1200, tenure) - 1))
                  .round();
        if (estimatedEmiMinor * 100 > totalIncomeMinor * 60) {
          throw StateError(
            'Estimated EMI exceeds 60% of recorded monthly household income.',
          );
        }
        appId = await txn.insert('applications', {
          'customer_id': customerId,
          'product_id': productId,
          'amount': amount,
          'amount_paise': CurrencyAmount.toMinorUnits(amount),
          'tenure': tenure,
          'rate': rate,
          'product_name_snapshot': product['name'],
          'method_snapshot': method,
          'min_amt_paise_snapshot': minAmountMinor,
          'max_amt_paise_snapshot': maxAmountMinor,
          'min_tenure_snapshot': minTenure,
          'max_tenure_snapshot': maxTenure,
          'fee_pct_snapshot': product['fee_pct'],
          'purpose': purpose.trim(),
          'income': income,
          'income_paise': CurrencyAmount.toMinorUnits(income),
          'occupation': occupation.trim(),
          'employer': employer.trim(),
          'co_name': coName.trim(),
          'co_phone': coPhone.trim(),
          'co_relation': coRelation,
          'co_income': coIncome,
          'co_income_paise': CurrencyAmount.toMinorUnits(coIncome),
          'status': 'submitted',
          'agent_id': agentId,
          'branch': customerBranch,
          'created': nowIso,
          'remarks': '',
          'docs': docsDeposited.join(','),
        });

        await txn.insert('app_extra', {
          'application_id': appId,
          'prev_loans': '[]',
          'insurance_wanted': insuranceWanted,
          'insurance_for': insuranceFor,
          'docs_deposited': docsDeposited.join(','),
          'docs_other': docsOther.trim(),
          'inc_agri': incAgri,
          'inc_agri_paise': CurrencyAmount.toMinorUnits(incAgri),
          'inc_business': incBusiness,
          'inc_business_paise': CurrencyAmount.toMinorUnits(incBusiness),
          'inc_job': incJob,
          'inc_job_paise': CurrencyAmount.toMinorUnits(incJob),
          'inc_other': incOther,
          'inc_other_paise': CurrencyAmount.toMinorUnits(incOther),
          'exp_basic': expBasic,
          'exp_basic_paise': CurrencyAmount.toMinorUnits(expBasic),
          'exp_education': expEducation,
          'exp_education_paise': CurrencyAmount.toMinorUnits(expEducation),
          'exp_festival': expFestival,
          'exp_festival_paise': CurrencyAmount.toMinorUnits(expFestival),
          'exp_health': expHealth,
          'exp_health_paise': CurrencyAmount.toMinorUnits(expHealth),
          'exp_emi': expEmi,
          'exp_emi_paise': CurrencyAmount.toMinorUnits(expEmi),
          'exp_other': expOther,
          'exp_other_paise': CurrencyAmount.toMinorUnits(expOther),
          'group_rec': groupRec > 0 ? groupRec : null,
          'group_rec_paise': groupRec > 0
              ? CurrencyAmount.toMinorUnits(groupRec)
              : null,
          'center_rec': centerRec > 0 ? centerRec : null,
          'center_rec_paise': centerRec > 0
              ? CurrencyAmount.toMinorUnits(centerRec)
              : null,
          'loan_cycle': loanCycle,
          'requested_amt': amount,
          'requested_amt_paise': CurrencyAmount.toMinorUnits(amount),
          'income_total': totalInc,
          'income_total_paise': totalIncomeMinor,
          'expense_total': totalExp,
          'expense_total_paise': totalExpenseMinor,
          'net_saving': netSav,
          'net_saving_paise': netSavingMinor,
          'declaration': declaration,
        });

        await txn.insert('approvals', {
          'application_id': appId,
          'stage': 'Submitted',
          'by_user': actors.first['name'],
          'by_role': role,
          'amount': amount,
          'amount_paise': CurrencyAmount.toMinorUnits(amount),
          'remarks': 'Loan application submitted',
          'at': nowIso,
        });
        await txn.insert('audit_log', {
          'operation_id': operationId,
          'entity_type': 'application',
          'entity_id': appId,
          'action': 'application_submitted',
          'actor_user_id': agentId,
          'actor_role': role,
          'actor_name': actors.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'product_id': productId,
            'amount': amount,
            'amount_paise': CurrencyAmount.toMinorUnits(amount),
            'tenure': tenure,
            'branch': customerBranch,
          }),
        });
      });

      await fetchAll(actorUserId: agentId);
      return appId;
    } catch (_) {
      debugPrint('Loan application could not be created.');
      return null;
    }
  }
}
