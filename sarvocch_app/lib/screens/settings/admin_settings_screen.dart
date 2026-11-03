import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database_helper.dart';
import '../../providers/customer_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/pregrt_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _minAgeCtrl = TextEditingController(text: '18');
  final _maxAgeCtrl = TextEditingController(text: '55');
  final _minGroupCtrl = TextEditingController(text: '2');
  final _maxGroupCtrl = TextEditingController(text: '5');
  final _maxIncomeCtrl = TextEditingController(text: '300000');
  final _maxEmiPctCtrl = TextEditingController(text: '60');
  final _gstRateCtrl = TextEditingController(text: '18');
  final _punchRadiusCtrl = TextEditingController(text: '2000');

  bool _loading = false;

  Future<void> _saveSettings() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;

    final map = {
      'min_age': _minAgeCtrl.text,
      'max_age': _maxAgeCtrl.text,
      'min_group': _minGroupCtrl.text,
      'max_group': _maxGroupCtrl.text,
      'max_household_income': _maxIncomeCtrl.text,
      'max_emi_pct': _maxEmiPctCtrl.text,
      'gst_rate': _gstRateCtrl.text,
      'punch_radius_m': _punchRadiusCtrl.text,
    };

    for (var entry in map.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings and policy rules updated successfully!'), backgroundColor: AppTheme.success),
      );
    }
  }

  Future<void> _resetDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset SQLite Demo Database?'),
        content: const Text('This will re-initialize all 18 tables with the default demo records matching the prototype repository.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Demo Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      await DatabaseHelper.instance.resetDatabase();
      if (!mounted) return;
      // Refresh all providers so in-memory state matches the reset DB
      await Future.wait([
        context.read<LoanProvider>().fetchAll(),
        context.read<CustomerProvider>().fetchCustomers(),
        context.read<PreGrtProvider>().fetchPreGrts(),
      ]);
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database reset and re-seeded with demo records!'), backgroundColor: AppTheme.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Admin Settings & Policies'),
      drawer: const CustomDrawer(currentRoute: '/settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Policy Controls Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MFI LENDING RULES & LIMITS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: _minAgeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Borrower Age'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _maxAgeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Borrower Age'))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: _minGroupCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Group Size'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _maxGroupCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Group Size'))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: _maxIncomeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Annual Income (₹)'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _maxEmiPctCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max EMI % of Income'))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: _gstRateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'GST Rate % (CGST + SGST)'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _punchRadiusCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Punch Radius (Meters)'))),
                      ],
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _saveSettings,
                        child: const Text('Save Policy Configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Demo Database Maintenance
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SQLITE DATABASE & DEMO TRIAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    const Text(
                      'Re-seed default demo accounts: Aarav (Admin), Meera (Manager), Uday (Underwriter), Ravi/Sneha/Imran (Field Officers), and Sunita (Customer).',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: AppTheme.danger),
                      label: const Text('Reset SQLite Database to Clean Demo Data', style: TextStyle(color: AppTheme.danger)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.danger),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: _loading ? null : _resetDatabase,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
