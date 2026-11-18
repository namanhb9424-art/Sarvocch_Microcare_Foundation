import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';
import 'crm_detail_screen.dart';

class CrmListScreen extends StatefulWidget {
  const CrmListScreen({super.key});

  @override
  State<CrmListScreen> createState() => _CrmListScreenState();
}

class _CrmListScreenState extends State<CrmListScreen> {
  String _selectedStage = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final customerProv = context.watch<CustomerProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final allCustomers = customerProv.customers.where((customer) {
      if (user == null) return false;
      if (user.role == 'admin') return true;
      if (user.role == 'field_agent') return customer.agentId == user.id;
      return customer.branch == user.branch;
    }).toList();

    final filtered = allCustomers.where((c) {
      final matchesStage =
          _selectedStage == 'all' || c.stage.toLowerCase() == _selectedStage;
      final matchesSearch =
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.phone.contains(_searchQuery) ||
              c.branch.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStage && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: const CustomAppBar(title: 'CRM / Customer Directory'),
      drawer: const CustomDrawer(currentRoute: '/crm'),
      floatingActionButton:
          {'admin', 'manager', 'field_agent'}.contains(user?.role)
              ? FloatingActionButton.extended(
                  backgroundColor: AppTheme.tealPrimary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.person_add),
                  label: const Text('New Customer'),
                  onPressed: () => _showAddCustomerDialog(context),
                )
              : null,
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search by customer name, phone, branch...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStageChip('All', 'all', allCustomers.length),
                      const SizedBox(width: 8),
                      _buildStageChip(
                          'Customers',
                          'customer',
                          allCustomers
                              .where((c) => c.stage == 'customer')
                              .length),
                      const SizedBox(width: 8),
                      _buildStageChip(
                          'Prospects',
                          'prospect',
                          allCustomers
                              .where((c) => c.stage == 'prospect')
                              .length),
                      const SizedBox(width: 8),
                      _buildStageChip('Leads', 'lead',
                          allCustomers.where((c) => c.stage == 'lead').length),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // Customer List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No customers found in this stage',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CrmDetailScreen(customer: c)),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: c.kycStatus == 'verified'
                                      ? AppTheme.tealSurface
                                      : Colors.grey.shade100,
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0] : 'C',
                                    style: TextStyle(
                                      color: c.kycStatus == 'verified'
                                          ? AppTheme.tealPrimary
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            c.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _stageColor(c.stage)
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              c.stage.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _stageColor(c.stage),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Phone: ${c.phone} • ${c.branch}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            c.kycStatus == 'verified'
                                                ? Icons.verified
                                                : Icons.pending_actions,
                                            size: 14,
                                            color: c.kycStatus == 'verified'
                                                ? AppTheme.success
                                                : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            c.kycStatus == 'verified'
                                                ? 'KYC Verified'
                                                : 'KYC Pending',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: c.kycStatus == 'verified'
                                                  ? AppTheme.success
                                                  : Colors.orange,
                                            ),
                                          ),
                                          if (c.waVerified == 1) ...[
                                            const SizedBox(width: 10),
                                            const Icon(Icons.check_circle,
                                                size: 14, color: Colors.green),
                                            const SizedBox(width: 3),
                                            const Text(
                                              'WhatsApp OK',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageChip(String label, String stage, int count) {
    final isSelected = _selectedStage == stage;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppTheme.tealSurface,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.tealPrimary : AppTheme.textSecondary,
      ),
      side: BorderSide(
          color: isSelected ? AppTheme.tealPrimary : AppTheme.border),
      onSelected: (_) => setState(() => _selectedStage = stage),
    );
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'customer':
        return AppTheme.success;
      case 'prospect':
        return AppTheme.info;
      case 'lead':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final branchCtrl =
        TextEditingController(text: user.role == 'admin' ? '' : user.branch);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer Lead',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Customer Full Name *')),
              const SizedBox(height: 12),
              TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Mobile Number *')),
              const SizedBox(height: 12),
              TextField(
                  controller: addressCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Village / Address *')),
              const SizedBox(height: 12),
              TextField(
                controller: branchCtrl,
                enabled: user.role == 'admin',
                decoration: const InputDecoration(labelText: 'Branch *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final createdId =
                  await context.read<CustomerProvider>().createCustomer(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        branch: branchCtrl.text.trim(),
                        actorUserId: user.id,
                      );
              if (createdId != null && ctx.mounted) Navigator.pop(ctx);
              if (createdId == null && ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Customer was not saved. Check required details, phone number and branch access.')),
                );
              }
            },
            child: const Text('Save Lead'),
          ),
        ],
      ),
    );
  }
}
