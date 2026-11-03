import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final db = await DatabaseHelper.instance.database;
    final branchRows = await db.query('branches', orderBy: 'id ASC');

    List<Map<String, dynamic>> enhanced = [];
    for (var b in branchRows) {
      final name = b['name'] as String;
      
      // Calculate branch statistics
      final staffCount = (await db.rawQuery(
        'SELECT COUNT(*) as c FROM employees WHERE branch = ? AND status != ?',
        [name, 'exited'],
      )).first['c'] as int? ?? 0;

      final custCount = (await db.rawQuery(
        'SELECT COUNT(*) as c FROM customers WHERE branch = ?',
        [name],
      )).first['c'] as int? ?? 0;

      final activeLoans = (await db.rawQuery(
        'SELECT COUNT(*) as c FROM loans WHERE branch = ? AND status = ?',
        [name, 'active'],
      )).first['c'] as int? ?? 0;

      final disbursedSum = (await db.rawQuery(
        'SELECT IFNULL(SUM(principal), 0) as s FROM loans WHERE branch = ?',
        [name],
      )).first['s'] as num? ?? 0.0;

      final overdueCount = (await db.rawQuery('''
        SELECT COUNT(DISTINCT l.id) as c 
        FROM schedule s 
        JOIN loans l ON l.id = s.loan_id 
        WHERE s.paid = 0 AND s.due_date < date('now') AND l.branch = ?
      ''', [name])).first['c'] as int? ?? 0;

      final map = Map<String, dynamic>.from(b);
      map['staff_count'] = staffCount;
      map['customer_count'] = custCount;
      map['active_loans'] = activeLoans;
      map['total_disbursed'] = disbursedSum.toDouble();
      map['overdue_loans'] = overdueCount;
      enhanced.add(map);
    }

    if (mounted) {
      setState(() {
        _branches = enhanced;
        _loading = false;
      });
    }
  }

  void _showAddBranchDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final headCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '22.7533');
    final lngCtrl = TextEditingController(text: '75.8937');
    final radiusCtrl = TextEditingController(text: '2000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Branch Office', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Branch Name (e.g. Bhopal - MP Nagar) *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Branch Code (BHO-02)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Full Address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: headCtrl,
                decoration: const InputDecoration(labelText: 'Branch Head Manager Name'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'GPS Latitude'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'GPS Longitude'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: radiusCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Punch Radius (Meters, default: 2000)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              await db.insert('branches', {
                'name': nameCtrl.text.trim(),
                'code': codeCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'head_name': headCtrl.text.trim(),
                'lat': double.tryParse(latCtrl.text) ?? 22.7533,
                'lng': double.tryParse(lngCtrl.text) ?? 75.8937,
                'radius_m': int.tryParse(radiusCtrl.text) ?? 2000,
                'active': 1,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadBranches();
            },
            child: const Text('Save Branch'),
          ),
        ],
      ),
    );
  }

  void _showBranchDetailsSheet(Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.tealSurface,
                  radius: 22,
                  child: const Icon(Icons.business, color: AppTheme.tealPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Code: ${b['code']} • Branch Head: ${b['head_name'] ?? "Not Assigned"}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('BRANCH PORTFOLIO & STATS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statBox('Active Staff', '${b['staff_count']}', Icons.badge_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _statBox('Borrowers', '${b['customer_count']}', Icons.people_outline)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _statBox('Active Loans', '${b['active_loans']}', Icons.monetization_on_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _statBox('Overdue', '${b['overdue_loans']}', Icons.warning_amber_outlined, isDanger: (b['overdue_loans'] as int) > 0)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Disbursed Portfolio: ${currency.format(b['total_disbursed'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.tealPrimary)),
                  const SizedBox(height: 4),
                  Text('Address: ${b['address']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text('GPS: ${b['lat']}, ${b['lng']} (Radius: ${b['radius_m']}m)',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, IconData icon, {bool isDanger = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDanger ? AppTheme.dangerLight : AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDanger ? AppTheme.danger : AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDanger ? AppTheme.danger : AppTheme.tealPrimary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
              Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDanger ? AppTheme.danger : AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Branch Offices & Portfolios'),
      drawer: const CustomDrawer(currentRoute: '/branches'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.tealPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Branch'),
        onPressed: _showAddBranchDialog,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _branches.isEmpty
              ? const Center(child: Text('No branch offices registered.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _branches.length,
                  itemBuilder: (context, index) {
                    final b = _branches[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.tealSurface,
                          child: const Icon(Icons.account_balance, color: AppTheme.tealPrimary),
                        ),
                        title: Text(
                          b['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${b['address']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Staff: ${b['staff_count']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 10),
                                Text('Active Loans: ${b['active_loans']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.tealPrimary)),
                                const SizedBox(width: 10),
                                if ((b['overdue_loans'] as int) > 0)
                                  Text('Overdue: ${b['overdue_loans']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.danger)),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        onTap: () => _showBranchDetailsSheet(b),
                      ),
                    );
                  },
                ),
    );
  }
}
