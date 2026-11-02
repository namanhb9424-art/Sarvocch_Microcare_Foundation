import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../models/pregrt_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class GroupApplyScreen extends StatefulWidget {
  final PreGrtModel group;

  const GroupApplyScreen({super.key, required this.group});

  @override
  State<GroupApplyScreen> createState() => _GroupApplyScreenState();
}

class _GroupApplyScreenState extends State<GroupApplyScreen> {
  int _selectedProductId = 1;
  int _tenure = 12;
  final List<String> _selectedDocs = ['aadhaar', 'voter'];
  bool _insuranceWanted = true;
  bool _declaration = true;
  late List<TextEditingController> _memberAmountCtrls;
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _memberAmountCtrls = widget.group.members.map((m) {
      return TextEditingController(text: m.loanAmount.toStringAsFixed(0));
    }).toList();
  }

  @override
  void dispose() {
    for (var ctrl in _memberAmountCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _submitBatchGroupApplication() async {
    if (_selectedDocs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 documents must be deposited for all members')),
      );
      return;
    }

    if (!_declaration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the group joint liability declaration')),
      );
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String().substring(0, 19);
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    int count = 0;

    for (int i = 0; i < widget.group.members.length; i++) {
      final m = widget.group.members[i];
      final amount = double.tryParse(_memberAmountCtrls[i].text) ?? m.loanAmount;

      // Find or assign customer_id
      int custId = m.customerId ?? (i + 1);

      final appId = await db.insert('applications', {
        'customer_id': custId,
        'product_id': _selectedProductId,
        'amount': amount,
        'tenure': _tenure,
        'rate': 18.0,
        'purpose': m.purpose.isNotEmpty ? m.purpose : 'Group business expansion',
        'income': m.annualIncome / 12,
        'occupation': 'Micro-business / Trade',
        'status': 'submitted',
        'agent_id': user?.id ?? 4,
        'branch': widget.group.branch,
        'created': nowIso,
        'docs': _selectedDocs.toString(),
      });

      await db.insert('app_extra', {
        'application_id': appId,
        'prev_loans': '[]',
        'insurance_wanted': _insuranceWanted ? 'yes' : 'no',
        'insurance_for': 'husband',
        'docs_deposited': _selectedDocs.toString(),
        'docs_other': '',
        'inc_agri': 0.0,
        'inc_business': m.annualIncome / 12,
        'inc_job': 0.0,
        'inc_other': 0.0,
        'exp_basic': 8000.0,
        'exp_education': 2000.0,
        'exp_festival': 1000.0,
        'exp_health': 1000.0,
        'exp_emi': 0.0,
        'exp_other': 1000.0,
        'group_rec': amount,
        'center_rec': amount,
        'loan_cycle': 1,
        'requested_amt': amount,
        'income_total': m.annualIncome / 12,
        'expense_total': 13000.0,
        'net_saving': (m.annualIncome / 12) - 13000.0,
        'declaration': 1,
      });

      await db.insert('approvals', {
        'application_id': appId,
        'stage': 'Submitted',
        'by_user': user?.name ?? 'Field PSO',
        'by_role': user?.role ?? 'field_agent',
        'amount': amount,
        'remarks': 'Pre-GRT verified group batch origination',
        'at': nowIso,
      });

      count++;
    }

    if (!mounted) return;

    // Refresh loan provider state
    await context.read<LoanProvider>().fetchAll();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully originated $count group loan applications!'),
        backgroundColor: AppTheme.success,
      ),
    );

    Navigator.pop(context);
    Navigator.pushNamed(context, '/applications');
  }

  @override
  Widget build(BuildContext context) {
    final loanProv = context.watch<LoanProvider>();
    final products = loanProv.products;

    return Scaffold(
      appBar: CustomAppBar(title: 'Group Loan: Center ${widget.group.centerNo} • Group ${widget.group.groupNo}'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppTheme.success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pre-GRT Group is VERIFIED by ${widget.group.verifiedBy ?? "Branch Manager"}. All members are eligible for batch origination.',
                      style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Product & Tenure Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. SELECT GROUP LOAN PRODUCT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedProductId,
                      decoration: const InputDecoration(labelText: 'Loan Scheme'),
                      items: products.map((p) {
                        return DropdownMenuItem<int>(
                          value: p.id,
                          child: Text('${p.name} (${p.rate}% ${p.method})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedProductId = val ?? 1),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _tenure,
                      decoration: const InputDecoration(labelText: 'Tenure (Months)'),
                      items: const [
                        DropdownMenuItem(value: 6, child: Text('6 Months')),
                        DropdownMenuItem(value: 12, child: Text('12 Months (Standard)')),
                        DropdownMenuItem(value: 18, child: Text('18 Months')),
                        DropdownMenuItem(value: 24, child: Text('24 Months')),
                      ],
                      onChanged: (val) => setState(() => _tenure = val ?? 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Member Loan Amounts
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('2. GROUP MEMBERS & APPLIED AMOUNTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.group.members.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final m = widget.group.members[i];
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.tealSurface,
                              child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.tealPrimary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text('w/o ${m.husbandName} • Age: ${m.age}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _memberAmountCtrls[i],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Principal (₹)',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Deposited Docs & Insurance
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('3. MANDATORY CHECKS (RBI JLG)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _insuranceWanted,
                      onChanged: (val) => setState(() => _insuranceWanted = val ?? true),
                      title: const Text('Credit Life Insurance included for all co-borrowers', style: TextStyle(fontSize: 12.5)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _declaration,
                      onChanged: (val) => setState(() => _declaration = val ?? true),
                      title: const Text('Group members mutual guarantee & discipline accepted', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: Text('Submit Batch Application (${widget.group.members.length} Members)'),
                onPressed: _submitBatchGroupApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
