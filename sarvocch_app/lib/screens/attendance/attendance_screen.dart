import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // Demo coordinates around Indore Vijay Nagar branch (22.7533, 75.8937)
  double _mockLat = 22.7510;
  double _mockLng = 75.8900;
  String _selectedBranch = 'Indore - Vijay Nagar';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      context.read<AttendanceProvider>().fetchAttendanceData(user.id);
    }
  }

  Future<void> _handlePunchIn() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final result = await context.read<AttendanceProvider>().punchIn(
          userId: user.id,
          branchName: _selectedBranch,
          currentLat: _mockLat,
          currentLng: _mockLng,
        );

    if (!mounted) return;

    if (result['success'] == true) {
      final isWithin = result['within_radius'] as bool;
      final dist = result['distance'] as int;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isWithin
                ? 'Punch-In Successful! Distance: ${dist}m (Within ${result['radius_m']}m branch geofence)'
                : 'Warning: Punched from ${dist}m away from $_selectedBranch.',
          ),
          backgroundColor: isWithin ? AppTheme.success : Colors.orange,
        ),
      );
    }
  }

  Future<void> _handlePunchOut() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final success = await context.read<AttendanceProvider>().punchOut(user.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Punch-Out recorded successfully. Have a good evening!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _showRequestModal() {
    final reasonCtrl = TextEditingController(text: 'Forgot to punch, conducted center meeting in field');
    final inCtrl = TextEditingController(text: '09:30');
    final outCtrl = TextEditingController(text: '18:00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attendance Correction Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hierarchy: Staff -> Manager -> Admin approval',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: inCtrl, decoration: const InputDecoration(labelText: 'Punch In'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: outCtrl, decoration: const InputDecoration(labelText: 'Punch Out'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason for manual request *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final user = auth.currentUser;
              final todayStr = DateTime.now().toIso8601String().substring(0, 10);

              await context.read<AttendanceProvider>().submitRequest(
                    userId: user?.id ?? 4,
                    branch: user?.branch ?? 'Indore - Vijay Nagar',
                    day: todayStr,
                    inTime: inCtrl.text,
                    outTime: outCtrl.text,
                    reason: reasonCtrl.text.trim(),
                    approverRole: 'manager',
                    approverId: 2,
                  );

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attendance edit request sent to Branch Manager for approval')),
                );
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attProv = context.watch<AttendanceProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final today = attProv.todayRecord;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Geofenced Attendance & Punch'),
      drawer: const CustomDrawer(currentRoute: '/attendance'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.tealPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Request Edit'),
        onPressed: _showRequestModal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Punch Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TODAY\'S PUNCH-IN STATUS',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: today?.inTime != null ? AppTheme.successLight : AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            today?.inTime != null ? 'Punched In' : 'Not Punched Today',
                            style: TextStyle(
                              color: today?.inTime != null ? AppTheme.success : AppTheme.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Branch & Geofence GPS
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.tealPrimary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Branch: $_selectedBranch\nGeofence check: 2000m radius',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (today?.inTime != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Punch In Time:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              Text(
                                today!.inTime!.length > 16 ? today.inTime!.substring(11, 16) : today.inTime!,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.tealPrimary),
                              ),
                            ],
                          ),
                          if (today.outTime != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Punch Out Time:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                Text(
                                  today.outTime!.length > 16 ? today.outTime!.substring(11, 16) : today.outTime!,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.tealPrimary),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.touch_app, size: 18),
                            label: const Text('Punch In (2000m Check)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: today?.inTime != null ? Colors.grey : AppTheme.tealPrimary,
                            ),
                            onPressed: today?.inTime != null ? null : _handlePunchIn,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.door_back_door_outlined, size: 18),
                            label: const Text('Punch Out'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.tealPrimary),
                            ),
                            onPressed: today?.inTime == null || today?.outTime != null ? null : _handlePunchOut,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Attendance Correction Requests (Staff / Manager review)
            if (attProv.requests.isNotEmpty) ...[
              const Text(
                'ATTENDANCE CORRECTION REQUESTS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attProv.requests.length,
                itemBuilder: (context, index) {
                  final req = attProv.requests[index];
                  final isPending = req.status == 'pending';
                  final canDecide = (user?.role == 'admin' || user?.role == 'manager');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${req.userName ?? "Employee"} • Date: ${req.day}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPending ? Colors.orange.withOpacity(0.15) : AppTheme.successLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  req.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isPending ? Colors.orange.shade800 : AppTheme.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Requested Hours: ${req.inTime} - ${req.outTime}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Reason: ${req.reason}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          if (isPending && canDecide) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => context.read<AttendanceProvider>().decideRequest(
                                        requestId: req.id,
                                        decision: 'rejected',
                                        decidedBy: user?.name ?? 'Manager',
                                        remarks: 'Ineligible',
                                        userId: user?.id ?? 4,
                                      ),
                                  child: const Text('Reject', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => context.read<AttendanceProvider>().decideRequest(
                                        requestId: req.id,
                                        decision: 'approved',
                                        decidedBy: user?.name ?? 'Manager',
                                        remarks: 'Approved by Branch Manager',
                                        userId: user?.id ?? 4,
                                      ),
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
              ),
              const SizedBox(height: 20),
            ],

            // Monthly History
            const Text(
              'RECENT ATTENDANCE LOG',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attProv.records.take(5).length,
              itemBuilder: (context, index) {
                final r = attProv.records[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                    title: Text(r.day, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                      'In: ${r.inTime != null && r.inTime!.length > 16 ? r.inTime!.substring(11, 16) : (r.inTime ?? "--:--")} | Out: ${r.outTime != null && r.outTime!.length > 16 ? r.outTime!.substring(11, 16) : (r.outTime ?? "--:--")}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                    trailing: const Text('Present', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.tealPrimary)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
