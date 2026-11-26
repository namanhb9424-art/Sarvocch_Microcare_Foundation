import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/sync_service.dart';
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
  final currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final db = await DatabaseHelper.instance.database;
    final user = context.read<AuthProvider>().currentUser;
    final branchData = user == null
        ? null
        : await db.transaction<List<Map<String, dynamic>>?>((txn) async {
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
            final assignedBranch = (actors.first['branch'] as String? ?? '')
                .trim();
            if (!{'admin', 'manager'}.contains(role) ||
                (role == 'manager' && assignedBranch.isEmpty)) {
              return null;
            }

            final branchRows = await txn.query(
              'branches',
              where: role == 'admin' ? null : 'name = ?',
              whereArgs: role == 'admin' ? null : [assignedBranch],
              orderBy: 'id ASC',
            );
            final enhanced = <Map<String, dynamic>>[];
            for (final branch in branchRows) {
              final name = branch['name'] as String;
              final staffCount =
                  (await txn.rawQuery(
                        'SELECT COUNT(*) as c FROM employees WHERE branch = ? AND status != ?',
                        [name, 'exited'],
                      )).first['c']
                      as int? ??
                  0;
              final customerCount =
                  (await txn.rawQuery(
                        'SELECT COUNT(*) as c FROM customers WHERE branch = ?',
                        [name],
                      )).first['c']
                      as int? ??
                  0;
              final activeLoans =
                  (await txn.rawQuery(
                        'SELECT COUNT(*) as c FROM loans WHERE branch = ? AND status = ?',
                        [name, 'active'],
                      )).first['c']
                      as int? ??
                  0;
              final disbursedMinor =
                  (await txn.rawQuery(
                        '''
                SELECT COALESCE(SUM(COALESCE(
                  principal_paise, CAST(ROUND(principal * 100) AS INTEGER)
                )), 0) AS amount_paise
                FROM loans WHERE branch = ?
                ''',
                        [name],
                      )).first['amount_paise']
                      as num? ??
                  0;
              final overdueCount =
                  (await txn.rawQuery(
                        '''
                SELECT COUNT(DISTINCT l.id) as c
                FROM schedule s
                JOIN loans l ON l.id = s.loan_id
                WHERE s.paid = 0 AND s.due_date < date('now') AND l.branch = ?
              ''',
                        [name],
                      )).first['c']
                      as int? ??
                  0;

              enhanced.add({
                ...branch,
                'staff_count': staffCount,
                'customer_count': customerCount,
                'active_loans': activeLoans,
                'total_disbursed': disbursedMinor.toDouble() / 100,
                'overdue_loans': overdueCount,
              });
            }
            return enhanced;
          });

    if (mounted) {
      setState(() {
        _branches = branchData ?? [];
        _loading = false;
      });
    }
  }

  void _showAddBranchDialog() {
    if (context.read<AuthProvider>().currentUser?.role != 'admin') return;
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final headCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final radiusCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Add New Branch Office',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Name (e.g. Bhopal - MP Nagar) *',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Branch Code (BHO-02)',
                      ),
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
                decoration: const InputDecoration(
                  labelText: 'Branch Head Manager Name',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'GPS Latitude',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'GPS Longitude',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: radiusCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Geofence Punch Radius (Meters)',
                  hintText: '2000',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final loc = await LocationService.instance.getCurrentCoordinates();
                    if (loc.isRealGps && loc.latitude != null && loc.longitude != null) {
                      latCtrl.text = loc.latitude!.toStringAsFixed(6);
                      lngCtrl.text = loc.longitude!.toStringAsFixed(6);
                      if (radiusCtrl.text.trim().isEmpty) radiusCtrl.text = '2000';
                    } else if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(loc.errorMessage ?? 'GPS unavailable')),
                      );
                    }
                  },
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Use Current GPS Coordinates'),
                ),
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
              if (nameCtrl.text.trim().isEmpty) return;
              final latitude = double.tryParse(latCtrl.text.trim());
              final longitude = double.tryParse(lngCtrl.text.trim());
              final hasCoordinates = latitude != null && longitude != null;
              final radius = int.tryParse(radiusCtrl.text.trim()) ?? 0;
              final enteredCoordinates =
                  latCtrl.text.trim().isNotEmpty ||
                  lngCtrl.text.trim().isNotEmpty;
              if ((enteredCoordinates &&
                      (!hasCoordinates ||
                          latitude < -90 ||
                          latitude > 90 ||
                          longitude < -180 ||
                          longitude > 180 ||
                          radius < 50 ||
                          radius > 10000)) ||
                  (hasCoordinates && (radius < 50 || radius > 10000))) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter valid GPS coordinates and a radius between 50 and 10,000 meters, or leave all geofence fields blank.',
                    ),
                  ),
                );
                return;
              }
              final user = context.read<AuthProvider>().currentUser;
              if (user == null) return;
              try {
                final db = await DatabaseHelper.instance.database;
                final nowIso = DateTime.now().toIso8601String().substring(
                  0,
                  19,
                );
                await db.transaction((txn) async {
                  final actors = await txn.query(
                    'users',
                    columns: ['name', 'role', 'auth_status'],
                    where: 'id = ?',
                    whereArgs: [user.id],
                    limit: 1,
                  );
                  if (actors.isEmpty ||
                      actors.first['auth_status'] != 'active' ||
                      actors.first['role'] != 'admin') {
                    throw StateError(
                      'Only an active administrator can add branches.',
                    );
                  }
                  final branchId = await txn.insert('branches', {
                    'name': nameCtrl.text.trim(),
                    'code': codeCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'head_name': headCtrl.text.trim(),
                    'lat': hasCoordinates ? latitude : null,
                    'lng': hasCoordinates ? longitude : null,
                    'radius_m': radius > 0 ? radius : 0,
                    'active': 1,
                  });
                  await txn.insert('audit_log', {
                    'operation_id': const Uuid().v4(),
                    'entity_type': 'branch',
                    'entity_id': branchId,
                    'action': 'branch_created',
                    'actor_user_id': user.id,
                    'actor_role': actors.first['role'],
                    'actor_name': actors.first['name'],
                    'occurred_at': nowIso,
                    'details': jsonEncode({
                      'name': nameCtrl.text.trim(),
                      'code': codeCtrl.text.trim(),
                      'geofence_configured': hasCoordinates,
                    }),
                  });
                });
                await SyncService().enqueueAction(
                  userId: user.id,
                  action: 'branch_created',
                  operationId: 'branch_${nameCtrl.text.trim()}_${DateTime.now().millisecondsSinceEpoch}',
                  payload: {
                    'name': nameCtrl.text.trim(),
                    'code': codeCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'head_name': headCtrl.text.trim(),
                    'lat': hasCoordinates ? latitude : null,
                    'lng': hasCoordinates ? longitude : null,
                    'radius_m': radius > 0 ? radius : 2000,
                  },
                );
                SyncService().triggerFullSync(userId: user.id);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadBranches();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Branch was not saved. Check permissions and whether the branch name is already in use.',
                      ),
                    ),
                  );
                }
              }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  child: const Icon(
                    Icons.business,
                    color: AppTheme.tealPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Code: ${b['code']} • Branch Head: ${b['head_name'] ?? "Not Assigned"}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'BRANCH PORTFOLIO & STATS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    'Active Staff',
                    '${b['staff_count']}',
                    Icons.badge_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    'Borrowers',
                    '${b['customer_count']}',
                    Icons.people_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    'Active Loans',
                    '${b['active_loans']}',
                    Icons.monetization_on_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    'Overdue',
                    '${b['overdue_loans']}',
                    Icons.warning_amber_outlined,
                    isDanger: (b['overdue_loans'] as int) > 0,
                  ),
                ),
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
                  Text(
                    'Disbursed Portfolio: ${currency.format(b['total_disbursed'])}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.tealPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Address: ${b['address']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GPS: ${b['lat']}, ${b['lng']} (Radius: ${b['radius_m']}m)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statBox(
    String label,
    String value,
    IconData icon, {
    bool isDanger = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDanger ? AppTheme.dangerLight : AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDanger ? AppTheme.danger : AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDanger ? AppTheme.danger : AppTheme.tealPrimary,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDanger ? AppTheme.danger : AppTheme.textPrimary,
                ),
              ),
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
      floatingActionButton:
          context.watch<AuthProvider>().currentUser?.role == 'admin'
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.tealPrimary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_business),
              label: const Text('Add Branch'),
              onPressed: _showAddBranchDialog,
            )
          : null,
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
                      child: const Icon(
                        Icons.account_balance,
                        color: AppTheme.tealPrimary,
                      ),
                    ),
                    title: Text(
                      b['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${b['address']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Staff: ${b['staff_count']}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Active Loans: ${b['active_loans']}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.tealPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            if ((b['overdue_loans'] as int) > 0)
                              Text(
                                'Overdue: ${b['overdue_loans']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.danger,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondary,
                    ),
                    onTap: () => _showBranchDetailsSheet(b),
                  ),
                );
              },
            ),
    );
  }
}
