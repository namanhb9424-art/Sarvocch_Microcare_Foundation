import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/customer_model.dart';
import '../../models/loan_product_model.dart';
import '../../models/user_model.dart';
import '../../services/currency_amount.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class ApplyLoanScreen extends StatefulWidget {
  const ApplyLoanScreen({super.key});

  @override
  State<ApplyLoanScreen> createState() => _ApplyLoanScreenState();
}

class _ApplyLoanScreenState extends State<ApplyLoanScreen> {
  int? _selectedCustomerId;
  int _selectedProductId = 0;
  final _amountCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _employerCtrl = TextEditingController();

  // Income Breakdown
  final _incomeAgriCtrl = TextEditingController();
  final _incomeBusinessCtrl = TextEditingController();
  final _incomeJobCtrl = TextEditingController();
  final _incomeOtherCtrl = TextEditingController();

  // Expense Breakdown
  final _expBasicCtrl = TextEditingController();
  final _expEducationCtrl = TextEditingController();
  final _expFestivalCtrl = TextEditingController();
  final _expHealthCtrl = TextEditingController();
  final _expEmiCtrl = TextEditingController();
  final _expOtherCtrl = TextEditingController();

  // Documents Deposited
  final List<String> _selectedDocs = [];
  final _docsOtherCtrl = TextEditingController();

  // Insurance
  String _insuranceWanted = 'no';
  String _insuranceFor = 'husband';
  bool _insuranceAck = false;

  // Recommendations
  final _groupRecCtrl = TextEditingController();
  final _centerRecCtrl = TextEditingController();

  // Declaration
  bool _appDeclaration = false;

  final Map<String, String> _docOptions = {
    'aadhaar': 'Aadhaar Card (आधार कार्ड)',
    'voter': 'Voter ID (मतदाता पहचान पत्र)',
    'pan': 'PAN Card (पैन कार्ड)',
    'ration': 'Ration Card (राशन कार्ड)',
    'passbook': 'Bank Passbook (बैंक पासबुक)',
    'id_proof': 'Other ID Proof (पहचान प्रमाण)',
    'address_proof': 'Address Proof (निवास प्रमाण)',
    'income_proof': 'Income Proof (आय प्रमाण)',
    'photo': 'Passport Photo (पासपोर्ट फोटो)',
    'other': 'Other Document (अन्य)',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final argCustomerId = ModalRoute.of(context)?.settings.arguments as int?;
      final customers = _visibleCustomers(
        context.read<CustomerProvider>().customers,
        context.read<AuthProvider>().currentUser,
      );
      if (argCustomerId != null) {
        final exists = customers.any((c) => c.id == argCustomerId);
        if (exists && mounted) {
          setState(() => _selectedCustomerId = argCustomerId);
          return;
        }
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tenureCtrl.dispose();
    _cycleCtrl.dispose();
    _purposeCtrl.dispose();
    _occupationCtrl.dispose();
    _employerCtrl.dispose();
    _incomeAgriCtrl.dispose();
    _incomeBusinessCtrl.dispose();
    _incomeJobCtrl.dispose();
    _incomeOtherCtrl.dispose();
    _expBasicCtrl.dispose();
    _expEducationCtrl.dispose();
    _expFestivalCtrl.dispose();
    _expHealthCtrl.dispose();
    _expEmiCtrl.dispose();
    _expOtherCtrl.dispose();
    _docsOtherCtrl.dispose();
    _groupRecCtrl.dispose();
    _centerRecCtrl.dispose();
    super.dispose();
  }

  int? _minorUnitsFromInput(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return 0;
    final value = double.tryParse(raw);
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        !CurrencyAmount.hasPaisePrecision(value)) {
      return null;
    }
    return CurrencyAmount.toMinorUnits(value);
  }

  int get _totalIncomeMinor =>
      [
        _incomeAgriCtrl,
        _incomeBusinessCtrl,
        _incomeJobCtrl,
        _incomeOtherCtrl,
      ].fold<int>(
        0,
        (sum, controller) => sum + (_minorUnitsFromInput(controller) ?? 0),
      );

  int get _totalExpenseMinor =>
      [
        _expBasicCtrl,
        _expEducationCtrl,
        _expFestivalCtrl,
        _expHealthCtrl,
        _expEmiCtrl,
        _expOtherCtrl,
      ].fold<int>(
        0,
        (sum, controller) => sum + (_minorUnitsFromInput(controller) ?? 0),
      );

  double get _totalIncome => CurrencyAmount.fromMinorUnits(_totalIncomeMinor);
  double get _totalExpense => CurrencyAmount.fromMinorUnits(_totalExpenseMinor);
  double get _netSaving =>
      CurrencyAmount.fromMinorUnits(_totalIncomeMinor - _totalExpenseMinor);

