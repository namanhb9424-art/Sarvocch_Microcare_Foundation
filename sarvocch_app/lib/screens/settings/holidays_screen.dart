import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key});

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  List<Map<String, dynamic>> _holidays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('holidays', orderBy: 'day ASC');
      if (mounted) {
        setState(() {
          _holidays = rows.map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addHolidayDialog() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.role != 'admin') return;
    final dayCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Public Holiday', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'EMI schedules automatically shift due dates falling on holidays to the next working business day.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dayCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Holiday Date (YYYY-MM-DD) *',
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  dayCtrl.text = picked.toIso8601String().substring(0, 10);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Holiday Name *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final d = dayCtrl.text.trim();
              final n = nameCtrl.text.trim();
              if (d.isEmpty || n.isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              await db.insert('holidays', {'day': d, 'name': n}, conflictAlgorithm: ConflictAlgorithm.replace);
              await SyncService().enqueueAction(
                userId: user.id,
                action: 'holiday_saved',
                operationId: 'hol_save_$d',
                payload: {'day': d, 'name': n},
              );
              SyncService().triggerFullSync(userId: user.id);
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadHolidays();
            },
            child: const Text('Save Holiday'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHoliday(String day) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.role != 'admin') return;
    final db = await DatabaseHelper.instance.database;
    await db.delete('holidays', where: 'day = ?', whereArgs: [day]);
    await SyncService().enqueueAction(
      userId: user.id,
      action: 'holiday_deleted',
      operationId: 'hol_del_${day}_${DateTime.now().millisecondsSinceEpoch}',
      payload: {'day': day},
    );
    SyncService().triggerFullSync(userId: user.id);
    await _loadHolidays();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().currentUser?.role == 'admin';
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Holiday Calendar',
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _addHolidayDialog,
            ),
        ],
      ),
      drawer: const CustomDrawer(currentRoute: '/holidays'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _holidays.isEmpty
              ? const Center(
                  child: Text(
                    'No public holidays configured.\nStandard weekends apply.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _holidays.length,
                  itemBuilder: (context, idx) {
                    final h = _holidays[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.tealLight,
                          child: Icon(Icons.event, color: AppTheme.tealPrimary),
                        ),
                        title: Text(h['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Date: ${h['day']}'),
                        trailing: isAdmin
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                                onPressed: () => _deleteHoliday(h['day'] as String),
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
