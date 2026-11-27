import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/loan_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';
import '../loans/loan_detail_screen.dart';

class CustomerPortalScreen extends StatefulWidget {
  const CustomerPortalScreen({super.key});

  @override
  State<CustomerPortalScreen> createState() => _CustomerPortalScreenState();
}

class _CustomerPortalScreenState extends State<CustomerPortalScreen> {
  final currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<LoanProvider>().fetchCustomerLoans(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final loanProv = context.watch<LoanProvider>();

    final custLoans = user?.customerId == null
        ? <LoanModel>[]
        : loanProv.loans
              .where((loan) => loan.customerId == user!.customerId)
              .toList();
    final activeLoans = custLoans.where((loan) => loan.status == 'active');
    final activeLoan = activeLoans.isEmpty ? null : activeLoans.first;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you want to exit Sarvoocch Saathi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                ),
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
        appBar: const CustomAppBar(title: 'My Loan Portal (ग्राहक पोर्टल)'),
        drawer: const CustomDrawer(currentRoute: '/portal'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.tealPrimary, AppTheme.tealDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0] : 'S',
                        style: const TextStyle(
                          color: AppTheme.tealPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Namaste, ${user?.name ?? "Customer"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.customerId == null
                                ? 'Portal access is not linked to a customer record.'
                                : 'Customer ID: ${user!.customerId} • ${user.branch.isEmpty ? 'Branch not assigned' : user.branch}',
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

              // Active Loan Next EMI Card
              if (activeLoan != null) ...[
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'NEXT UPCOMING EMI DUE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.tealPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warningLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Due Soon',
                                style: TextStyle(
                                  color: AppTheme.warning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currency.format(activeLoan.emi),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.tealPrimary,
                                  ),
                                ),
                                Text(
                                  'Due Date: ${activeLoan.nextDueDate ?? "Not scheduled"}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('Pay EMI'),
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/payments'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: AppTheme.border, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AutoPay: Not configured',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Balance: ${currency.format(activeLoan.outstanding)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // All Borrower Loans
              const Text(
                'MY LOAN ACCOUNTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: custLoans.length,
                itemBuilder: (context, index) {
                  final l = custLoans[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: l.status == 'active'
                            ? AppTheme.tealSurface
                            : AppTheme.successLight,
                        child: Icon(
                          l.status == 'active'
                              ? Icons.account_balance_wallet
                              : Icons.check_circle,
                          color: l.status == 'active'
                              ? AppTheme.tealPrimary
                              : AppTheme.success,
                        ),
                      ),
                      title: Text(
                        '${l.productName ?? "Micro Business Loan"} (#LN-${l.id})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        'Sanctioned: ${currency.format(l.principal)} • Paid: ${l.paidCount}/${l.totalCount} EMIs',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      trailing: l.status == 'closed'
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                side: const BorderSide(color: AppTheme.success),
                              ),
                              onPressed: () => _showNocDialog(l),
                              child: const Text(
                                'NOC PDF',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.chevron_right,
                              color: AppTheme.textMuted,
                            ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoanDetailScreen(loan: l),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Quick Calculator Shortcut
              Card(
                color: AppTheme.background,
                child: ListTile(
                  leading: const Icon(
                    Icons.calculate_outlined,
                    color: AppTheme.tealPrimary,
                  ),
                  title: const Text(
                    'EMI Calculator',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Plan new loan instalments and interest rates',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.tealPrimary,
                  ),
                  onTap: () => Navigator.pushNamed(context, '/calculator'),
                ),
              ),
            ],
          ),
        ),
      ), // end Scaffold
    ); // end PopScope
  }

  void _showNocDialog(LoanModel loan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Objection Certificate (NOC)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_outlined, color: AppTheme.success, size: 44),
            const SizedBox(height: 12),
            Text(
              'Loan #LN-${loan.id} status: ${loan.status.toUpperCase()}.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'You can download your signed PDF NOC from the Web Portal (sarvocchfinance.com/portal) or request a stamped copy at your branch.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