  LoanProductModel? _selectedProduct(List<LoanProductModel> products) {
    if (_selectedProductId <= 0) return null;
    try {
      return products.firstWhere((p) => p.id == _selectedProductId);
    } on StateError {
      return null;
    }
  }

  double _calcEmi(List<LoanProductModel> products) {
    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    final ten = int.tryParse(_tenureCtrl.text) ?? 1;
    if (amt <= 0 || ten <= 0 || !CurrencyAmount.hasPaisePrecision(amt)) {
      return 0.0;
    }

    final prod = _selectedProduct(products);
    if (prod == null) return 0.0;
    final rate = prod.rate;
    final method = prod.method;
    if (!rate.isFinite || rate < 0) return 0.0;
    final amountMinor = CurrencyAmount.toMinorUnits(amt);
    late final int emiMinor;
    if (method == 'flat') {
      emiMinor = ((amountMinor + (amountMinor * rate / 100 * ten / 12)) / ten)
          .round();
    } else {
      final r = rate / 1200;
      emiMinor = rate == 0
          ? (amountMinor / ten).round()
          : (amountMinor * r * pow(1 + r, ten) / (pow(1 + r, ten) - 1)).round();
    }
    return CurrencyAmount.fromMinorUnits(emiMinor);
  }

  Future<void> _submitApplication() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an applicant')),
      );
      return;
    }

    if (_selectedProductId <= 0 ||
        !context.read<LoanProvider>().products.any(
          (product) => product.id == _selectedProductId,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an active loan product.')),
      );
      return;
    }

    CustomerModel? applicant;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    for (final customer in _visibleCustomers(
      context.read<CustomerProvider>().customers,
      user,
    )) {
      if (customer.id == _selectedCustomerId) {
        applicant = customer;
        break;
      }
    }
    if (applicant?.kycStatus != 'verified') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'KYC must be manually reviewed and approved before applying.',
          ),
        ),
      );
      return;
    }

    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    final ten = int.tryParse(_tenureCtrl.text) ?? 0;
    final financialInputs = [
      _amountCtrl,
      _incomeAgriCtrl,
      _incomeBusinessCtrl,
      _incomeJobCtrl,
      _incomeOtherCtrl,
      _expBasicCtrl,
      _expEducationCtrl,
      _expFestivalCtrl,
      _expHealthCtrl,
      _expEmiCtrl,
      _expOtherCtrl,
      _groupRecCtrl,
      _centerRecCtrl,
    ];
    if (financialInputs.any(
      (controller) => _minorUnitsFromInput(controller) == null,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid non-negative financial amounts with at most two decimal places.',
          ),
        ),
      );
      return;
    }
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid loan amount')),
      );
      return;
    }
    if (ten <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid tenure in months')),
      );
      return;
    }
    final cycle = int.tryParse(_cycleCtrl.text) ?? 0;
    if (cycle <= 0 ||
        _purposeCtrl.text.trim().isEmpty ||
        _occupationCtrl.text.trim().isEmpty ||
        _totalIncome <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the loan purpose, occupation, loan cycle and household income.',
          ),
        ),
      );
      return;
    }

    if (_selectedDocs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 documents must be deposited')),
      );
      return;
    }

    if (!_appDeclaration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the loan repayment declaration'),
        ),
      );
      return;
    }

    final customers = _visibleCustomers(
      context.read<CustomerProvider>().customers,
      user,
    );
    CustomerModel? cust;
    try {
      cust = customers.firstWhere((c) => c.id == _selectedCustomerId);
    } catch (_) {}

    final appId = await context.read<LoanProvider>().submitNewLoanApplication(
      customerId: _selectedCustomerId!,
      productId: _selectedProductId,
      amount: amt,
      tenure: ten,
      purpose: _purposeCtrl.text.trim(),
      income: _totalIncome,
      occupation: _occupationCtrl.text.trim(),
      agentId: user.id,
      branch: cust?.branch ?? user.branch,
      employer: _employerCtrl.text.trim(),
      coName: cust?.coName ?? cust?.husbandName ?? '',
      coPhone: cust?.coPhone ?? '',
      coRelation:
          cust?.coRelation ??
          (cust?.guardianType == 'husband' ? 'Husband' : ''),
      coIncome: cust?.coIncome ?? 0.0,
      incAgri: double.tryParse(_incomeAgriCtrl.text) ?? 0,
      incBusiness: double.tryParse(_incomeBusinessCtrl.text) ?? 0,
      incJob: double.tryParse(_incomeJobCtrl.text) ?? 0,
      incOther: double.tryParse(_incomeOtherCtrl.text) ?? 0,
      expBasic: double.tryParse(_expBasicCtrl.text) ?? 0,
      expEducation: double.tryParse(_expEducationCtrl.text) ?? 0,
      expFestival: double.tryParse(_expFestivalCtrl.text) ?? 0,
      expHealth: double.tryParse(_expHealthCtrl.text) ?? 0,
      expEmi: double.tryParse(_expEmiCtrl.text) ?? 0,
      expOther: double.tryParse(_expOtherCtrl.text) ?? 0,
      docsDeposited: _selectedDocs,
      docsOther: _docsOtherCtrl.text.trim(),
      insuranceWanted: _insuranceWanted,
      insuranceFor: _insuranceFor,
      groupRec: double.tryParse(_groupRecCtrl.text) ?? 0,
      centerRec: double.tryParse(_centerRecCtrl.text) ?? 0,
      loanCycle: cycle,
      declaration: _appDeclaration ? 1 : 0,
    );

    if (!mounted) return;

    if (appId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan Application #APP-$appId submitted successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application was not submitted. Check KYC, product terms, income-based EMI limits, declarations and access scope.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = _visibleCustomers(
      context.watch<CustomerProvider>().customers,
      context.watch<AuthProvider>().currentUser,
    );
    final loanProv = context.watch<LoanProvider>();
    final products = loanProv.products;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    CustomerModel? selectedCust;
    if (_selectedCustomerId != null) {
      try {
        selectedCust = customers.firstWhere((c) => c.id == _selectedCustomerId);
      } catch (_) {}
    }

    final hasKyc = selectedCust?.kycStatus == 'verified';
    final hasKycForm = selectedCust?.centerNo?.isNotEmpty ?? false;
    final currentEmi = _calcEmi(products);
    final netSaving = _netSaving;
    final currentEmiMinor = currentEmi > 0
        ? CurrencyAmount.toMinorUnits(currentEmi)
        : 0;
    final isEmiHigh = currentEmi > netSaving && netSaving > 0;
    final isEmiAboveIncomeLimit =
        currentEmiMinor * 100 > _totalIncomeMinor * 60;
    final isNegativeSaving = netSaving <= 0 && _totalIncome > 0;
    final hasAffordabilityWarning =
        isEmiHigh || isEmiAboveIncomeLimit || isNegativeSaving;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Loan Application / ऋण आवेदन'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Customer & Loan
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1 · CUSTOMER & LOAN TERMS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _selectedCustomerId,
                      decoration: const InputDecoration(
                        labelText: 'Customer *',
                      ),
                      isExpanded: true,
                      items: customers.map((c) {
                        final kycNote = c.kycStatus == 'verified'
                            ? ' [KYC Approved]'
                            : (c.centerNo?.isNotEmpty ?? false)
                            ? ' [KYC Pending Review]'
                            : ' [KYC Required]';
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.name} (${c.phone})$kycNote',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCustomerId = val;
                        });
                      },
                    ),
                    if (!hasKyc && selectedCust != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasKycForm
                                    ? 'KYC is pending manual review. A separate authorized reviewer must approve it before an application can be submitted.'
                                    : 'This customer has no KYC form yet. Complete the form and obtain separate manual approval first.',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.brown,
                                ),
                              ),
                            ),
                            if (!hasKycForm)
                              TextButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/kyc_form',
                                  arguments: selectedCust!.id,
                                ),
                                child: const Text(
                                  'Fill KYC',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value:
                          products.any(
                            (product) => product.id == _selectedProductId,
                          )
                          ? _selectedProductId
                          : null,
                      decoration: const InputDecoration(labelText: 'Product *'),
                      hint: const Text('Select an active product'),
                      items: products.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} · ${p.rate}% (${p.method})'),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedProductId = val ?? 0),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Amount (₹) *',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _tenureCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tenure (months) *',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _cycleCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cycle *',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _purposeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Purpose of Loan *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.tealSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.tealPrimary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calculate,
                            color: AppTheme.tealPrimary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedProduct(products) == null
                                  ? 'Select an active product to calculate an estimated EMI.'
                                  : 'Estimated EMI: ${currency.format(currentEmi)} / month (${_selectedProduct(products)!.method} @ ${_selectedProduct(products)!.rate}%)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.tealDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 2. Co-Applicant Info
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      color: Colors.blueGrey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Co-Applicant: ${selectedCust?.coName ?? selectedCust?.husbandName ?? 'None on KYC record'}'
                        '${selectedCust?.coRelation != null ? ' (${selectedCust!.coRelation})' : ''}'
                        '${selectedCust?.coIncome != null ? ' · Income ₹${selectedCust!.coIncome!.toInt()}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 3. Monthly Cash Flow
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3 · MONTHLY CASH FLOW (₹ PER MONTH)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Income / आय',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _incomeBusinessCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Business / Trade',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _incomeAgriCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Agriculture / Dairy',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _incomeJobCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Salary / Wages',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _incomeOtherCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Other / Co-borrower',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Income: ${currency.format(_totalIncome)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: AppTheme.success,
                      ),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Expenses / व्यय',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _expBasicCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Basic / Food / Utility',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _expEducationCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Education',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _expHealthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Health / Medical',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _expFestivalCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Festival / Social',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _expEmiCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Existing EMIs',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _expOtherCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Other Expenses',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Expenses: ${currency.format(_totalExpense)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasAffordabilityWarning
                            ? AppTheme.dangerLight
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Net Monthly Saving / शुद्ध बचत:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                currency.format(netSaving),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: hasAffordabilityWarning
                                      ? AppTheme.danger
                                      : AppTheme.navyDark,
                                ),
                              ),
                            ],
                          ),
                          if (isEmiHigh)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                '⚠️ Alert: Estimated EMI exceeds net monthly saving!',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isEmiAboveIncomeLimit)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                '⚠️ Alert: Estimated EMI exceeds 60% of monthly household income and cannot be submitted.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isNegativeSaving)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                '⚠️ Alert: Expenses exceed total household income!',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _occupationCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Occupation / व्यवसाय',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _employerCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Employer / Business',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 4. Deposited Documents Check
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            '4 · DOCUMENTS DEPOSITED / जमा दस्तावेज़',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedDocs.length >= 2
                                ? AppTheme.successLight
                                : AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedDocs.length} selected (min 2)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _selectedDocs.length >= 2
                                  ? AppTheme.tealDark
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: _docOptions.entries.map((e) {
                        final isChecked = _selectedDocs.contains(e.key);
                        return FilterChip(
                          selected: isChecked,
                          showCheckmark: true,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.tealPrimary,
                          elevation: 0,
                          pressElevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          side: BorderSide(
                            color: isChecked
                                ? AppTheme.tealDark
                                : const Color(0xFFCBD5E1),
                            width: isChecked ? 1.5 : 1.2,
                          ),
                          avatar: isChecked
                              ? null
                              : const Icon(
                                  Icons.check_box_outline_blank,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                          label: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isChecked
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isChecked
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedDocs.add(e.key);
                              } else {
                                _selectedDocs.remove(e.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_selectedDocs.contains('other')) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _docsOtherCtrl,
                        decoration: const InputDecoration(
                          labelText: 'If other document, specify details',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 5. Life Insurance
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '5 · LIFE INSURANCE / जीवन बीमा',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Opt for Insurance: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Radio<String>(
                          value: 'yes',
                          groupValue: _insuranceWanted,
                          onChanged: (v) =>
                              setState(() => _insuranceWanted = v!),
                        ),
                        const Text(
                          'Yes / हाँ',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        const SizedBox(width: 14),
                        Radio<String>(
                          value: 'no',
                          groupValue: _insuranceWanted,
                          onChanged: (v) =>
                              setState(() => _insuranceWanted = v!),
                        ),
                        const Text(
                          'No / नहीं',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                    if (_insuranceWanted == 'yes') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Cover For: ',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Radio<String>(
                            value: 'self',
                            groupValue: _insuranceFor,
                            onChanged: (v) =>
                                setState(() => _insuranceFor = v!),
                          ),
                          const Text('Self', style: TextStyle(fontSize: 12)),
                          Radio<String>(
                            value: 'husband',
                            groupValue: _insuranceFor,
                            onChanged: (v) =>
                                setState(() => _insuranceFor = v!),
                          ),
                          const Text('Husband', style: TextStyle(fontSize: 12)),
                          Radio<String>(
                            value: 'both',
                            groupValue: _insuranceFor,
                            onChanged: (v) =>
                                setState(() => _insuranceFor = v!),
                          ),
                          const Text('Both', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _insuranceAck,
                        onChanged: (v) => setState(() => _insuranceAck = v!),
                        title: const Text(
                          'I understand premium is collected with loan and cover has been explained. (प्रीमियम और कवर जानकारी प्राप्त) *',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 6. Recommendation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '6 · RECOMMENDATIONS (OPTIONAL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _groupRecCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Group Leader Recommends (₹)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _centerRecCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Centre Leader Recommends (₹)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Declaration & Submit
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _appDeclaration,
                  onChanged: (v) => setState(() => _appDeclaration = v!),
                  title: const Text(
                    'I declare that the information given is correct and I will repay the loan on time. (मैं घोषणा करती हूँ कि दी गई जानकारी सही है और मैं ऋण समय पर चुकाऊँगी) *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: _submitApplication,
                label: const Text(
                  'Submit Loan Application / आवेदन जमा करें',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<CustomerModel> _visibleCustomers(
    List<CustomerModel> customers,
    UserModel? user,
  ) {
    if (user == null) return const [];
    if (user.role == 'admin') return customers;
    if (user.role == 'field_agent') {
      return customers
          .where((customer) => customer.agentId == user.id)
          .toList();
    }
    return customers
        .where((customer) => customer.branch == user.branch)
        .toList();
  }
}
