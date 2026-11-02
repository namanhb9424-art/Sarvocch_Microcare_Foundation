import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pregrt_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pregrt_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class PreGrtScreen extends StatefulWidget {
  const PreGrtScreen({super.key});

  @override
  State<PreGrtScreen> createState() => _PreGrtScreenState();
}

class _PreGrtScreenState extends State<PreGrtScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PreGrtProvider>().fetchPreGrts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pregrtProv = context.watch<PreGrtProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final groups = pregrtProv.preGrts;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Pre-GRT (Group Recognition Test)'),
      drawer: const CustomDrawer(currentRoute: '/pregrt'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.tealPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text('New Pre-GRT Group'),
        onPressed: () => _showNewGroupDialog(context),
      ),
      body: pregrtProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? const Center(child: Text('No Pre-GRT groups recorded yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final grp = groups[index];
                    return _buildGroupCard(grp, user?.role ?? '');
                  },
                ),
    );
  }

  Widget _buildGroupCard(PreGrtModel grp, String userRole) {
    Color statusColor;
    switch (grp.status) {
      case 'verified':
        statusColor = AppTheme.success;
        break;
      case 'submitted':
        statusColor = Colors.orange;
        break;
      case 'returned':
        statusColor = AppTheme.danger;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: grp.id == 1,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.tealSurface,
          child: const Icon(Icons.people, color: AppTheme.tealPrimary),
        ),
        title: Row(
          children: [
            Text(
              'Center ${grp.centerNo} • Group ${grp.groupNo}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                grp.status.toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${grp.village}, ${grp.district} • Branch: ${grp.branch}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Field PSO: ${grp.psoName} (${grp.psoEmpid})',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text('Date: ${grp.formDate}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                if (grp.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Notes: ${grp.notes}', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 12),
                const Text(
                  'GROUP MEMBERS & CGT DISCIPLINE CHECK',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),

                // Members List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: grp.members.length,
                  itemBuilder: (context, mIdx) {
                    final m = grp.members[mIdx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${m.sno}. ${m.name} (w/o ${m.husbandName})',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                '₹${m.loanAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.tealPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Age: ${m.age} • Voter: ${m.voterId} • Purpose: ${m.purpose}',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                m.allCgtPassed ? Icons.check_circle : Icons.warning,
                                size: 14,
                                color: m.allCgtPassed ? AppTheme.success : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                m.allCgtPassed ? 'All 7 CGT Discipline Points Passed' : 'Partial CGT Verification',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: m.allCgtPassed ? AppTheme.success : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Manager / Admin Verification Actions
                if ((userRole == 'admin' || userRole == 'manager') && grp.status == 'submitted') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Verify & Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tealPrimary),
                          onPressed: () => _handleReview(grp.id, 'verified'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.replay, size: 18, color: AppTheme.danger),
                          label: const Text('Return to PSO', style: TextStyle(color: AppTheme.danger)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
                          onPressed: () => _handleReview(grp.id, 'returned'),
                        ),
                      ),
                    ],
                  ),
                ],

                if (grp.status == 'verified')
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: AppTheme.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Verified by ${grp.verifiedBy ?? "Branch Manager"} on ${grp.verifiedOn ?? grp.formDate}',
                            style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
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

  void _handleReview(int grpId, String status) {
    final remarksCtrl = TextEditingController(text: status == 'verified' ? 'Group discipline verified, ready for application' : 'Correction required in member 4 voter ID');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'verified' ? 'Verify Pre-GRT Group' : 'Return Group to Field Officer'),
        content: TextField(
          controller: remarksCtrl,
          decoration: const InputDecoration(labelText: 'Review Remarks *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await context.read<PreGrtProvider>().reviewPreGrt(
                    pregrtId: grpId,
                    status: status,
                    reviewRemarks: remarksCtrl.text.trim(),
                    verifiedBy: auth.currentUser?.name ?? 'Branch Manager',
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(status == 'verified' ? 'Confirm Verify' : 'Return'),
          ),
        ],
      ),
    );
  }

  void _showNewGroupDialog(BuildContext context) {
    final villageCtrl = TextEditingController(text: 'Palasia');
    final centerCtrl = TextEditingController(text: 'C-202');
    final groupCtrl = TextEditingController(text: 'G-C');
    final notesCtrl = TextEditingController(text: '5 members organized for tailoring & trade');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Pre-GRT Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: villageCtrl, decoration: const InputDecoration(labelText: 'Village / Ward *')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: centerCtrl, decoration: const InputDecoration(labelText: 'Center No *'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: groupCtrl, decoration: const InputDecoration(labelText: 'Group Code *'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Group Formation Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final user = auth.currentUser;
              await context.read<PreGrtProvider>().createPreGrt(
                branch: user?.branch ?? 'Indore - Vijay Nagar',
                centerNo: centerCtrl.text.trim(),
                groupNo: groupCtrl.text.trim(),
                village: villageCtrl.text.trim(),
                district: 'Indore',
                psoName: user?.name ?? 'Ravi Field Officer',
                psoEmpid: 'E-1004',
                bmName: 'Meera Manager',
                bmEmpid: 'E-1002',
                notes: notesCtrl.text.trim(),
                agentId: user?.id ?? 4,
                members: [
                  {'name': 'Shashi Bala', 'husband_name': 'Ram Babu', 'age': 34, 'voter_id': 'MPV112233', 'loan_amount': 25000.0, 'purpose': 'Handloom'},
                  {'name': 'Radha Bai', 'husband_name': 'Sanjay', 'age': 37, 'voter_id': 'MPV112234', 'loan_amount': 25000.0, 'purpose': 'Pottery'},
                  {'name': 'Urmila Devi', 'husband_name': 'Kishan', 'age': 40, 'voter_id': 'MPV112235', 'loan_amount': 25000.0, 'purpose': 'Grocery'},
                ],
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
  }
}
