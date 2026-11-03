import 'dart:math';
import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/application_model.dart';
import '../models/loan_model.dart';
import '../models/loan_product_model.dart';

class LoanProvider extends ChangeNotifier {
  List<ApplicationModel> _applications = [];
  List<LoanModel> _loans = [];
  List<LoanProductModel> _products = [];
  bool _isLoading = false;

  // KPI Metrics
  double _totalDisbursed = 0.0;
  double _totalOutstanding = 0.0;
  double _totalOverdue = 0.0;
  int _activeLoansCount = 0;
  int _overdueLoansCount = 0;
  double _recoveryRate = 96.5;
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

  Future<void> fetchAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch Products
      final prodRows = await db.query('products', where: 'active = 1');
      _products = prodRows.map((r) => LoanProductModel.fromMap(r)).toList();

      // 2. Fetch Applications with Joined Customers & Products
      final appRows = await db.rawQuery('''
        SELECT a.*, c.name as customer_name, c.phone as customer_phone, p.name as product_name,
               ae.income_total, ae.expense_total, ae.net_saving
        FROM applications a
        LEFT JOIN customers c ON a.customer_id = c.id
        LEFT JOIN products p ON a.product_id = p.id
        LEFT JOIN app_extra ae ON a.id = ae.application_id
        ORDER BY a.id DESC
      ''');
      _applications = appRows.map((r) => ApplicationModel.fromMap(r)).toList();

      // 3. Fetch Loans with aggregates
      final loanRows = await db.rawQuery('''
        SELECT l.*, c.name as customer_name, c.phone as customer_phone, p.name as product_name,
               (SELECT COUNT(*) FROM schedule WHERE loan_id = l.id AND paid = 1) as paid_count,
               (SELECT COUNT(*) FROM schedule WHERE loan_id = l.id) as total_count,
               (SELECT IFNULL(SUM(amount), 0) FROM payments WHERE loan_id = l.id) as paid_total,
               (SELECT IFNULL(SUM(principal), 0) FROM schedule WHERE loan_id = l.id AND paid = 0) as outstanding,
               (SELECT due_date FROM schedule WHERE loan_id = l.id AND paid = 0 ORDER BY no ASC LIMIT 1) as next_due_date,
               (SELECT emi FROM schedule WHERE loan_id = l.id AND paid = 0 ORDER BY no ASC LIMIT 1) as next_due_amount,
               (SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END FROM schedule WHERE loan_id = l.id AND paid = 0 AND due_date < date('now')) as has_overdue
        FROM loans l
        LEFT JOIN customers c ON l.customer_id = c.id
        LEFT JOIN products p ON l.product_id = p.id
        ORDER BY l.id DESC
      ''');
      _loans = loanRows.map((r) => LoanModel.fromMap(r)).toList();

      // 4. Fetch actual overdue amount from schedule
      final overdueResult = await db.rawQuery('''
        SELECT IFNULL(SUM(s.emi), 0) as overdue_sum
        FROM schedule s
        JOIN loans l ON s.loan_id = l.id
        WHERE s.paid = 0 AND s.due_date < date('now') AND l.status = 'active'
      ''');
      final dbOverdue = (overdueResult.first['overdue_sum'] as num?)?.toDouble() ?? 0.0;

