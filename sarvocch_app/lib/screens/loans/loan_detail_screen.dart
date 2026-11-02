import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/loan_model.dart';
import '../../providers/loan_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/document_viewer_sheet.dart';

class LoanDetailScreen extends StatefulWidget {
  final LoanModel loan;

  const LoanDetailScreen({super.key, required this.loan});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  List<ScheduleItemModel> _schedule = [];
  bool _loadingSchedule = true;
  late LoanModel _currentLoan;

  @override
  void initState() {
    super.initState();
    _currentLoan = widget.loan;
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final list = await context.read<LoanProvider>().getSchedule(_currentLoan.id);
    if (mounted) {
      setState(() {
        _schedule = list;
        _loadingSchedule = false;
      });
    }
  }

  void _showPayModal(ScheduleItemModel item) {
    String channel = 'upi';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pay Installment #${item.no}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Due Amount:', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    Text(
                      currency.format(item.emi),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.tealPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Due Date: ${item.dueDate}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),

                const Text('Select Payment Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('UPI / QR'),
                      selected: channel == 'upi',
                      onSelected: (_) => setModalState(() => channel = 'upi'),
                    ),
                    ChoiceChip(
                      label: const Text('Cash in Field'),
                      selected: channel == 'cash',
                      onSelected: (_) => setModalState(() => channel = 'cash'),
                    ),
                    ChoiceChip(
                      label: const Text('Debit Card'),
                      selected: channel == 'card',
                      onSelected: (_) => setModalState(() => channel = 'card'),
                    ),
                    ChoiceChip(
                      label: const Text('AutoPay eNACH'),
                      selected: channel == 'autopay',
                      onSelected: (_) => setModalState(() => channel = 'autopay'),
                    ),
                  ],
                ),

                if (channel == 'upi') ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Column(
                      children: [
                        QrImageView(
                          data: 'upi://pay?pa=sarvocch.microcare@icici&pn=Sarvocch&am=${item.emi}&cu=INR',
                          version: QrVersions.auto,
                          size: 130.0,
                          foregroundColor: AppTheme.tealPrimary,
                        ),
                        const SizedBox(height: 6),
                        const Text('Scan with GPay, PhonePe or Paytm', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () async {
                      final success = await context.read<LoanProvider>().payInstallment(
                            loanId: _currentLoan.id,
                            scheduleId: item.id,
                            amount: item.emi,
                            channel: channel,
                          );

                      if (ctx.mounted) Navigator.pop(ctx);

                      if (success) {
                        final updated = context.read<LoanProvider>().loans.firstWhere((l) => l.id == _currentLoan.id);
                        setState(() => _currentLoan = updated);
                        await _loadSchedule();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment of ${currency.format(item.emi)} recorded successfully via ${channel.toUpperCase()}!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      }
                    },
                    child: Text('Confirm ${currency.format(item.emi)} Payment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSettlementModal() async {
    final quote = await context.read<LoanProvider>().getSettlementQuote(_currentLoan.id);
    if (!mounted || quote == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Full Settlement Quotation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calculation as per RBI rules:\nPrincipal outstanding + next installment interest',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Principal Outstanding:'),
                Text(currency.format(quote['principal_outstanding']), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Next Month Interest:'),
                Text(currency.format(quote['next_interest']), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(color: AppTheme.border, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Settlement Payoff:', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  currency.format(quote['total_settlement']),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.tealPrimary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await context.read<LoanProvider>().settleLoanFull(_currentLoan.id, 'upi');
              if (ctx.mounted) Navigator.pop(ctx);
              final updated = context.read<LoanProvider>().loans.firstWhere((l) => l.id == _currentLoan.id);
              setState(() => _currentLoan = updated);
              await _loadSchedule();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loan settled in full! Closed successfully.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Confirm Payoff'),
          ),
        ],
      ),
    );
  }

  void _showLoanCardQr() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
                  const Text('Digital Loan Card & Passbook', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 12),
              QrImageView(
                data: 'https://sarvocch.demo/loans/${_currentLoan.id}/card',
                version: QrVersions.auto,
                size: 150.0,
                foregroundColor: AppTheme.tealPrimary,
              ),
              const SizedBox(height: 12),
              Text(
                'ACCOUNT: SMF-LN-00${_currentLoan.id}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.tealPrimary),
              ),
              Text(
                '${_currentLoan.customerName} • ${_currentLoan.branch}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Principal: ${currency.format(_currentLoan.principal)} • Monthly EMI: ${currency.format(_currentLoan.emi)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Loan #LN-${_currentLoan.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Loan Passbook',
            onPressed: () {
              DocumentViewerSheet.show(
                context,
                type: DocumentType.loanPassbook,
                data: {
                  'id': _currentLoan.id,
                  'customer_name': _currentLoan.customerName,
                  'product_name': _currentLoan.productName,
                  'principal': _currentLoan.principal,
                  'rate': _currentLoan.rate,
                  'method': _currentLoan.method,
                  'emi': _currentLoan.emi,
                  'start_date': _currentLoan.startDate,
                  'tenure': _currentLoan.tenure,
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Loan Card QR',
            onPressed: _showLoanCardQr,
          ),
          if (_currentLoan.status == 'active')
            IconButton(
              icon: const Icon(Icons.handshake_outlined),
              tooltip: 'Full Settlement',
              onPressed: _showSettlementModal,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Loan Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentLoan.customerName ?? 'Borrower',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                            Text(
                              '${_currentLoan.productName ?? "Loan"} • ${_currentLoan.branch}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _currentLoan.status == 'active' ? AppTheme.tealSurface : AppTheme.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentLoan.status.toUpperCase(),
                            style: TextStyle(
                              color: _currentLoan.status == 'active' ? AppTheme.tealPrimary : AppTheme.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Principal', currency.format(_currentLoan.principal)),
                        _buildStat('Monthly EMI', currency.format(_currentLoan.emi)),
                        _buildStat('Outstanding', currency.format(_currentLoan.outstanding)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Repayment Schedule Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'REPAYMENT SCHEDULE (EMI)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                ),
                Text(
                  'Paid ${_currentLoan.paidCount} / ${_currentLoan.totalCount}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.tealPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            _loadingSchedule
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _schedule.length,
                    itemBuilder: (context, index) {
                      final item = _schedule[index];
                      final isPaid = item.paid == 1;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isPaid ? AppTheme.successLight : AppTheme.tealSurface,
                            child: Icon(
                              isPaid ? Icons.check : Icons.schedule,
                              size: 16,
                              color: isPaid ? AppTheme.success : AppTheme.tealPrimary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text('EMI #${item.no} • ${item.dueDate}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              const SizedBox(width: 8),
                              if (isPaid)
                                const Text('(PAID)', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          subtitle: Text(
                            'Principal: ₹${item.principal.toStringAsFixed(0)} | Interest: ₹${item.interest.toStringAsFixed(0)} | Bal: ₹${item.balance.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                          trailing: isPaid
                              ? Text(
                                  currency.format(item.emi),
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 13),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _showPayModal(item),
                                  child: Text('Pay ${currency.format(item.emi)}'),
                                ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.tealPrimary)),
      ],
    );
  }
}
