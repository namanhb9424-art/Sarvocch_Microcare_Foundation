import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _selectedBranch = '';
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      if (user.branch.isNotEmpty) {
        _selectedBranch = user.branch;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AttendanceProvider>().fetchAttendanceData(user.id);
      });
    }
  }

  Future<void> _handlePunchIn() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _isLocating = true);

    final locResult = await LocationService.instance.getCurrentCoordinates();

    if (!mounted) return;
    setState(() {
      _isLocating = false;
    });

    if (locResult.errorMessage != null ||
        !locResult.isRealGps ||
        locResult.latitude == null ||
        locResult.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locResult.errorMessage ??
              'Live GPS is required. Attendance was not recorded.'),
          backgroundColor: Colors.blueGrey,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final result = await context.read<AttendanceProvider>().punchIn(
          userId: user.id,
          branchName: _selectedBranch,
          currentLat: locResult.latitude!,
          currentLng: locResult.longitude!,
        );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Punch-in recorded (${result['distance'] ?? 0}m from branch, limit ${result['radius_m'] ?? 2000}m).',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      final dist = result['distance'];
      final lim = result['radius_m'];
      final baseErr =
          result['error'] as String? ?? 'Punch-in could not be recorded.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dist != null && lim != null
                ? '$baseErr (${dist}m away, allowed ${lim}m)'
                : baseErr,
          ),
          backgroundColor: Colors.orange.shade800,
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
          content:
              Text('Punch-Out recorded successfully. Have a good evening!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _showRequestModal() {
    final reasonCtrl = TextEditingController();
    final inCtrl = TextEditingController();
    final outCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attendance Correction Request',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A branch manager or administrator must review this correction.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: inCtrl,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                              labelText: 'Punch In', hintText: 'HH:MM'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: outCtrl,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                              labelText: 'Punch Out', hintText: 'HH:MM'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Reason for manual request *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final user = auth.currentUser;
              if (user == null || reasonCtrl.text.trim().isEmpty) return;
              final todayStr =
                  DateTime.now().toIso8601String().substring(0, 10);

              final submitted =
                  await context.read<AttendanceProvider>().submitRequest(
                        actorUserId: user.id,
                        day: todayStr,
                        inTime: inCtrl.text,
                        outTime: outCtrl.text,
                        reason: reasonCtrl.text.trim(),
                      );

              if (submitted && ctx.mounted) Navigator.pop(ctx);
              if (mounted && submitted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Attendance correction request submitted for review.'),
                ));
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Attendance correction request was not saved.'),
                ));
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(int requestId, String decision) async {
    final remarksCtrl = TextEditingController();
    final remarks = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(decision == 'approved'
            ? 'Approve correction'
            : 'Reject correction'),
        content: TextField(
          controller: remarksCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Review remarks *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, remarksCtrl.text.trim()),
            child: const Text('Record review'),
          ),
        ],
      ),
    );
    remarksCtrl.dispose();
    if (remarks == null || remarks.isEmpty || !mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final saved = await context.read<AttendanceProvider>().decideRequest(
          requestId: requestId,
          decision: decision,
          actorUserId: user.id,
          remarks: remarks,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'Review recorded.' : 'Review was not recorded.'),
        backgroundColor: saved ? AppTheme.success : AppTheme.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attProv = context.watch<AttendanceProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final today = attProv.todayRecord;
    final availableBranches = attProv.branches;
    var activeBranchName = _selectedBranch;
    if ((activeBranchName.isEmpty ||
            !availableBranches.any((b) => b.name == activeBranchName)) &&
        availableBranches.isNotEmpty) {
      final userMatch = availableBranches.where((b) => b.name == user?.branch);
      activeBranchName = userMatch.isNotEmpty
          ? userMatch.first.name
          : availableBranches.first.name;
      if (_selectedBranch != activeBranchName) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedBranch = activeBranchName);
        });
      }
    }
    final branchRows =
        availableBranches.where((branch) => branch.name == activeBranchName);
    final branch = branchRows.isEmpty ? null : branchRows.first;
    final geofenceConfigured = branch?.lat != null &&
        branch?.lng != null &&
        (branch?.radiusM ?? 0) > 0;

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
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: today?.inTime != null
                                ? AppTheme.successLight
                                : AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            today?.inTime != null
                                ? 'Punched In'
                                : 'Not Punched Today',
                            style: TextStyle(
                              color: today?.inTime != null
                                  ? AppTheme.success
                                  : AppTheme.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Branch & Geofence GPS
                    if (user?.role == 'admin' && availableBranches.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: availableBranches.any((b) => b.name == activeBranchName)
                            ? activeBranchName
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Assigned Branch for Punch-In',
                          prefixIcon: Icon(Icons.business_outlined, size: 18),
                          isDense: true,
                        ),
                        items: availableBranches.map((b) {
                          final geoOk = b.lat != null && b.lng != null && b.radiusM > 0;
                          return DropdownMenuItem(
                            value: b.name,
                            child: Text(
                              '${b.name} (${geoOk ? '${b.radiusM}m' : 'No GPS'})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBranch = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: geofenceConfigured
                              ? AppTheme.tealPrimary
                              : Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Branch: ${activeBranchName.isEmpty ? 'Not assigned' : activeBranchName}\nGeofence: ${geofenceConfigured ? '${branch!.radiusM}m (${branch.lat!.toStringAsFixed(4)}, ${branch.lng!.toStringAsFixed(4)})' : 'Not configured'}',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!geofenceConfigured && user?.role == 'admin')
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/branches'),
                            child: const Text('Configure'),
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
                              const Text('Punch In Time:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                              Text(
                                today!.inTime!.length > 16
                                    ? today.inTime!.substring(11, 16)
                                    : today.inTime!,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.tealPrimary),
                              ),
                            ],
                          ),
                          if (today.outTime != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Punch Out Time:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary)),
                                Text(
                                  today.outTime!.length > 16
                                      ? today.outTime!.substring(11, 16)
                                      : today.outTime!,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.tealPrimary),
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
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.touch_app, size: 18),
                            label: Text(
                                _isLocating ? 'Acquiring GPS...' : 'Punch In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (today?.inTime != null || _isLocating)
                                      ? Colors.grey
                                      : AppTheme.tealPrimary,
                            ),
                            onPressed: (today?.inTime != null ||
                                    _isLocating ||
                                    !geofenceConfigured)
                                ? null
                                : _handlePunchIn,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.door_back_door_outlined,
                                size: 18),
                            label: const Text('Punch Out'),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: AppTheme.tealPrimary),
                            ),
                            onPressed:
                                today?.inTime == null || today?.outTime != null
                                    ? null
                                    : _handlePunchOut,
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
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attProv.requests.length,
                itemBuilder: (context, index) {
                  final req = attProv.requests[index];
                  final isPending = req.status == 'pending';
                  final canDecide =
                      (user?.role == 'admin' || user?.role == 'manager');

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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPending
                                      ? Colors.orange.withOpacity(0.15)
                                      : AppTheme.successLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  req.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isPending
                                        ? Colors.orange.shade800
                                        : AppTheme.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Requested Hours: ${req.inTime} - ${req.outTime}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Reason: ${req.reason}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          if (isPending && canDecide) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _showReviewDialog(req.id, 'rejected'),
                                  child: const Text('Reject',
                                      style: TextStyle(
                                          color: AppTheme.danger,
                                          fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () =>
                                      _showReviewDialog(req.id, 'approved'),
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
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8),
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
                    leading: const Icon(Icons.check_circle,
                        color: AppTheme.success, size: 20),
                    title: Text(r.day,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                      'In: ${r.inTime != null && r.inTime!.length > 16 ? r.inTime!.substring(11, 16) : (r.inTime ?? "--:--")} | Out: ${r.outTime != null && r.outTime!.length > 16 ? r.outTime!.substring(11, 16) : (r.outTime ?? "--:--")}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                    trailing: const Text('Present',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.tealPrimary)),
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
