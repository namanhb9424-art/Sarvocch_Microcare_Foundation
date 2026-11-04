import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/database_helper.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class FieldTasksScreen extends StatefulWidget {
  const FieldTasksScreen({super.key});

  @override
  State<FieldTasksScreen> createState() => _FieldTasksScreenState();
}

class _FieldTasksScreenState extends State<FieldTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  bool _syncing = false;
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

                await db.insert('payments', {
                  'loan_id': loanId,
                  'schedule_id': scheduleId ?? 0,
                  'amount': collectedAmount,
                  'channel': 'field_cash',
                  'ref': 'FIELD${DateTime.now().millisecondsSinceEpoch}',
                  'at': nowIso,
                });

                // Enqueue to offline sync
                await SyncService().enqueueAction(
                  userId: 4,
                  action: 'field_collection',
                  payload: {
                    'loan_id': loanId,
                    'amount': collectedAmount,
                    'task_id': taskId,
                    'notes': notesCtrl.text.trim(),
                  },
                );
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
    final success = await SyncService().triggerFullSync();
    setState(() => _syncing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Tasks & Collections synchronized successfully!' : 'Sync queued locally for transmission.'),
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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.tealPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.tealPrimary,
              tabs: const [
                Tab(icon: Icon(Icons.format_list_bulleted, size: 20), text: 'Task List'),
                Tab(icon: Icon(Icons.map_outlined, size: 20), text: 'Spatial Map View'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Task List
                      ListView.builder(
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

                      // Tab 2: Spatial Map View
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 260,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E9EC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blueGrey.shade200),
                              ),
                              child: Stack(
                                children: [
                                  // Grid styling lines representing map grid
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _MapGridPainter(),
                                    ),
                                  ),

                                  // Center Location Pins
                                  for (int i = 0; i < _tasks.length; i++) ...[
                                    Positioned(
                                      left: 30.0 + (i * 55.0) % 260,
                                      top: 40.0 + (i * 45.0) % 180,
                                      child: GestureDetector(
                                        onTap: () {
                                          final t = _tasks[i];
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('${t['title']}: ${t['customer_name']} (Due: ₹${t['collected'] ?? 5200})')),
                                          );
                                        },
                                        child: Column(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: _tasks[i]['status'] == 'done' ? AppTheme.success : AppTheme.tealPrimary,
                                              child: Text(
                                                '${i + 1}',
                                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
                                              child: Text(
                                                _tasks[i]['customer_name'] ?? 'Task',
                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Field Agent GPS Marker
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.my_location, color: AppTheme.tealPrimary, size: 16),
                                          SizedBox(width: 6),
                                          Text('Live Agent GPS: Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyDark)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Field Centers & Route Sequence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            ..._tasks.map((t) {
                              final isDone = t['status'] == 'done';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.pin_drop, color: isDone ? AppTheme.success : AppTheme.tealPrimary, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text('Lat: ${t['lat']} • Lng: ${t['lng']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDone ? AppTheme.successLight : Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isDone ? 'VISITED' : 'PENDING VISIT',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDone ? AppTheme.success : Colors.amber.shade900),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.shade100
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 35) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 35) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Road route representation line
    final routePaint = Paint()
      ..color = Colors.teal.shade200
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(30, 40)
      ..lineTo(90, 85)
      ..lineTo(145, 60)
      ..lineTo(200, 130)
      ..lineTo(255, 175);

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
