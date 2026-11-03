import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan_product_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class ApplyLoanScreen extends StatefulWidget {
  const ApplyLoanScreen({super.key});

  @override
  State<ApplyLoanScreen> createState() => _ApplyLoanScreenState();
}

class _ApplyLoanScreenState extends State<ApplyLoanScreen> {
  int? _selectedCustomerId;
  int _selectedProductId = 1;
  double _loanAmount = 40000.0;
  int _tenure = 12;
  final _purposeCtrl = TextEditingController(text: 'Small business expansion & stock purchase');
  final _occupationCtrl = TextEditingController(text: 'Tailoring & Garments');

  // Income Breakdown
  final _incomeBusinessCtrl = TextEditingController(text: '24000');
  final _incomeJobCtrl = TextEditingController(text: '0');
  final _incomeOtherCtrl = TextEditingController(text: '6000');

  // Expense Breakdown
  final _expBasicCtrl = TextEditingController(text: '9000');
  final _expEducationCtrl = TextEditingController(text: '2000');
  final _expFestivalCtrl = TextEditingController(text: '1500');
  final _expHealthCtrl = TextEditingController(text: '1000');
  final _expOtherCtrl = TextEditingController(text: '1500');

  final List<String> _selectedDocs = ['aadhaar', 'voter'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final argCustomerId = ModalRoute.of(context)?.settings.arguments as int?;
      final customers = context.read<CustomerProvider>().customers;
      if (argCustomerId != null) {
        final exists = customers.any((c) => c.id == argCustomerId);
        if (exists && mounted) {
          setState(() => _selectedCustomerId = argCustomerId);
          return;
        }
      }
      if (customers.isNotEmpty && mounted) {
        setState(() => _selectedCustomerId = customers.first.id);
      }
    });
  }

  double get _totalIncome {
    final b = double.tryParse(_incomeBusinessCtrl.text) ?? 0.0;
    final j = double.tryParse(_incomeJobCtrl.text) ?? 0.0;
    final o = double.tryParse(_incomeOtherCtrl.text) ?? 0.0;
    return b + j + o;
  }

  double get _totalExpense {
    final b = double.tryParse(_expBasicCtrl.text) ?? 0.0;
    final e = double.tryParse(_expEducationCtrl.text) ?? 0.0;
    final f = double.tryParse(_expFestivalCtrl.text) ?? 0.0;
    final h = double.tryParse(_expHealthCtrl.text) ?? 0.0;
    final o = double.tryParse(_expOtherCtrl.text) ?? 0.0;
    return b + e + f + h + o;
  }

  LoanProductModel? _selectedProduct(List<LoanProductModel> products) {
    try {
      return products.firstWhere((p) => p.id == _selectedProductId);
    } catch (_) {
      return products.isNotEmpty ? products.first : null;
    }
  }

  double _calcEmi(List<LoanProductModel> products) {
    final prod = _selectedProduct(products);
    final rate = prod?.rate ?? 18.0;
    final method = prod?.method ?? 'reducing';
    if (method == 'flat') {
      return double.parse(((_loanAmount + (_loanAmount * rate / 100 * _tenure / 12)) / _tenure).toStringAsFixed(2));
    } else {
      final r = rate / 1200;
      final emi = _loanAmount * r * pow(1 + r, _tenure) / (pow(1 + r, _tenure) - 1);
      return double.parse(emi.toStringAsFixed(2));
    }
  }

  double _emiRatio(List<LoanProductModel> products) {
    if (_totalIncome <= 0) return 0.0;
    return (_calcEmi(products) / _totalIncome) * 100;
  }

  Future<void> _submitApplication() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an applicant')));
      return;
    }

    if (_selectedDocs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least 2 documents must be deposited')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final appId = await context.read<LoanProvider>().submitNewLoanApplication(
          customerId: _selectedCustomerId!,
          productId: _selectedProductId,
          amount: _loanAmount,
          tenure: _tenure,
          purpose: _purposeCtrl.text.trim(),
          income: _totalIncome,
          occupation: _occupationCtrl.text.trim(),
          agentId: user?.id ?? 4,
          branch: user?.branch ?? 'Indore - Vijay Nagar',
          incBusiness: double.tryParse(_incomeBusinessCtrl.text) ?? 0,
          incJob: double.tryParse(_incomeJobCtrl.text) ?? 0,
          incOther: double.tryParse(_incomeOtherCtrl.text) ?? 0,
          expBasic: double.tryParse(_expBasicCtrl.text) ?? 0,
          expEducation: double.tryParse(_expEducationCtrl.text) ?? 0,
          expFestival: double.tryParse(_expFestivalCtrl.text) ?? 0,
          expHealth: double.tryParse(_expHealthCtrl.text) ?? 0,
          expOther: double.tryParse(_expOtherCtrl.text) ?? 0,
          docsDeposited: _selectedDocs,
        );

    if (!mounted) return;

    if (appId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application #APP-$appId submitted successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;
    final loanProv = context.watch<LoanProvider>();
    final products = loanProv.products;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final currentEmi = _calcEmi(products);
    final currentEmiRatio = _emiRatio(products);
    final isHighRisk = currentEmiRatio > 60.0;

    return Scaffold(
      appBar: const CustomAppBar(title: 'New Loan Application'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. APPLICANT DETAILS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _selectedCustomerId,
                      decoration: const InputDecoration(labelText: 'Customer *'),
                      items: customers.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.name} (${c.phone}) - ${c.stage.toUpperCase()}'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCustomerId = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _occupationCtrl,
                      decoration: const InputDecoration(labelText: 'Occupation / Business Type *'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Product & Loan Terms
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('2. LOAN PRODUCT & AMOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _selectedProductId,
                      decoration: const InputDecoration(labelText: 'Loan Product *'),
                      items: products.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} (${p.rate}% ${p.method})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedProductId = val!),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Requested Principal Amount:'),
                        Text(currency.format(_loanAmount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.tealPrimary)),
                      ],
                    ),
                    Slider(
                      value: _loanAmount,
                      min: 10000,
                      max: 100000,
                      divisions: 18,
                      activeColor: AppTheme.tealPrimary,
                      onChanged: (val) => setState(() => _loanAmount = val),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tenure (Months):'),
                        Text('$_tenure Months', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.tealPrimary)),
                      ],
                    ),
                    Slider(
                      value: _tenure.toDouble(),
                      min: 6,
                      max: 24,
                      divisions: 18,
                      activeColor: AppTheme.tealPrimary,
                      onChanged: (val) => setState(() => _tenure = val.toInt()),
                    ),
                    TextField(
                      controller: _purposeCtrl,
                      decoration: const InputDecoration(labelText: 'Loan Purpose *'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Risk Assessment & EMI Calculation Card
            Card(
              color: isHighRisk ? AppTheme.dangerLight : AppTheme.tealSurface.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isHighRisk ? Icons.warning : Icons.speed, color: isHighRisk ? AppTheme.danger : AppTheme.tealPrimary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'REAL-TIME RISK & CASHFLOW CHECK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isHighRisk ? AppTheme.danger : AppTheme.tealPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Monthly EMI:'),
                        Text(currency.format(currentEmi), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Monthly Household Income:'),
                        Text(currency.format(_totalIncome), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Monthly Household Expenses:'),
                        Text(currency.format(_totalExpense), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('EMI / Income Ratio:'),
                        Text(
                          '${currentEmiRatio.toStringAsFixed(1)}% (Max 60% rule)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isHighRisk ? AppTheme.danger : AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                    if (isHighRisk) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'WARNING: EMI exceeds 60% of verified household income. Underwriter approval required with justification.',
                        style: TextStyle(color: AppTheme.danger, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Deposited Documents Check
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('3. DEPOSITED DOCUMENTS (Min. 2 Required)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    _buildDocCheck('aadhaar', 'Aadhaar Card (आधार कार्ड)'),
                    _buildDocCheck('voter', 'Voter ID Card (मतदाता पहचान पत्र)'),
                    _buildDocCheck('pan', 'PAN Card (पैन कार्ड)'),
                    _buildDocCheck('passbook', 'Bank Passbook / Cancelled Cheque'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitApplication,
                child: const Text('Submit Loan Application', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCheck(String key, String label) {
    final isChecked = _selectedDocs.contains(key);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: isChecked,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            _selectedDocs.add(key);
          } else {
            _selectedDocs.remove(key);
          }
        });
      },
    );
  }
}
