import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/loan_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';
import 'loan_detail_screen.dart';

class LoansListScreen extends StatefulWidget {
  const LoansListScreen({super.key});

  @override
  State<LoansListScreen> createState() => _LoansListScreenState();
}

class _LoansListScreenState extends State<LoansListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanProv = context.watch<LoanProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final allLoans = loanProv.loans;

    // Data scoping: customers see only their own loans; field agents see only loans they manage
    final scopedLoans = () {
      if (user?.role == 'customer') {
        return allLoans.where((l) => l.customerId == user?.customerId).toList();
      } else if (user?.role == 'field_agent') {
        return allLoans.where((l) => l.agentId == user?.id).toList();
      }
      return allLoans;
    }();

    final activeLoans = scopedLoans.where((l) => l.status == 'active').toList();
    final overdueLoans = scopedLoans.where((l) => l.hasOverdue).toList();
    final closedLoans = scopedLoans.where((l) => l.status == 'closed').toList();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Loans & EMI Repayments'),
      drawer: const CustomDrawer(currentRoute: '/loans'),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.tealPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.tealPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(text: 'Active (${activeLoans.length})'),
                Tab(text: 'Overdue (${overdueLoans.length})'),
                Tab(text: 'Closed (${closedLoans.length})'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLoanList(activeLoans, 'No active loans'),
                _buildLoanList(overdueLoans, 'No overdue loans! Outstanding is on track.'),
                _buildLoanList(closedLoans, 'No closed loans'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanList(List<LoanModel> list, String emptyMsg) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 52, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(emptyMsg, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final loan = list[index];
        final progress = loan.totalCount > 0 ? (loan.paidCount / loan.totalCount) : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoanDetailScreen(loan: loan),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.tealSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#LN-${loan.id}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.tealPrimary, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            loan.customerName ?? 'Borrower',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ],
                      ),
                      if (loan.hasOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700, fontSize: 10),
                          ),
                        )
                      else if (loan.status == 'closed')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.successLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CLOSED',
                            style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Principal Loan', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text(currency.format(loan.principal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Monthly EMI', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text(currency.format(loan.emi), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.tealPrimary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Outstanding', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text(currency.format(loan.outstanding), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(loan.hasOverdue ? Colors.orange : AppTheme.tealPrimary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paid: ${loan.paidCount} of ${loan.totalCount} EMIs (${currency.format(loan.paidTotal)})',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                      if (loan.nextDueDate != null && loan.status == 'active')
                        Text(
                          'Next Due: ${loan.nextDueDate}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: loan.hasOverdue ? AppTheme.danger : AppTheme.tealPrimary,
                          ),
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
  }
}
