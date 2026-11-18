import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/loan_model.dart';

import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/currency_amount.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanProv = context.watch<LoanProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final loans = loanProv.loans.where((loan) {
      if (user == null) return false;
      if (user.role == 'admin') return true;
      if (user.role == 'field_agent') return loan.agentId == user.id;
      if (user.role == 'customer') return loan.customerId == user.customerId;
      return loan.branch == user.branch;
    }).toList();
    final totalDisbursedPaise = loans.fold<int>(
      0,
      (sum, loan) => sum + loan.principalPaise,
    );
    final activeLoans = loans.where((loan) => loan.status == 'active').toList();
    final totalOutstandingPaise = activeLoans.fold<int>(
      0,
      (sum, loan) => sum + loan.outstandingPaise,
    );
    final overdueCount = loans.where((loan) => loan.hasOverdue).length;
    final branchPortfolio = <String, List<LoanModel>>{};
    for (final loan in loans) {
      branchPortfolio.putIfAbsent(loan.branch, () => []).add(loan);
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Portfolio & Analytics (रिपोर्ट्स)'),
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
                Tab(
                  icon: Icon(Icons.pie_chart_outline, size: 20),
                  text: 'PAR & Aging',
                ),
                Tab(
                  icon: Icon(Icons.business_outlined, size: 20),
                  text: 'Branch Performance',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: PAR & Aging
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Summary Row
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              'Active Borrowers',
                              '${activeLoans.length}',
                              Icons.groups,
                              AppTheme.tealPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              'Loans with overdue',
                              '$overdueCount',
                              Icons.warning_amber,
                              AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              'Total Disbursed',
                              currency.format(
                                CurrencyAmount.fromMinorUnits(
                                  totalDisbursedPaise,
                                ),
                              ),
                              Icons.payments,
                              Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              'Gross Portfolio (GLP)',
                              currency.format(
                                CurrencyAmount.fromMinorUnits(
                                  totalOutstandingPaise,
                                ),
                              ),
                              Icons.account_balance,
                              AppTheme.navyDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // PAR Distribution Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Portfolio aging',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Aging and collection efficiency reports are unavailable until approved calculation rules are configured.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _kpiCard(
                                'Loans with overdue installments',
                                '$overdueCount',
                                Icons.schedule,
                                AppTheme.warning,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab 2: Branch Performance
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Regional Operating Performance',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...branchPortfolio.entries.map((entry) {
                        final branchName = entry.key;
                        final branchLoans = entry.value;
                        final branchGLPPaise = branchLoans.fold<int>(
                          0,
                          (acc, l) => acc + l.principalPaise,
                        );
                        final branchOutstandingPaise = branchLoans
                            .where((loan) => loan.status == 'active')
                            .fold<int>(
                              0,
                              (sum, loan) => sum + loan.outstandingPaise,
                            );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      branchName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.tealSurface,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${branchLoans.length} Loans',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppTheme.tealDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Disbursed principal:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      currency.format(
                                        CurrencyAmount.fromMinorUnits(
                                          branchGLPPaise,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Active outstanding:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      currency.format(
                                        CurrencyAmount.fromMinorUnits(
                                          branchOutstandingPaise,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        color: AppTheme.tealPrimary,
                                      ),
                                    ),
                                  ],
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

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 4),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