      // 5. Calculate KPIs
      _calculateKpis(dbOverdue);
    } catch (e) {
      debugPrint('Error fetching loan data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateKpis(double dbOverdue) {
    double disbursed = 0.0;
    double outstanding = 0.0;
    int activeCount = 0;
    int overdueCount = 0;
    Map<String, double> branchMap = {};

    for (var l in _loans) {
      disbursed += l.principal;
      branchMap[l.branch] = (branchMap[l.branch] ?? 0.0) + l.principal;

      if (l.status == 'active') {
        activeCount++;
        outstanding += l.outstanding;
        if (l.hasOverdue) {
          overdueCount++;
        }
      }
    }

    _totalDisbursed = disbursed;
    _totalOutstanding = outstanding;
    _totalOverdue = dbOverdue;
    _activeLoansCount = activeCount;
    _overdueLoansCount = overdueCount;
    _branchPortfolio = branchMap;

    if (disbursed > 0) {
      final totalPaid = _loans.fold<double>(0.0, (sum, l) => sum + l.paidTotal);
      _recoveryRate = (totalPaid + _totalOverdue) > 0
          ? double.parse(((totalPaid / (totalPaid + _totalOverdue)) * 100).toStringAsFixed(1))
          : 100.0;
    }
  }

  Future<List<ScheduleItemModel>> getSchedule(int loanId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('schedule', where: 'loan_id = ?', whereArgs: [loanId], orderBy: 'no ASC');
    return rows.map((r) => ScheduleItemModel.fromMap(r)).toList();
  }

  Future<List<PaymentModel>> getPayments(int loanId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('payments', where: 'loan_id = ?', whereArgs: [loanId], orderBy: 'id DESC');
    return rows.map((r) => PaymentModel.fromMap(r)).toList();
  }

  Future<List<ApprovalLogModel>> getApprovalTimeline(int applicationId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('approvals', where: 'application_id = ?', whereArgs: [applicationId], orderBy: 'id ASC');
    return rows.map((r) => ApprovalLogModel.fromMap(r)).toList();
  }

  Future<bool> payInstallment({
    required int loanId,
    required int scheduleId,
    required double amount,
    required String channel,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final todayStr = now.toIso8601String().substring(0, 10);
      final ref = '${channel.toUpperCase()}${100000 + Random().nextInt(900000)}';

      // 1. Mark schedule as paid
      await db.update(
        'schedule',
        {'paid': 1, 'paid_on': todayStr},
        where: 'id = ? AND loan_id = ?',
        whereArgs: [scheduleId, loanId],
      );

      // 2. Insert payment record
      await db.insert('payments', {
        'loan_id': loanId,
        'schedule_id': scheduleId,
        'amount': amount,
        'channel': channel,
        'ref': ref,
        'at': nowIso,
      });

      // 3. Check if all paid to close loan
      final unpaid = await db.rawQuery('SELECT COUNT(*) as c FROM schedule WHERE loan_id = ? AND paid = 0', [loanId]);
      final unpaidCount = (unpaid.first['c'] as int?) ?? 0;
      if (unpaidCount == 0) {
        await db.update(
          'loans',
          {'status': 'closed', 'closure_date': todayStr},
          where: 'id = ?',
          whereArgs: [loanId],
        );
      }

      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('Error paying installment: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSettlementQuote(int loanId) async {
    final db = await DatabaseHelper.instance.database;
    final unpaid = await db.query('schedule', where: 'loan_id = ? AND paid = 0', whereArgs: [loanId], orderBy: 'no ASC');
    if (unpaid.isEmpty) return null;

    double principalRemaining = 0.0;
    for (var r in unpaid) {
      principalRemaining += (r['principal'] as num).toDouble();
    }
    // Settlement rule: outstanding principal + interest of next installment
    final nextInterest = (unpaid.first['interest'] as num).toDouble();
    final totalSettlement = double.parse((principalRemaining + nextInterest).toStringAsFixed(2));

    return {
      'principal_outstanding': double.parse(principalRemaining.toStringAsFixed(2)),
      'next_interest': nextInterest,
      'total_settlement': totalSettlement,
      'installments_left': unpaid.length,
    };
  }

  Future<bool> settleLoanFull(int loanId, String channel) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final quote = await getSettlementQuote(loanId);
      if (quote == null) return false;

      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final todayStr = now.toIso8601String().substring(0, 10);
      final ref = 'SETTLE${Random().nextInt(900000) + 100000}';

      // Mark all schedule items paid
      await db.update('schedule', {'paid': 1, 'paid_on': todayStr}, where: 'loan_id = ?', whereArgs: [loanId]);

      // Record settlement payment
      await db.insert('payments', {
        'loan_id': loanId,
        'schedule_id': 0,
        'amount': quote['total_settlement'],
        'channel': channel,
        'ref': ref,
        'at': nowIso,
      });

      // Close the loan
      await db.update('loans', {'status': 'closed', 'closure_date': todayStr}, where: 'id = ?', whereArgs: [loanId]);

      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('Error settling loan: $e');
      return false;
    }
  }

  Future<bool> advanceApplication({
    required int applicationId,
    required String targetStage,
    required String byUser,
    required String byRole,
    required double sanctionedAmount,
    required String remarks,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);
      final today = DateTime(now.year, now.month, now.day);

      // Update application status & amount if altered
      await db.update(
        'applications',
        {'status': targetStage, 'amount': sanctionedAmount, 'remarks': remarks},
        where: 'id = ?',
        whereArgs: [applicationId],
      );

      // Stage label
      String stageLabel;
      switch (targetStage) {
        case 'under_review':
          stageLabel = 'Under Review';
          break;
        case 'approved':
          stageLabel = 'Approved';
          break;
        case 'sanctioned':
          stageLabel = 'Sanctioned';
          break;
        case 'disbursed':
          stageLabel = 'Disbursed';
          break;
        case 'rejected':
          stageLabel = 'Rejected';
          break;
        default:
          stageLabel = targetStage.toUpperCase();
      }

      await db.insert('approvals', {
        'application_id': applicationId,
        'stage': stageLabel,
        'by_user': byUser,
        'by_role': byRole,
        'amount': sanctionedAmount,
        'remarks': remarks,
        'at': nowIso,
      });

      // If Disbursed, automatically create active loan with schedule!
      if (targetStage == 'disbursed') {
        final appList = await db.query('applications', where: 'id = ?', whereArgs: [applicationId]);
        if (appList.isNotEmpty) {
          final app = appList.first;
          final prodList = await db.query('products', where: 'id = ?', whereArgs: [app['product_id']]);
          final prod = prodList.first;

          final principal = sanctionedAmount;
          final rate = (app['rate'] as num).toDouble();
          final tenure = app['tenure'] as int;
          final method = (prod['method'] ?? 'reducing') as String;

          double emi;
          if (method == 'flat') {
            emi = (principal + (principal * rate / 100 * tenure / 12)) / tenure;
          } else {
            final r = rate / 1200;
            emi = principal * r * pow(1 + r, tenure) / (pow(1 + r, tenure) - 1);
          }
          emi = double.parse(emi.toStringAsFixed(2));

          final loanId = await db.insert('loans', {
            'application_id': applicationId,
            'customer_id': app['customer_id'],
            'product_id': app['product_id'],
            'principal': principal,
            'rate': rate,
            'tenure': tenure,
            'method': method,
            'emi': emi,
            'start_date': today.toIso8601String().substring(0, 10),
            'status': 'active',
            'branch': app['branch'],
            'agent_id': app['agent_id'],
          });

          double bal = principal;
          for (int i = 1; i <= tenure; i++) {
            double interest;
            double prin;
            if (method == 'flat') {
              interest = double.parse((principal * rate / 100 / 12).toStringAsFixed(2));
              prin = double.parse((principal / tenure).toStringAsFixed(2));
            } else {
              interest = double.parse((bal * rate / 1200).toStringAsFixed(2));
              prin = double.parse((emi - interest).toStringAsFixed(2));
            }
            if (i == tenure) prin = double.parse(bal.toStringAsFixed(2));
            bal = double.parse(max(0, bal - prin).toStringAsFixed(2));

            var due = DateTime(today.year, today.month + i, today.day);
            if (due.weekday == DateTime.saturday) due = due.add(const Duration(days: 2));
            if (due.weekday == DateTime.sunday) due = due.add(const Duration(days: 1));

            await db.insert('schedule', {
              'loan_id': loanId,
              'no': i,
              'due_date': due.toIso8601String().substring(0, 10),
              'emi': emi,
              'principal': prin,
              'interest': interest,
              'balance': bal,
              'paid': 0,
            });
          }

          // Update customer stage to 'active' now that loan is disbursed
          await db.update(
            'customers',
            {'stage': 'active'},
            where: 'id = ?',
            whereArgs: [app['customer_id']],
          );
        }
      }

      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('Error advancing application: $e');
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
    try {
      final db = await DatabaseHelper.instance.database;
      final prodList = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      if (prodList.isEmpty) return null;
      final rate = (prodList.first['rate'] as num).toDouble();

      final now = DateTime.now();
      final nowIso = now.toIso8601String().substring(0, 19);

      final appId = await db.insert('applications', {
        'customer_id': customerId,
        'product_id': productId,
        'amount': amount,
        'tenure': tenure,
        'rate': rate,
        'purpose': purpose,
        'income': income,
        'occupation': occupation,
        'employer': employer,
        'co_name': coName,
        'co_phone': coPhone,
        'co_relation': coRelation,
        'co_income': coIncome,
        'status': 'submitted',
        'agent_id': agentId,
        'branch': branch,
        'created': nowIso,
        'remarks': '',
        'docs': docsDeposited.join(','),
      });

      final totalExp = expBasic + expEducation + expFestival + expHealth + expEmi + expOther;
      final totalInc = incAgri + incBusiness + incJob + incOther > 0 ? (incAgri + incBusiness + incJob + incOther) : income;
      final netSav = totalInc - totalExp;

      await db.insert('app_extra', {
        'application_id': appId,
        'prev_loans': '[]',
        'insurance_wanted': insuranceWanted,
        'insurance_for': insuranceFor,
        'docs_deposited': docsDeposited.join(','),
        'docs_other': docsOther,
        'inc_agri': incAgri,
        'inc_business': incBusiness,
        'inc_job': incJob,
        'inc_other': incOther,
        'exp_basic': expBasic,
        'exp_education': expEducation,
        'exp_festival': expFestival,
        'exp_health': expHealth,
        'exp_emi': expEmi,
        'exp_other': expOther,
        'group_rec': groupRec > 0 ? groupRec : amount,
        'center_rec': centerRec > 0 ? centerRec : amount,
        'loan_cycle': loanCycle,
        'requested_amt': amount,
        'income_total': totalInc,
        'expense_total': totalExp,
        'net_saving': netSav,
        'declaration': declaration,
      });

      await db.insert('approvals', {
        'application_id': appId,
        'stage': 'Submitted',
        'by_user': 'Field Officer',
        'by_role': 'field_agent',
        'amount': amount,
        'remarks': 'New loan application submitted',
        'at': nowIso,
      });

      await fetchAll();
      return appId;
    } catch (e) {
      debugPrint('Error creating application: $e');
      return null;
    }
  }
}
