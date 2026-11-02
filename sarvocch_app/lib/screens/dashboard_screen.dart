import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/loan_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/kpi_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoanProvider>().fetchAll();
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loan = context.watch<LoanProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you want to exit SARVOOCCH Microcare?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: const CustomAppBar(title: 'SARVOOCCH Microcare Portal'),
      drawer: const CustomDrawer(currentRoute: '/dashboard'),
      body: RefreshIndicator(
        onRefresh: () => loan.fetchAll(),
        color: AppTheme.tealPrimary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.tealPrimary, AppTheme.tealDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.tealPrimary.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user?.name ?? "Officer"}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Role: ${user?.roleDisplay ?? ""} • Branch: ${user?.branch ?? "Head Office"}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // KPI Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.35,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  KpiCard(
                    title: 'Total Disbursed',
                    value: currencyFormat.format(loan.totalDisbursed),
                    icon: Icons.account_balance_wallet,
                    iconColor: AppTheme.tealPrimary,
                    subtitle: '${loan.loans.length} Total Loans',
                    subtitleColor: AppTheme.tealDark,
                    onTap: () => Navigator.pushNamed(context, '/loans'),
                  ),
                  KpiCard(
                    title: 'Outstanding Bal',
                    value: currencyFormat.format(loan.totalOutstanding),
                    icon: Icons.trending_up,
                    iconColor: AppTheme.info,
                    subtitle: '${loan.activeLoansCount} Active Borrowers',
                    subtitleColor: AppTheme.info,
                    onTap: () => Navigator.pushNamed(context, '/loans'),
                  ),
                  KpiCard(
                    title: 'Overdue Amount',
                    value: currencyFormat.format(loan.totalOverdue),
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppTheme.danger,
                    subtitle: '${loan.overdueLoansCount} Loan In Default',
                    subtitleColor: AppTheme.danger,
                    onTap: () => Navigator.pushNamed(context, '/loans'),
                  ),
                  KpiCard(
                    title: 'Recovery Rate',
                    value: '${loan.recoveryRate}%',
                    icon: Icons.check_circle_outline,
                    iconColor: AppTheme.success,
                    subtitle: 'Collection Efficiency',
                    subtitleColor: AppTheme.success,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Quick Action Bar
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildActionButton(
                      label: 'New Customer (KYC)',
                      icon: Icons.badge_outlined,
                      color: AppTheme.tealPrimary,
                      onTap: () => Navigator.pushNamed(context, '/kyc-form'),
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      label: 'Pre-GRT Group',
                      icon: Icons.groups_outlined,
                      color: Colors.indigo,
                      onTap: () => Navigator.pushNamed(context, '/pregrt'),
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      label: 'Apply Loan',
                      icon: Icons.note_add_outlined,
                      color: Colors.teal.shade700,
                      onTap: () => Navigator.pushNamed(context, '/apply'),
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      label: 'Punch Attendance',
                      icon: Icons.access_time_outlined,
                      color: Colors.orange.shade800,
                      onTap: () => Navigator.pushNamed(context, '/attendance'),
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      label: 'Cloud DB Sync',
                      icon: Icons.cloud_sync_outlined,
                      color: Colors.purple.shade700,
                      onTap: () => Navigator.pushNamed(context, '/cloud-quotes'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Interactive Chart: Branch Portfolio
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Branch Portfolio Distribution',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Icon(Icons.pie_chart_outline, size: 20, color: AppTheme.tealPrimary),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Active disbursements across regional micro-branches',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 36,
                                  sections: [
                                    PieChartSectionData(
                                      value: 86000,
                                      title: '56%',
                                      color: AppTheme.tealPrimary,
                                      radius: 40,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: 32000,
                                      title: '21%',
                                      color: AppTheme.tealLight,
                                      radius: 40,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: 20000,
                                      title: '13%',
                                      color: AppTheme.info,
                                      radius: 40,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: 15000,
                                      title: '10%',
                                      color: Colors.amber,
                                      radius: 40,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _LegendItem(color: AppTheme.tealPrimary, label: 'Indore - VN (₹86k)'),
                                  SizedBox(height: 6),
                                  _LegendItem(color: AppTheme.tealLight, label: 'Indore - PL (₹32k)'),
                                  SizedBox(height: 6),
                                  _LegendItem(color: AppTheme.info, label: 'Bhopal - MP (₹20k)'),
                                  SizedBox(height: 6),
                                  _LegendItem(color: Colors.amber, label: 'Pipariya (₹15k)'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Pipeline Applications
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PIPELINE APPLICATIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/applications'),
                    child: const Text('View All', style: TextStyle(color: AppTheme.tealPrimary, fontSize: 12)),
                  ),
                ],
              ),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: loan.applications.take(3).length,
                itemBuilder: (context, index) {
                  final app = loan.applications[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.tealSurface,
                        child: Text(
                          '#${app.id}',
                          style: const TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        app.customerName ?? 'Applicant',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${app.productName ?? "Loan"} • ${currencyFormat.format(app.amount)} (${app.tenure} mo)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(app.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          app.statusDisplay,
                          style: TextStyle(
                            color: _statusColor(app.status),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/applications'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ), // end Scaffold
    ); // end PopScope
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.orange;
      case 'under_review':
        return Colors.blue;
      case 'approved':
        return Colors.teal;
      case 'sanctioned':
        return Colors.indigo;
      case 'disbursed':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.danger;
      default:
        return Colors.grey;
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
