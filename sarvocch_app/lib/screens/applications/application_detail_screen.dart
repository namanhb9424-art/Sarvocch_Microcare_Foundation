import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/application_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../theme/app_theme.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final ApplicationModel application;

  const ApplicationDetailScreen({super.key, required this.application});

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  final currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  List<ApprovalLogModel> _timeline = [];
  bool _loadingTimeline = true;
  late ApplicationModel _app;

  @override
  void initState() {
    super.initState();
    _app = widget.application;
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final logs = await context.read<LoanProvider>().getApprovalTimeline(
      _app.id,
      actorUserId: user.id,
    );
    if (mounted) {
      setState(() {
        _timeline = logs;
        _loadingTimeline = false;
      });
    }
  }

  Future<void> _advanceStageDialog(String targetStage) async {
    final amountCtrl = TextEditingController(
      text: _app.amount.toStringAsFixed(0),
    );
    final remarksCtrl = TextEditingController();
    final payoutReferenceCtrl = TextEditingController();
    var payoutChannel = '';

    String title;
    switch (targetStage) {
      case 'under_review':
        title = 'Move to Under Review';
        break;
      case 'approved':
        title = 'Approve Application (Adjust Sanction Amount)';
        break;
      case 'sanctioned':
        title = 'Record Sanction Decision';
        break;
      case 'disbursed':
        title = 'Record Loan Disbursement';
        break;
      case 'rejected':
        title = 'Reject Application';
        break;
      default:
        title = 'Advance Application';
    }

    final completed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (targetStage == 'approved') ...[
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sanctioned Amount (₹)',
                    helperText:
                        'Approver may reduce amount as per repayment limit',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (targetStage == 'disbursed') ...[
                const Text(
                  'Record the staff-confirmed payout. No bank or payment provider is connected.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                StatefulBuilder(
                  builder: (context, setDialogState) =>
                      DropdownButtonFormField<String>(
                        value: payoutChannel,
                        decoration: const InputDecoration(
                          labelText: 'Payout channel *',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('Select channel'),
                          ),
                          DropdownMenuItem(
                            value: 'bank_transfer',
                            child: Text('Bank transfer'),
                          ),
                          DropdownMenuItem(value: 'imps', child: Text('IMPS')),
                          DropdownMenuItem(value: 'neft', child: Text('NEFT')),
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => payoutChannel = value ?? ''),
                      ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: payoutReferenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Payout or receipt reference *',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Approval Remarks / Reason *',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final user = auth.currentUser;
              final newAmt = double.tryParse(amountCtrl.text) ?? _app.amount;

              final success = await context
                  .read<LoanProvider>()
                  .advanceApplication(
                    applicationId: _app.id,
                    targetStage: targetStage,
                    actorUserId: user?.id ?? 0,
                    sanctionedAmount: newAmt,
                    remarks: remarksCtrl.text.trim(),
                    disbursementReference: payoutReferenceCtrl.text.trim(),
                    disbursementChannel: payoutChannel,
                  );

              if (success && ctx.mounted) Navigator.pop(ctx, true);
              if (!success && ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Application update was not recorded. Check role, branch, KYC and transition requirements.',
                    ),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    amountCtrl.dispose();
    remarksCtrl.dispose();
    payoutReferenceCtrl.dispose();
    if (completed != true || !mounted) return;

    final updated = context.read<LoanProvider>().applications.where(
      (application) => application.id == _app.id,
    );
    if (updated.isEmpty) return;
    setState(() => _app = updated.first);
    await _loadTimeline();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Application #APP-${_app.id} moved to ${targetStage.toUpperCase()}',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _showSanctionLetter() {
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
                  const Text(
                    'Internal Application Reference',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 10),
              QrImageView(
                data: 'SARVOCCH-APPLICATION-${_app.id}',
                version: QrVersions.auto,
                size: 160.0,
                foregroundColor: AppTheme.tealPrimary,
              ),
              const SizedBox(height: 14),
              Text(
                'LOCAL APPLICATION ID: APP-${_app.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.tealPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recorded amount: ${currency.format(_app.amount)} for ${_app.customerName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This QR contains a local record identifier only. It is not a sanction letter or an externally verifiable approval.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final role = user?.role ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Application #APP-${_app.id}'),
        actions: [
          if (_app.status == 'sanctioned' || _app.status == 'disbursed')
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Local application reference',
              onPressed: _showSanctionLetter,
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(role),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Overview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _app.customerName ?? 'Applicant',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Phone: ${_app.customerPhone ?? "N/A"} • ${_app.branch}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(_app.status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _app.statusDisplay,
                            style: TextStyle(
                              color: _statusColor(_app.status),
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
                        _buildStat(
                          {'sanctioned', 'disbursed'}.contains(_app.status)
                              ? 'Sanctioned Amount'
                              : 'Requested Amount',
                          currency.format(_app.amount),
                        ),
                        _buildStat('Tenure', '${_app.tenure} Months'),
                        _buildStat('Interest Rate', '${_app.rate}% p.a.'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cash Flow & Risk Analysis
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FINANCIAL CASHFLOW & CAPACITY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _detailRow('Occupation', _app.occupation),
                    _detailRow('Purpose', _app.purpose),
                    _detailRow(
                      'Verified Household Income',
                      currency.format(_app.incomeTotal ?? _app.income),
                    ),
                    _detailRow(
                      'Monthly Household Expenses',
                      _app.expenseTotal == null
                          ? 'Not recorded'
                          : currency.format(_app.expenseTotal),
                    ),
                    _detailRow(
                      'Estimated Net Monthly Savings',
                      _app.netSaving == null
                          ? 'Not recorded'
                          : currency.format(_app.netSaving),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Approval Chain Timeline
            const Text(
              'APPROVAL CHAIN & AUDIT LOG',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            _loadingTimeline
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _timeline.length,
                    itemBuilder: (context, index) {
                      final log = _timeline[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.tealPrimary,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            log.stage,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          subtitle: Text(
                            'By ${log.byUser} (${log.byRole.toUpperCase()})\n${log.remarks.isNotEmpty ? log.remarks : "Standard workflow advancement"}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: Text(
                            log.at.length > 10
                                ? log.at.substring(0, 10)
                                : log.at,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
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

  Widget? _buildBottomActions(String role) {
    if (_app.status == 'disbursed' || _app.status == 'rejected') return null;

    final canApprove =
        (role == 'admin' || role == 'manager' || role == 'underwriter');
    final canDisburse = (role == 'admin' || role == 'manager');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (_app.status == 'submitted' && canApprove)
            Expanded(
              child: ElevatedButton(
                onPressed: () => _advanceStageDialog('under_review'),
                child: const Text('Move Under Review'),
              ),
            ),
          if (_app.status == 'under_review' && canApprove) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: () => _advanceStageDialog('approved'),
                child: const Text('Approve Application'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.danger),
                ),
                onPressed: () => _advanceStageDialog('rejected'),
                child: const Text(
                  'Reject',
                  style: TextStyle(color: AppTheme.danger),
                ),
              ),
            ),
          ],
          if (_app.status == 'approved' && canDisburse)
            Expanded(
              child: ElevatedButton(
                onPressed: () => _advanceStageDialog('sanctioned'),
                child: const Text('Sanction Loan'),
              ),
            ),
          if (_app.status == 'sanctioned' && canDisburse)
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Record Disbursement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
                onPressed: () => _advanceStageDialog('disbursed'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.tealPrimary,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
