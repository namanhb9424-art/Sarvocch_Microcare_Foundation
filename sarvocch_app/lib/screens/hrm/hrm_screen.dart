import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/currency_amount.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class HrmScreen extends StatefulWidget {
  const HrmScreen({super.key});

  @override
  State<HrmScreen> createState() => _HrmScreenState();
}

class _HrmScreenState extends State<HrmScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _perfList = [];
  bool _loading = true;
  final currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllHrmData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllHrmData() async {
    final db = await DatabaseHelper.instance.database;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _employees = [];
          _leaves = [];
          _perfList = [];
          _loading = false;
        });
      }
      return;
    }

    final hrmData = await db.transaction((txn) async {
      final actors = await txn.query(
        'users',
        columns: ['role', 'branch', 'auth_status'],
        where: 'id = ?',
        whereArgs: [user.id],
        limit: 1,
      );
      if (actors.isEmpty || actors.first['auth_status'] != 'active') {
        return null;
      }
      final role = actors.first['role'] as String? ?? '';
      final branch = (actors.first['branch'] as String? ?? '').trim();
      if (!{'admin', 'manager'}.contains(role) ||
          (role == 'manager' && branch.isEmpty)) {
        return null;
      }

      final empRows = await txn.rawQuery(
        '''
        SELECT e.*, m.name as manager_name
        FROM employees e
        LEFT JOIN employees m ON m.id = e.manager_id
        WHERE (? = 'admin') OR e.branch = ?
        ORDER BY e.id ASC
      ''',
        [role, branch],
      );
      final leaveRows = await txn.rawQuery(
        '''
        SELECT l.*, u.name as user_name
        FROM leaves l
        JOIN users u ON u.id = l.user_id
        WHERE (? = 'admin') OR u.branch = ?
        ORDER BY l.id DESC
      ''',
        [role, branch],
      );
      final perfRows = await txn.rawQuery(
        '''
        SELECT p.*, u.name as user_name
        FROM perf p
        JOIN users u ON u.id = p.user_id
        WHERE (? = 'admin') OR u.branch = ?
        ORDER BY p.id DESC
      ''',
        [role, branch],
      );
      return (employees: empRows, leaves: leaveRows, performance: perfRows);
    });

    if (mounted) {
      setState(() {
        _employees = hrmData?.employees ?? [];
        _leaves = hrmData?.leaves ?? [];
        _perfList = hrmData?.performance ?? [];
        _loading = false;
      });
    }
  }

  void _showAddEmployeeDialog() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final nameCtrl = TextEditingController();
    final desigCtrl = TextEditingController();
    final branchCtrl = TextEditingController(
      text: user.role == 'admin' ? '' : user.branch,
    );
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Add Staff Employee',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Legal Name *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: desigCtrl,
                decoration: const InputDecoration(labelText: 'Designation'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: branchCtrl,
                enabled: user.role == 'admin',
                decoration: const InputDecoration(labelText: 'Branch *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: salaryCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Gross (₹)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final salary = double.tryParse(salaryCtrl.text.trim());
              final normalizedPhone = phoneCtrl.text.trim().replaceAll(
                RegExp(r'\D'),
                '',
              );
              final email = emailCtrl.text.trim();
              if (nameCtrl.text.trim().isEmpty ||
                  desigCtrl.text.trim().isEmpty ||
                  !RegExp(r'^\d{10}$').hasMatch(normalizedPhone) ||
                  branchCtrl.text.trim().isEmpty ||
                  salary == null ||
                  !salary.isFinite ||
                  salary <= 0 ||
                  !CurrencyAmount.hasPaisePrecision(salary) ||
                  (email.isNotEmpty &&
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) ||
                  (user.role != 'admin' &&
                      branchCtrl.text.trim() != user.branch)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a name, designation, valid 10-digit phone, active branch, and positive gross salary with at most two decimal places.',
                    ),
                  ),
                );
                return;
              }
              try {
                final db = await DatabaseHelper.instance.database;
                final now = DateTime.now();
                final nowIso = now.toIso8601String().substring(0, 19);
                final todayStr = DateFormat('yyyy-MM-dd').format(now);
                await db.transaction((txn) async {
                  final actors = await txn.query(
                    'users',
                    columns: ['name', 'role', 'branch', 'auth_status'],
                    where: 'id = ?',
                    whereArgs: [user.id],
                    limit: 1,
                  );
                  if (actors.isEmpty ||
                      actors.first['auth_status'] != 'active' ||
                      !{'admin', 'manager'}.contains(actors.first['role'])) {
                    throw StateError('Staff creation is not authorized.');
                  }
                  final actorRole = actors.first['role'] as String;
                  final actorBranch = (actors.first['branch'] as String? ?? '')
                      .trim();
                  final branchName = branchCtrl.text.trim();
                  if (actorRole == 'manager' &&
                      (actorBranch.isEmpty || actorBranch != branchName)) {
                    throw StateError('Employee is outside this branch.');
                  }
                  final branches = await txn.query(
                    'branches',
                    columns: ['id'],
                    where: 'name = ? AND active = 1',
                    whereArgs: [branchName],
                    limit: 1,
                  );
                  if (branches.isEmpty) {
                    throw StateError('Branch is not active.');
                  }
                  final existingEmployees = await txn.query(
                    'employees',
                    columns: ['phone'],
                  );
                  if (existingEmployees.any(
                    (employee) =>
                        (employee['phone'] as String? ?? '').replaceAll(
                          RegExp(r'\D'),
                          '',
                        ) ==
                        normalizedPhone,
                  )) {
                    throw StateError('Employee phone is already in use.');
                  }
                  final employeeId = await txn.insert('employees', {
                    'name': nameCtrl.text.trim(),
                    'designation': desigCtrl.text.trim(),
                    'branch': branchName,
                    'phone': phoneCtrl.text.trim(),
                    'email': email,
                    'salary': salary,
                    'salary_paise': CurrencyAmount.toMinorUnits(salary),
                    'joined': todayStr,
                    'status': 'onboarding',
                    'bg_check': 'in_progress',
                    'docs': '[]',
                  });
                  await txn.insert('audit_log', {
                    'operation_id': const Uuid().v4(),
                    'entity_type': 'employee',
                    'entity_id': employeeId,
                    'action': 'employee_created',
                    'actor_user_id': user.id,
                    'actor_role': actorRole,
                    'actor_name': actors.first['name'],
                    'occurred_at': nowIso,
                    'details': jsonEncode({
                      'branch': branchName,
                      'designation': desigCtrl.text.trim(),
                      'status': 'onboarding',
                    }),
                  });
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAllHrmData();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Employee was not saved. Check branch access and ensure the phone is not already assigned.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Add Employee'),
          ),
        ],
      ),
    );
  }

  void _showAddLeaveDialog() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Apply for Leave',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromCtrl,
                    decoration: const InputDecoration(
                      labelText: 'From Date (YYYY-MM-DD)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: toCtrl,
                    decoration: const InputDecoration(
                      labelText: 'To Date (YYYY-MM-DD)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for Leave *',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final fromDate = _parseDateOnly(fromCtrl.text.trim());
              final toDate = _parseDateOnly(toCtrl.text.trim());
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              if (reasonCtrl.text.trim().length < 4 ||
                  fromDate == null ||
                  toDate == null ||
                  fromDate.isBefore(todayDate) ||
                  toDate.isBefore(fromDate)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a reason and a valid date range starting today or later.',
                    ),
                  ),
                );
                return;
              }
              try {
                final db = await DatabaseHelper.instance.database;
                final nowIso = DateTime.now().toIso8601String().substring(
                  0,
                  19,
                );
                await db.transaction((txn) async {
                  final actors = await txn.query(
                    'users',
                    columns: ['name', 'role', 'branch', 'auth_status'],
                    where: 'id = ?',
                    whereArgs: [user.id],
                    limit: 1,
                  );
                  if (actors.isEmpty ||
                      actors.first['auth_status'] != 'active' ||
                      !{'admin', 'manager'}.contains(actors.first['role'])) {
                    throw StateError('Leave request is not authorized.');
                  }
                  final role = actors.first['role'] as String;
                  final branch = (actors.first['branch'] as String? ?? '')
                      .trim();
                  if (role == 'manager' && branch.isEmpty) {
                    throw StateError('Manager branch is not configured.');
                  }
                  final overlap = await txn.rawQuery(
                    '''
                    SELECT id FROM leaves
                    WHERE user_id = ?
                      AND lower(status) IN ('pending', 'approved')
                      AND from_d <= ? AND to_d >= ?
                    LIMIT 1
                  ''',
                    [user.id, toCtrl.text.trim(), fromCtrl.text.trim()],
                  );
                  if (overlap.isNotEmpty) {
                    throw StateError('Leave dates overlap another request.');
                  }
                  final leaveId = await txn.insert('leaves', {
                    'user_id': user.id,
                    'from_d': fromCtrl.text.trim(),
                    'to_d': toCtrl.text.trim(),
                    'reason': reasonCtrl.text.trim(),
                    'status': 'pending',
                  });
                  await txn.insert('audit_log', {
                    'operation_id': const Uuid().v4(),
                    'entity_type': 'leave',
                    'entity_id': leaveId,
                    'action': 'leave_submitted',
                    'actor_user_id': user.id,
                    'actor_role': role,
                    'actor_name': actors.first['name'],
                    'occurred_at': nowIso,
                    'details': jsonEncode({
                      'from': fromCtrl.text.trim(),
                      'to': toCtrl.text.trim(),
                    }),
                  });
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAllHrmData();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Leave request was not saved. Check date range and existing requests.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Submit Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLeaveStatus(int leaveId, String newStatus) async {
    final actor = context.read<AuthProvider>().currentUser;
    if (actor == null ||
        !{'admin', 'manager'}.contains(actor.role) ||
        !{'approved', 'rejected'}.contains(newStatus)) {
      return;
    }
    final db = await DatabaseHelper.instance.database;
    final nowIso = DateTime.now().toIso8601String().substring(0, 19);
    try {
      final changed = await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actor.id],
          limit: 1,
        );
        if (actors.isEmpty ||
            actors.first['auth_status'] != 'active' ||
            !{'admin', 'manager'}.contains(actors.first['role'])) {
          throw StateError('Leave review is not authorized.');
        }
        final requests = await txn.rawQuery(
          '''
          SELECT l.user_id, l.status, l.from_d, l.to_d, u.branch
          FROM leaves l
          JOIN users u ON u.id = l.user_id
          WHERE l.id = ?
          LIMIT 1
        ''',
          [leaveId],
        );
        if (requests.isEmpty ||
            requests.first['status'] != 'pending' ||
            requests.first['user_id'] == actor.id) {
          throw StateError('Leave request cannot be reviewed by this user.');
        }
        final actorRole = actors.first['role'] as String;
        final actorBranch = (actors.first['branch'] as String? ?? '').trim();
        if (actorRole == 'manager' &&
            (actorBranch.isEmpty || actorBranch != requests.first['branch'])) {
          throw StateError('Leave request is outside this branch.');
        }
        final updated = await txn.update(
          'leaves',
          {'status': newStatus},
          where: 'id = ? AND status = ?',
          whereArgs: [leaveId, 'pending'],
        );
        if (updated != 1) return false;
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'leave',
          'entity_id': leaveId,
          'action': 'leave_$newStatus',
          'actor_user_id': actor.id,
          'actor_role': actorRole,
          'actor_name': actors.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'requester_user_id': requests.first['user_id'],
            'from': requests.first['from_d'],
            'to': requests.first['to_d'],
          }),
        });
        return true;
      });
      if (changed) await _loadAllHrmData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Leave review was not saved. Check branch access and ensure you did not submit the request yourself.',
            ),
          ),
        );
      }
    }
  }

  DateTime? _parseDateOnly(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'HRM & Human Resources'),
      drawer: const CustomDrawer(currentRoute: '/hrm'),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.tealPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.tealPrimary,
              isScrollable: true,
              tabs: [
                Tab(text: 'Staff (${_employees.length})'),
                Tab(text: 'Leaves (${_leaves.length})'),
                Tab(text: 'Performance (${_perfList.length})'),
                const Tab(text: 'Payroll setup required'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEmployeesTab(),
                      _buildLeavesTab(),
                      _buildPerfTab(),
                      _buildPayrollTab(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.tealPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('New Action'),
        onPressed: () {
          if (_tabController.index == 1) {
            _showAddLeaveDialog();
          } else {
            _showAddEmployeeDialog();
          }
        },
      ),
    );
  }

  Widget _buildEmployeesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _employees.length,
      itemBuilder: (ctx, i) {
        final e = _employees[i];
        final isActive = e['status'] == 'active';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: AppTheme.tealSurface,
              child: Text(
                (e['name'] as String).isNotEmpty
                    ? (e['name'] as String)[0]
                    : 'E',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.tealPrimary,
                ),
              ),
            ),
            title: Text(
              e['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  '${e['designation']} • ${e['branch']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Phone: ${e['phone']} • Gross: ${_salaryDisplay(e)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.tealPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isActive ? AppTheme.success : Colors.orange)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (e['status'] as String? ?? 'onboarding').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppTheme.success : Colors.orange.shade800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeavesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _leaves.length,
      itemBuilder: (ctx, i) {
        final l = _leaves[i];
        final isPending = l['status'] == 'pending';
        final isApproved = l['status'] == 'approved';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l['user_name'] ?? 'Staff Member',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isApproved
                                    ? AppTheme.success
                                    : isPending
                                    ? Colors.orange
                                    : AppTheme.danger)
                                .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (l['status'] as String).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isApproved
                              ? AppTheme.success
                              : isPending
                              ? Colors.orange.shade800
                              : AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Dates: ${l['from_d']} to ${l['to_d']}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reason: ${l['reason']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            _updateLeaveStatus(l['id'] as int, 'rejected'),
                        child: const Text(
                          'Reject',
                          style: TextStyle(color: AppTheme.danger),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _updateLeaveStatus(l['id'] as int, 'approved'),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerfTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _perfList.length,
      itemBuilder: (ctx, i) {
        final p = _perfList[i];
        final rating = p['rating'] as int?;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  p['user_name'] ?? 'Employee',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  p['period'] ?? 'Period not recorded',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                if (rating == null)
                  const Text(
                    'Rating not recorded',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  )
                else
                  Row(
                    children: List.generate(
                      5,
                      (star) => Icon(
                        star < rating ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '"${p['notes']}"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Evaluated by: ${p['by_name']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPayrollTab() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Payroll calculations are unavailable until the organization configures approved salary components, attendance rules, deductions and statutory settings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  String _salaryDisplay(Map<String, dynamic> employee) {
    final paise = employee['salary_paise'] as num?;
    if (paise != null) {
      return currency.format(CurrencyAmount.fromMinorUnits(paise.toInt()));
    }
    final legacySalary = employee['salary'] as num?;
    return legacySalary == null
        ? 'Not configured'
        : currency.format(legacySalary.toDouble());
  }
}
