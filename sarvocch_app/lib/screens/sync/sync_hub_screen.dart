import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database_helper.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/grievance_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/pregrt_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class SyncHubScreen extends StatefulWidget {
  const SyncHubScreen({super.key});

  @override
  State<SyncHubScreen> createState() => _SyncHubScreenState();
}

class _SyncHubScreenState extends State<SyncHubScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('sync_log', orderBy: 'id DESC', limit: 60);
      if (mounted) {
        setState(() {
          _logs = rows.map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runCloudSync() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final ok = await SyncService().triggerFullSync(userId: user.id);
    if (!mounted) return;
    await Future.wait([
      context.read<LoanProvider>().fetchAll(actorUserId: user.id),
      context.read<CustomerProvider>().fetchCustomers(actorUserId: user.id),
      context.read<PreGrtProvider>().fetchPreGrts(user.id),
      context.read<AttendanceProvider>().fetchAttendanceData(user.id),
      context.read<GrievanceProvider>().fetchGrievances(actorUserId: user.id),
      _loadLogs(),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Bi-directional Cloud Sync Complete! Live website & app data matched.'
              : SyncService().lastSyncStatus,
        ),
        backgroundColor: ok ? AppTheme.success : AppTheme.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    return Scaffold(
      appBar: const CustomAppBar(title: 'Cloud Sync & Offline Queue'),
      drawer: const CustomDrawer(currentRoute: '/sync'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sync.isCloudOnline ? Icons.cloud_done : Icons.cloud_queue,
                        color: sync.isCloudOnline ? AppTheme.success : AppTheme.tealPrimary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SARVOOCCH Hostinger Cloud Sync',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              sync.lastSyncStatus,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pending Offline Operations: ${sync.pendingCount}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (sync.lastSyncedAt != null)
                        Text('Last Sync: ${sync.lastSyncedAt}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: sync.isSyncing ? null : _runCloudSync,
                      icon: sync.isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(sync.isSyncing ? 'Syncing with Cloud...' : 'Push & Pull Cloud Sync Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent Offline Sync Logs',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_logs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No offline operations queued yet.', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            )
          else
            ..._logs.map((row) {
              final synced = (row['synced_at'] as String? ?? '').isNotEmpty;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    synced ? Icons.check_circle : Icons.schedule,
                    color: synced ? AppTheme.success : AppTheme.warning,
                  ),
                  title: Text(
                    row['uuid'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Captured: ${row['captured_at']}\nStatus: ${synced ? "Synced (${row['synced_at']})" : "Pending Upload"}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }
}
