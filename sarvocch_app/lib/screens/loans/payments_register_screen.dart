import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/currency_amount.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/kpi_card.dart';

class PaymentsRegisterScreen extends StatefulWidget {
  const PaymentsRegisterScreen({super.key});

  @override
  State<PaymentsRegisterScreen> createState() => _PaymentsRegisterScreenState();
}

class _PaymentsRegisterScreenState extends State<PaymentsRegisterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _dueLoans = [];
  List<Map<String, dynamic>> _recentPayments = [];
  double _todayCollection = 0.0;
  bool _loading = true;
  final currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final isAdmin = user.role == 'admin';
      final isAgent = user.role == 'field_agent';
      final isCust = user.role == 'customer';

      final branchClause = isAdmin
          ? ''
          : isCust
              ? 'AND l.customer_id = ?'
              : isAgent
                  ? 'AND l.branch = ?'
                  : 'AND l.branch = ?';
      final args = isAdmin
          ? <Object?>[]
          : isCust
              ? <Object?>[user.customerId ?? -1]
              : <Object?>[user.branch];

      final dueRows = await db.rawQuery('''
        SELECT l.id, l.emi, l.emi_paise, l.branch, c.name as customer_name, c.phone,
               (SELECT id FROM schedule s WHERE s.loan_id = l.id AND s.paid = 0 ORDER BY s.no ASC LIMIT 1) as next_sched_id,
               (SELECT no FROM schedule s WHERE s.loan_id = l.id AND s.paid = 0 ORDER BY s.no ASC LIMIT 1) as next_no,
               (SELECT due_date FROM schedule s WHERE s.loan_id = l.id AND s.paid = 0 ORDER BY s.no ASC LIMIT 1) as next_due
        FROM loans l
        JOIN customers c ON l.customer_id = c.id
        WHERE l.status = 'active' $branchClause
        ORDER BY next_due ASC
        LIMIT 50
      ''', args);

      final payRows = await db.rawQuery('''
        SELECT p.*, l.branch, c.name as customer_name, c.phone, pr.name as product_name
        FROM payments p
        JOIN loans l ON p.loan_id = l.id
        JOIN customers c ON l.customer_id = c.id
        LEFT JOIN products pr ON l.product_id = pr.id
        WHERE 1=1 $branchClause
        ORDER BY p.id DESC
        LIMIT 100
      ''', args);

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final todayRows = await db.rawQuery('''
        SELECT COALESCE(SUM(COALESCE(p.amount_paise, CAST(ROUND(p.amount * 100) AS INTEGER))), 0) as total_paise
        FROM payments p
        JOIN loans l ON p.loan_id = l.id
        WHERE substr(p.at, 1, 10) = ? $branchClause
      ''', [today, ...args]);

      if (mounted) {
        setState(() {
          _dueLoans = dueRows.map(Map<String, dynamic>.from).toList();
          _recentPayments = payRows.map(Map<String, dynamic>.from).toList();
          _todayCollection = CurrencyAmount.fromMinorUnits(
            (todayRows.first['total_paise'] as num?)?.toInt() ?? 0,
          );
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _collectEmiModal(Map<String, dynamic> dueLoan) {
    final schedId = dueLoan['next_sched_id'] as int?;
    if (schedId == null) return;
    final emi = CurrencyAmount.readStoredValue(dueLoan, 'emi_paise', 'emi');
    String channel = 'cash';

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
                Text(
                  'Collect EMI • #SMF-LN-${dueLoan['id']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dueLoan['customer_name']} • Installment #${dueLoan['next_no']} (${dueLoan['next_due'] ?? ''})',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount Due:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      currency.format(emi),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.tealPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Cash in Field'),
                      selected: channel == 'cash',
                      onSelected: (_) => setModalState(() => channel = 'cash'),
                    ),
                    ChoiceChip(
                      label: const Text('UPI / BharatQR'),
                      selected: channel == 'upi',
                      onSelected: (_) => setModalState(() => channel = 'upi'),
                    ),
                    ChoiceChip(
                      label: const Text('NEFT / Bank'),
                      selected: channel == 'neft',
                      onSelected: (_) => setModalState(() => channel = 'neft'),
                    ),
                    ChoiceChip(
                      label: const Text('eNACH'),
                      selected: channel == 'enach',
                      onSelected: (_) => setModalState(() => channel = 'enach'),
                    ),
                  ],
                ),
                if (channel == 'upi') ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Column(
                      children: [
                        QrImageView(
                          data:
                              'upi://pay?pa=sarvoocch@icici&pn=SARVOOCCH+Microcare&am=${emi.toStringAsFixed(2)}&cu=INR&tn=LN${dueLoan['id']}',
                          version: QrVersions.auto,
                          size: 130.0,
                          foregroundColor: AppTheme.tealPrimary,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Scan with GPay, PhonePe or Paytm',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
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
                      final actorId = context.read<AuthProvider>().currentUser?.id ?? 0;
                      final ok = await context.read<LoanProvider>().payInstallment(
                            loanId: dueLoan['id'] as int,
                            scheduleId: schedId,
                            amount: emi,
                            channel: channel,
                            actorUserId: actorId,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (ok) {
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment of ${currency.format(emi)} recorded via ${channel.toUpperCase()} & queued for cloud sync!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment could not be recorded for this role/branch.'),
                            backgroundColor: AppTheme.danger,
                          ),
                        );
                      }
                    },
                    child: Text('Confirm ${currency.format(emi)} Payment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt(Map<String, dynamic> payment) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final amount = CurrencyAmount.readStoredValue(payment, 'amount_paise', 'amount');
    final bytes = await PdfService.generateCollectionRecord(
      data: {
        'reference': payment['ref'],
        'recorded_at': payment['at'],
        'customer_name': payment['customer_name'],
        'loan_id': payment['loan_id'],
        'branch': payment['branch'],
        'product_name': payment['product_name'] ?? 'Microfinance Loan',
        'installment': payment['schedule_id'] != null ? '#${payment['schedule_id']}' : 'Direct',
        'channel': (payment['channel'] as String? ?? 'CASH').toUpperCase(),
        'amount': amount,
      },
    );
    await PdfService.printOrShareDocument(
      title: 'Receipt_${payment['ref']}',
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return Scaffold(
      appBar: const CustomAppBar(title: 'Repayments & Collection Register'),
      drawer: const CustomDrawer(currentRoute: '/payments'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: KpiCard(
                    title: "Today's Collection",
                    value: currency.format(_todayCollection),
                    icon: Icons.payments_outlined,
                    iconColor: AppTheme.success,
                    subtitle: 'All channels',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KpiCard(
                    title: 'Due Installments',
                    value: '${_dueLoans.length}',
                    icon: Icons.schedule,
                    iconColor: AppTheme.warning,
                    subtitle: '${_recentPayments.length} receipts logged',
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.tealPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.tealPrimary,
              tabs: [
                Tab(text: 'Due for Collection (${_dueLoans.length})'),
                Tab(text: 'Recent Receipts (${_recentPayments.length})'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Due Installments
                      RefreshIndicator(
                        onRefresh: _loadData,
                        child: _dueLoans.isEmpty
                            ? const Center(child: Text('No pending installments due.'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _dueLoans.length,
                                itemBuilder: (context, idx) {
                                  final dl = _dueLoans[idx];
                                  final emi = CurrencyAmount.readStoredValue(dl, 'emi_paise', 'emi');
                                  final nextDue = dl['next_due'] as String? ?? '';
                                  final overdue = nextDue.isNotEmpty && nextDue.compareTo(todayStr) < 0;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              dl['customer_name'] as String? ?? '-',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          Text(
                                            currency.format(emi),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.tealPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '#SMF-LN-${dl['id']} • Due: $nextDue ${overdue ? "(OVERDUE)" : ""}\n${dl['branch']} • ${dl['phone'] ?? ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: overdue ? AppTheme.danger : AppTheme.textSecondary,
                                        ),
                                      ),
                                      isThreeLine: true,
                                      trailing: ElevatedButton(
                                        onPressed: () => _collectEmiModal(dl),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.success,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                        ),
                                        child: const Text('Collect', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Tab 2: Recent Receipts
                      RefreshIndicator(
                        onRefresh: _loadData,
                        child: _recentPayments.isEmpty
                            ? const Center(child: Text('No payment receipts logged yet.'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _recentPayments.length,
                                itemBuilder: (context, idx) {
                                  final p = _recentPayments[idx];
                                  final amt = CurrencyAmount.readStoredValue(p, 'amount_paise', 'amount');
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '#${p['ref'] ?? p['id']}',
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.tealPrimary),
                                            ),
                                          ),
                                          Text(
                                            currency.format(amt),
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.success),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${p['customer_name']} • #SMF-LN-${p['loan_id']}\n${(p['channel'] ?? 'CASH').toString().toUpperCase()} • ${p['at'] ?? ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      isThreeLine: true,
                                      trailing: IconButton(
                                        icon: const Icon(Icons.print_outlined, color: AppTheme.tealPrimary),
                                        tooltip: 'Print Receipt PDF',
                                        onPressed: () => _printReceipt(p),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
