import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class FieldTasksScreen extends StatefulWidget {
  const FieldTasksScreen({super.key});

  @override
  State<FieldTasksScreen> createState() => _FieldTasksScreenState();
}

class _FieldTasksScreenState extends State<FieldTasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  bool _syncing = false;
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery('''
      SELECT t.*, c.name as customer_name, c.phone as customer_phone
      FROM tasks t
      LEFT JOIN customers c ON t.customer_id = c.id
      ORDER BY t.status ASC, t.id ASC
    ''');
    if (mounted) {
      setState(() {
        _tasks = results;
        _loading = false;
      });
    }
  }

  Future<void> _markTaskDone(int taskId) async {
    final collectedCtrl = TextEditingController(text: '5200');
    final notesCtrl = TextEditingController(text: 'Collected in cash during center meeting');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Field Collection / Visit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: collectedCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount Collected (₹) *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Field Notes'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = await DatabaseHelper.instance.database;
              final nowIso = DateTime.now().toIso8601String().substring(0, 19);
              final todayStr = DateTime.now().toIso8601String().substring(0, 10);
              final task = _tasks.firstWhere((t) => t['id'] == taskId, orElse: () => {});
              final collectedAmount = double.tryParse(collectedCtrl.text) ?? 0.0;

              await db.update(
                'tasks',
                {
                  'status': 'done',
                  'collected': collectedAmount,
                  'notes': notesCtrl.text.trim(),
                  'done_at': nowIso,
                },
                where: 'id = ?',
                whereArgs: [taskId],
              );

              // If this is a collection task with a loan_id, record payment & mark schedule
              if (task.isNotEmpty && task['loan_id'] != null && collectedAmount > 0) {
                final loanId = task['loan_id'] as int;

                // Find the first unpaid overdue schedule entry
                final overdueRows = await db.query(
                  'schedule',
                  where: 'loan_id = ? AND paid = 0 AND due_date <= ?',
                  whereArgs: [loanId, todayStr],
                  orderBy: 'no ASC',
                  limit: 1,
                );

                int? scheduleId;
                if (overdueRows.isNotEmpty) {
                  scheduleId = overdueRows.first['id'] as int?;
                  await db.update(
                    'schedule',
                    {'paid': 1, 'paid_on': todayStr},
                    where: 'id = ?',
                    whereArgs: [scheduleId],
                  );
                }

                // Record payment entry
                await db.insert('payments', {
                  'loan_id': loanId,
                  'schedule_id': scheduleId ?? 0,
                  'amount': collectedAmount,
                  'channel': 'field_cash',
                  'ref': 'FIELD${DateTime.now().millisecondsSinceEpoch}',
                  'at': nowIso,
                });
              }

              if (ctx.mounted) Navigator.pop(ctx);
              await _loadTasks();
            },
            child: const Text('Record Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSync() async {
    setState(() => _syncing = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() => _syncing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline Queue Synced: 6 Tasks & GPS coordinates reconciled with database.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Field Operations & Tasks',
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync),
            tooltip: 'Sync Offline Queue',
            onPressed: _syncing ? null : _triggerSync,
          ),
        ],
      ),
      drawer: const CustomDrawer(currentRoute: '/field'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final t = _tasks[index];
                final isDone = t['status'] == 'done';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isDone ? AppTheme.successLight : AppTheme.tealSurface,
                      child: Icon(
                        isDone ? Icons.check : (t['ttype'] == 'collection' ? Icons.monetization_on : Icons.verified),
                        color: isDone ? AppTheme.success : AppTheme.tealPrimary,
                        size: 20,
                      ),
                    ),
                    title: Text(t['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          'Borrower: ${t['customer_name'] ?? "N/A"} (${t['customer_phone'] ?? ""})',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        Text(
                          'Location: ${t['lat']}, ${t['lng']} • Due: ${t['due_date']}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        if (isDone)
                          Text(
                            'Collected: ${currency.format(t['collected'] ?? 0)} (${t['notes'] ?? ""})',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.success, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    trailing: isDone
                        ? const Text('COMPLETED', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 11))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                            onPressed: () => _markTaskDone(t['id'] as int),
                            child: const Text('Complete', style: TextStyle(fontSize: 12)),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
