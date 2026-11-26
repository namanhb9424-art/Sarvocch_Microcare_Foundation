import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/grievance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class GrievancesScreen extends StatefulWidget {
  const GrievancesScreen({super.key});

  @override
  State<GrievancesScreen> createState() => _GrievancesScreenState();
}

class _GrievancesScreenState extends State<GrievancesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<GrievanceProvider>().fetchGrievances(actorUserId: user.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showNewGrievanceDialog() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final nameCtrl = TextEditingController(
      text: user.role == 'customer' ? user.name : '',
    );
    final phoneCtrl = TextEditingController(
      text: user.role == 'customer' ? user.phone : '',
    );
    final detailsCtrl = TextEditingController();
    String category = 'Receipt / Payment Discrepancy';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Customer Grievance (GRO)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Borrower Name *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Issue Category'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Receipt / Payment Discrepancy',
                      child: Text('Receipt / Payment Discrepancy'),
                    ),
                    DropdownMenuItem(
                      value: 'Interest / Fee Clarification',
                      child: Text('Interest / Fee Clarification'),
                    ),
                    DropdownMenuItem(
                      value: 'Field Staff Conduct / Fair Practices',
                      child: Text('Field Staff Conduct / Fair Practices'),
                    ),
                    DropdownMenuItem(
                      value: 'NOC / Loan Closure Delay',
                      child: Text('NOC / Loan Closure Delay'),
                    ),
                    DropdownMenuItem(
                      value: 'KYC / Privacy Query',
                      child: Text('KYC / Privacy Query'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Complaint Details *',
                    hintText: 'Describe the issue and relevant Loan/Receipt #',
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
                if (nameCtrl.text.trim().isEmpty ||
                    detailsCtrl.text.trim().isEmpty) {
                  return;
                }
                final ticket = await context.read<GrievanceProvider>().createGrievance(
                      actorUserId: user.id,
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      category: category,
                      details: detailsCtrl.text,
                      branch: user.branch,
                      customerId: user.customerId,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && ticket != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Grievance Ticket $ticket logged & queued for GRO!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text('Submit Ticket'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(Map<String, dynamic> g) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final notesCtrl = TextEditingController(
      text: g['resolution_notes'] as String? ?? '',
    );
    String nextStatus = (g['status'] as String? ?? 'open') == 'open'
        ? 'resolved'
        : (g['status'] as String? ?? 'resolved');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Update ${g['ticket_no']}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: nextStatus,
                decoration: const InputDecoration(labelText: 'Ticket Status'),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected / Closed')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => nextStatus = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'GRO Resolution Notes *',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await context.read<GrievanceProvider>().updateGrievance(
                      actorUserId: user.id,
                      id: g['id'] as int,
                      ticketNo: g['ticket_no'] as String,
                      status: nextStatus,
                      resolutionNotes: notesCtrl.text,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Grievance resolution updated & synced!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text('Save Decision'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final prov = context.watch<GrievanceProvider>();
    final all = prov.grievances;
    final canResolve =
        user != null && {'admin', 'manager', 'underwriter'}.contains(user.role);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Grievance Redressal (GRO)',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Log Grievance',
            onPressed: _showNewGrievanceDialog,
          ),
        ],
      ),
      drawer: const CustomDrawer(currentRoute: '/grievances'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewGrievanceDialog,
        backgroundColor: AppTheme.tealPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.support_agent),
        label: const Text('New Ticket'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFF0FDFA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: AppTheme.tealPrimary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GRO: Smt. Bandana Singh (CEO) · Helpline +91 91111 99101 · 48-Hr SLA',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.tealDark),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.tealPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.tealPrimary,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Open'),
                Tab(text: 'In Progress'),
                Tab(text: 'Resolved'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: ['all', 'open', 'in_progress', 'resolved'].map((stage) {
                final items = stage == 'all'
                    ? all
                    : all.where((g) => (g['status'] as String? ?? 'open') == stage).toList();
                if (prov.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text('No grievance tickets in this queue',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => prov.fetchGrievances(actorUserId: user?.id ?? 0),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final g = items[idx];
                      final st = g['status'] as String? ?? 'open';
                      final color = st == 'resolved'
                          ? AppTheme.success
                          : st == 'in_progress'
                              ? AppTheme.warning
                              : AppTheme.danger;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    g['ticket_no'] as String? ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.tealPrimary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      st.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${g['name']} • ${g['phone']}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${g['category']} • ${g['branch']}',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                g['details'] as String? ?? '',
                                style: const TextStyle(fontSize: 13),
                              ),
                              if ((g['resolution_notes'] as String? ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Resolution: ${g['resolution_notes']}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.success),
                                  ),
                                ),
                              ],
                              if (canResolve) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showResolveDialog(g),
                                    icon: const Icon(Icons.edit_note, size: 16),
                                    label: const Text('Update / Resolve'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
