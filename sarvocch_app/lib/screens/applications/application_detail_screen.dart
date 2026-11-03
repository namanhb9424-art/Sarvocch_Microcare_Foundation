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
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
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
    final logs = await context.read<LoanProvider>().getApprovalTimeline(_app.id);
    if (mounted) {
      setState(() {
        _timeline = logs;
        _loadingTimeline = false;
      });
    }
  }

  Future<void> _advanceStageDialog(String targetStage) async {
    final amountCtrl = TextEditingController(text: _app.amount.toStringAsFixed(0));
    final remarksCtrl = TextEditingController();

    String title;
    switch (targetStage) {
      case 'under_review':
        title = 'Move to Under Review';
        remarksCtrl.text = 'KYC, bureau score, and address verified';
        break;
      case 'approved':
        title = 'Approve Application (Adjust Sanction Amount)';
        remarksCtrl.text = 'Approved within borrower repaying capacity';
        break;
      case 'sanctioned':
        title = 'Issue Sanction Letter';
        remarksCtrl.text = 'Sanction approved & eNACH mandate recorded';
        break;
      case 'disbursed':
        title = 'Disburse Loan to Bank Account';
        remarksCtrl.text = 'Transferred via IMPS/NEFT to borrower SBI account';
        break;
      case 'rejected':
        title = 'Reject Application';
        remarksCtrl.text = 'Failed bureau checks or debt capacity limit';
        break;
      default:
        title = 'Advance Application';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                    helperText: 'Approver may reduce amount as per repayment limit',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Approval Remarks / Reason *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final user = auth.currentUser;
              final newAmt = double.tryParse(amountCtrl.text) ?? _app.amount;

              await context.read<LoanProvider>().advanceApplication(
                    applicationId: _app.id,
                    targetStage: targetStage,
                    byUser: user?.name ?? 'Branch Manager',
                    byRole: user?.role ?? 'manager',
                    sanctionedAmount: newAmt,
                    remarks: remarksCtrl.text.trim(),
                  );

              if (ctx.mounted) Navigator.pop(ctx);

              // Update local state
              final updated = context.read<LoanProvider>().applications.firstWhere((a) => a.id == _app.id);
              setState(() => _app = updated);
              _loadTimeline();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Application #APP-${_app.id} moved to ${targetStage.toUpperCase()}'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
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
                  const Text('Sanction Letter & Digital QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 10),
              QrImageView(
                data: 'https://sarvocch.demo/applications/${_app.id}/sanction.pdf',
                version: QrVersions.auto,
                size: 160.0,
                foregroundColor: AppTheme.tealPrimary,
              ),
              const SizedBox(height: 14),
              Text(
                'SANCTION ID: SMF-SANCTION-${_app.id}-2026',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.tealPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Sanctioned Amount: ${currency.format(_app.amount)} for ${_app.customerName}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share Digital Sanction Letter'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sanction Letter link copied to clipboard')),
                    );
                  },
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
              tooltip: 'Sanction QR',
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
                            Text(_app.customerName ?? 'Applicant',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                            const SizedBox(height: 2),
                            Text('Phone: ${_app.customerPhone ?? "N/A"} • ${_app.branch}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        _buildStat('Sanction Amount', currency.format(_app.amount)),
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
                    const Text('FINANCIAL CASHFLOW & CAPACITY',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    _detailRow('Occupation', _app.occupation),
                    _detailRow('Purpose', _app.purpose),
                    _detailRow('Verified Household Income', currency.format(_app.incomeTotal ?? _app.income)),
                    _detailRow('Monthly Household Expenses', currency.format(_app.expenseTotal ?? 15000)),
                    _detailRow('Estimated Net Monthly Savings', currency.format(_app.netSaving ?? 15000)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Approval Chain Timeline
            const Text(
              'APPROVAL CHAIN & AUDIT LOG',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
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
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(log.stage, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          subtitle: Text(
                            'By ${log.byUser} (${log.byRole.toUpperCase()})\n${log.remarks.isNotEmpty ? log.remarks : "Standard workflow advancement"}',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                          trailing: Text(
                            log.at.length > 10 ? log.at.substring(0, 10) : log.at,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
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

    final canApprove = (role == 'admin' || role == 'manager' || role == 'underwriter');
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
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
                onPressed: () => _advanceStageDialog('rejected'),
                child: const Text('Reject', style: TextStyle(color: AppTheme.danger)),
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
                label: const Text('Disburse Funds to Borrower'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
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
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.tealPrimary)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
