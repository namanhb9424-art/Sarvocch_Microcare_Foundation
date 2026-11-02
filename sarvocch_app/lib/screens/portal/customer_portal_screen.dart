import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/loan_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class CustomerPortalScreen extends StatefulWidget {
  const CustomerPortalScreen({super.key});

  @override
  State<CustomerPortalScreen> createState() => _CustomerPortalScreenState();
}

class _CustomerPortalScreenState extends State<CustomerPortalScreen> {
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final loanProv = context.watch<LoanProvider>();

    // Loans belonging to customer (Sunita Verma id=1)
    final custLoans = loanProv.loans.where((l) => l.customerId == (user?.customerId ?? 1)).toList();
    final activeLoan = custLoans.where((l) => l.status == 'active').firstOrNull;

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
                      style: const TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Namaste, ${user?.name ?? "Sunita Verma"}',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A/C: SMF-CUST-00${user?.customerId ?? 1} • ${user?.branch ?? "Indore"}',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
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
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.tealPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.warningLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Due Soon', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 11)),
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
                              Text(currency.format(activeLoan.emi),
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.tealPrimary)),
                              Text('Due Date: ${activeLoan.nextDueDate ?? "2026-11-05"}',
                                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                            ],
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text('Pay via UPI'),
                            onPressed: () => _showQuickUpiPay(activeLoan),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('AutoPay eNACH: Active (SBIN)', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                          Text('Balance: ${currency.format(activeLoan.outstanding)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: l.status == 'active' ? AppTheme.tealSurface : AppTheme.successLight,
                      child: Icon(
                        l.status == 'active' ? Icons.account_balance_wallet : Icons.check_circle,
                        color: l.status == 'active' ? AppTheme.tealPrimary : AppTheme.success,
                      ),
                    ),
                    title: Text(
                      '${l.productName ?? "Micro Business Loan"} (#LN-${l.id})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    subtitle: Text(
                      'Sanctioned: ${currency.format(l.principal)} • Paid: ${l.paidCount}/${l.totalCount} EMIs',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: l.status == 'closed'
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              side: const BorderSide(color: AppTheme.success),
                            ),
                            onPressed: () => _showNocDialog(l),
                            child: const Text('NOC PDF', style: TextStyle(color: AppTheme.success, fontSize: 11)),
                          )
                        : const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onTap: () => Navigator.pushNamed(context, '/loans'),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // Quick Calculator Shortcut
            Card(
              color: AppTheme.background,
              child: ListTile(
                leading: const Icon(Icons.calculate_outlined, color: AppTheme.tealPrimary),
                title: const Text('EMI Calculator', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Plan new loan instalments and interest rates', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.tealPrimary),
                onTap: () => Navigator.pushNamed(context, '/calculator'),
              ),
            ),
          ],
        ),
      ),
    ), // end Scaffold
    ); // end PopScope
  }

  void _showQuickUpiPay(LoanModel loan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quick 1-Click UPI Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 12),
              QrImageView(
                data: 'upi://pay?pa=sarvocch.microcare@icici&pn=Sarvocch&am=${loan.emi}&cu=INR',
                version: QrVersions.auto,
                size: 160.0,
                foregroundColor: AppTheme.tealPrimary,
              ),
              const SizedBox(height: 12),
              Text(
                'Instant Pay ${currency.format(loan.emi)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.tealPrimary),
              ),
              const SizedBox(height: 4),
              const Text('Scan using any UPI App (GPay, PhonePe, Paytm, BHIM)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Payment of ${currency.format(loan.emi)} confirmed! EMI updated.'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  },
                  child: const Text('Simulate Successful UPI Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            const Icon(Icons.verified, color: AppTheme.success, size: 48),
            const SizedBox(height: 12),
            Text('Loan Account #LN-${loan.id} has been fully settled and closed.'),
            const SizedBox(height: 6),
            const Text(
              'Certificate No: SMF-NOC-2026-0941\nAuthorized signatory: SARVOOCCH Microcare Foundation',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download NOC'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('NOC PDF certificate downloaded to device!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
