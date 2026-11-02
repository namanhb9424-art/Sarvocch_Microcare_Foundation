import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class HrmScreen extends StatefulWidget {
  const HrmScreen({super.key});

  @override
  State<HrmScreen> createState() => _HrmScreenState();
}

class _HrmScreenState extends State<HrmScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _perfList = [];
  List<Map<String, dynamic>> _payroll = [];
  bool _loading = true;
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

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

    // 1. Employees
    final empRows = await db.rawQuery('''
      SELECT e.*, m.name as manager_name 
      FROM employees e 
      LEFT JOIN employees m ON m.id = e.manager_id 
      ORDER BY e.id ASC
    ''');

    // 2. Leaves
    final leaveRows = await db.rawQuery('''
      SELECT l.*, u.name as user_name 
      FROM leaves l 
      JOIN users u ON u.id = l.user_id 
      ORDER BY l.id DESC
    ''');

    // 3. Performance
    final perfRows = await db.rawQuery('''
      SELECT p.*, u.name as user_name 
      FROM perf p 
      JOIN users u ON u.id = p.user_id 
      ORDER BY p.id DESC
    ''');

    // 4. Payroll calculation for current month
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final attRows = await db.rawQuery('''
      SELECT u.id as user_id, u.name, COUNT(a.id) as present 
      FROM users u 
      LEFT JOIN attendance a ON a.user_id = u.id AND substr(a.day, 1, 7) = ? 
      WHERE u.role != 'customer' 
      GROUP BY u.id 
      ORDER BY u.name ASC
    ''', [currentMonth]);

    List<Map<String, dynamic>> payrollCalc = [];
    for (var r in attRows) {
      final uId = r['user_id'] as int;
      final emp = empRows.where((e) => e['user_id'] == uId).firstOrNull;
      final basic = (emp?['salary'] as num?)?.toDouble() ?? 24000.0;
      final present = (r['present'] as int?) ?? 22;
      final lop = (26 - present) > 0 ? (26 - present) : 0;
      final lopAmt = (basic / 26) * lop;
      final hra = basic * 0.40;
      final pf = basic * 0.12;
      final net = basic + hra - pf - lopAmt;

      payrollCalc.add({
        'name': r['name'] as String,
        'present': present,
        'basic': basic,
        'hra': hra,
        'pf': pf,
        'lop': lop,
        'lop_amt': lopAmt,
        'net': net,
      });
    }

    if (mounted) {
      setState(() {
        _employees = empRows;
        _leaves = leaveRows;
        _perfList = perfRows;
        _payroll = payrollCalc;
        _loading = false;
      });
    }
  }

  void _showAddEmployeeDialog() {
    final nameCtrl = TextEditingController();
    final desigCtrl = TextEditingController(text: 'Field Officer');
    final branchCtrl = TextEditingController(text: 'Indore - Vijay Nagar');
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final salaryCtrl = TextEditingController(text: '22000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Staff Employee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Legal Name *')),
              const SizedBox(height: 10),
              TextField(controller: desigCtrl, decoration: const InputDecoration(labelText: 'Designation')),
              const SizedBox(height: 10),
              TextField(controller: branchCtrl, decoration: const InputDecoration(labelText: 'Branch')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: salaryCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Gross (₹)'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
              await db.insert('employees', {
                'name': nameCtrl.text.trim(),
                'designation': desigCtrl.text.trim(),
                'branch': branchCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'salary': double.tryParse(salaryCtrl.text) ?? 22000.0,
                'joined': todayStr,
                'status': 'onboarding',
                'bg_check': 'in_progress',
                'docs': '["Aadhaar Card", "PAN Card", "Driving License"]',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadAllHrmData();
            },
            child: const Text('Add Employee'),
          ),
        ],
      ),
    );
  }

  void _showAddLeaveDialog() {
    final auth = context.read<AuthProvider>();
    final fromCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 2))));
    final toCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 3))));
    final reasonCtrl = TextEditingController(text: 'Family function & personal travel');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: fromCtrl, decoration: const InputDecoration(labelText: 'From Date (YYYY-MM-DD)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'To Date (YYYY-MM-DD)'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for Leave *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              await db.insert('leaves', {
                'user_id': auth.currentUser?.id ?? 4,
                'from_d': fromCtrl.text.trim(),
                'to_d': toCtrl.text.trim(),
                'reason': reasonCtrl.text.trim(),
                'status': 'pending',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadAllHrmData();
            },
            child: const Text('Submit Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLeaveStatus(int leaveId, String newStatus) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('leaves', {'status': newStatus}, where: 'id = ?', whereArgs: [leaveId]);
    await _loadAllHrmData();
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
                Tab(text: 'Payroll (${_payroll.length})'),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppTheme.tealSurface,
              child: Text(
                (e['name'] as String).isNotEmpty ? (e['name'] as String)[0] : 'E',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.tealPrimary),
              ),
            ),
            title: Text(e['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('${e['designation']} • ${e['branch']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text('Phone: ${e['phone']} • Gross: ${currency.format(e['salary'] ?? 0)}',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.tealPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isActive ? AppTheme.success : Colors.orange).withOpacity(0.12),
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
                    Text(l['user_name'] ?? 'Staff Member', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isApproved ? AppTheme.success : isPending ? Colors.orange : AppTheme.danger).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (l['status'] as String).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isApproved ? AppTheme.success : isPending ? Colors.orange.shade800 : AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Dates: ${l['from_d']} to ${l['to_d']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Reason: ${l['reason']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (isPending) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _updateLeaveStatus(l['id'] as int, 'rejected'),
                        child: const Text('Reject', style: TextStyle(color: AppTheme.danger)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _updateLeaveStatus(l['id'] as int, 'approved'),
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
        final rating = p['rating'] as int? ?? 4;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p['user_name'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(p['period'] ?? 'Q3 2026', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
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
                Text('"${p['notes']}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                const SizedBox(height: 4),
                Text('Evaluated by: ${p['by_name']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPayrollTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _payroll.length,
      itemBuilder: (ctx, i) {
        final pr = _payroll[i];
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
                    Text(pr['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      currency.format(pr['net']),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.tealPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Present Days: ${pr['present']} / 26 working days (LOP: ${pr['lop']} days)',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Basic: ${currency.format(pr['basic'])}', style: const TextStyle(fontSize: 11)),
                    Text('HRA (+40%): ${currency.format(pr['hra'])}', style: const TextStyle(fontSize: 11)),
                    Text('PF (-12%): ${currency.format(pr['pf'])}', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
