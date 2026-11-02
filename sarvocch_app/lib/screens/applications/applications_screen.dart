import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/loan_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';
import 'application_detail_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<String> _stages = [
    'all',
    'submitted',
    'under_review',
    'approved',
    'sanctioned',
    'disbursed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stages.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanProv = context.watch<LoanProvider>();
    final allApps = loanProv.applications;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Loan Applications',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New Application',
            onPressed: () => Navigator.pushNamed(context, '/apply'),
          ),
        ],
      ),
      drawer: const CustomDrawer(currentRoute: '/applications'),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.tealPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.tealPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Submitted'),
                Tab(text: 'Under Review'),
                Tab(text: 'Approved'),
                Tab(text: 'Sanctioned'),
                Tab(text: 'Disbursed'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _stages.map((stage) {
                final filtered = stage == 'all'
                    ? allApps
                    : allApps.where((a) => a.status.toLowerCase() == stage).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 54, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No applications in ${stage.replaceAll("_", " ").toUpperCase()}',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApplicationDetailScreen(application: app),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '#APP-${app.id}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        app.customerName ?? 'Applicant',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    currencyFormat.format(app.amount),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.tealPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${app.productName ?? "Loan"} • ${app.tenure} Months',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1, color: AppTheme.border),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Monthly Savings: ₹${app.netSaving?.toStringAsFixed(0) ?? "15,000"}',
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.success, fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Branch: ${app.branch}',
                                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
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
