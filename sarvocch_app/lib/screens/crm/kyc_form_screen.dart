import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class KycFormScreen extends StatefulWidget {
  const KycFormScreen({super.key});

  @override
  State<KycFormScreen> createState() => _KycFormScreenState();
}

class _KycFormScreenState extends State<KycFormScreen> {
  int _currentStep = 0;
  int? _selectedCustomerId;

  // Bilingual Controllers
  final _centerNoCtrl = TextEditingController(text: 'C-101');
  final _groupNoCtrl = TextEditingController(text: 'G-A');
  final _guardianTypeCtrl = TextEditingController(text: 'husband');
  final _guardianNameCtrl = TextEditingController(text: 'Ramesh Verma');
  final _educationCtrl = TextEditingController(text: 'Secondary (10th)');
  final _religionCtrl = TextEditingController(text: 'Hindu');
  final _categoryCtrl = TextEditingController(text: 'OBC');
  
  // Residence & Land
  final _houseNoCtrl = TextEditingController(text: '12');
  final _villageCtrl = TextEditingController(text: 'Vijay Nagar');
  final _postOfficeCtrl = TextEditingController(text: 'Vijay Nagar PO');
  final _districtCtrl = TextEditingController(text: 'Indore');
  final _stateCtrl = TextEditingController(text: 'Madhya Pradesh');
  final _pincodeCtrl = TextEditingController(text: '452010');
  String _houseType = 'pucca';
  final _landHaCtrl = TextEditingController(text: '0.0');
  final _livestockCtrl = TextEditingController(text: '1 cow, 2 goats');

  // Bank & Income
  final _bankNameCtrl = TextEditingController(text: 'State Bank of India');
  final _bankAcctCtrl = TextEditingController(text: '30123456780');
  final _passbookNameCtrl = TextEditingController(text: 'Sunita Verma');
  String _povertyLine = 'APL';
  final _annualIncomeCtrl = TextEditingController(text: '216000');

  // Husband Info & Consent
  final _husbandNameCtrl = TextEditingController(text: 'Ramesh Verma');
  final _husbandFatherCtrl = TextEditingController(text: 'Suresh Verma');
  final _husbandDobCtrl = TextEditingController(text: '1984-03-02');
  bool _husbandConsentGiven = true;
  bool _declarationAccepted = true;
  bool _addressVisited = true;

  @override
  void initState() {
    super.initState();
    // Accept a pre-selected customer ID passed as route argument
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final argCustomerId = ModalRoute.of(context)?.settings.arguments as int?;
      final customers = context.read<CustomerProvider>().customers;
      if (argCustomerId != null) {
        // Verify the customer exists, then select it
        final exists = customers.any((c) => c.id == argCustomerId);
        if (exists && mounted) {
          setState(() => _selectedCustomerId = argCustomerId);
          return;
        }
      }
      // Fallback to first customer
      if (customers.isNotEmpty && mounted) {
        setState(() => _selectedCustomerId = customers.first.id);
      }
    });
  }

  Future<void> _submitKycForm() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await context.read<CustomerProvider>().saveKycForm(
      customerId: _selectedCustomerId!,
      agentId: auth.currentUser?.id ?? 4,
      centerNo: _centerNoCtrl.text.trim(),
      groupNo: _groupNoCtrl.text.trim(),
      guardianType: _guardianTypeCtrl.text.trim(),
      guardianName: _guardianNameCtrl.text.trim(),
      education: _educationCtrl.text.trim(),
      religion: _religionCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      houseNo: _houseNoCtrl.text.trim(),
      village: _villageCtrl.text.trim(),
      postOffice: _postOfficeCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      houseType: _houseType,
      landHa: double.tryParse(_landHaCtrl.text) ?? 0.0,
      livestock: _livestockCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim(),
      bankAcct: _bankAcctCtrl.text.trim(),
      passbookName: _passbookNameCtrl.text.trim(),
      povertyLine: _povertyLine,
      annualIncome: double.tryParse(_annualIncomeCtrl.text) ?? 180000.0,
      husbandName: _husbandNameCtrl.text.trim(),
      husbandFather: _husbandFatherCtrl.text.trim(),
      husbandDob: _husbandDobCtrl.text.trim(),
      consentGiven: _husbandConsentGiven ? 1 : 0,
      addressVerified: _addressVisited ? 1 : 0,
      verifiedBy: auth.currentUser?.name ?? 'Ravi Field Officer',
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bilingual KYC Form saved & verified successfully!'),
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

    return Scaffold(
      appBar: const CustomAppBar(title: 'Bilingual KYC Digital Form'),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _submitKycForm();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 2 ? 'Save & Submit KYC' : 'Next Step'),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Applicant'),
            isActive: _currentStep >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Customer Lead (ग्राहक चुनें) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: customers.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.name} (${c.phone}) - ${c.branch}'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCustomerId = val),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Center No (केंद्र सं.)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _centerNoCtrl, decoration: const InputDecoration(hintText: 'e.g. C-101')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Group No (समूह सं.)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _groupNoCtrl, decoration: const InputDecoration(hintText: 'e.g. G-A')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Education (शिक्षा)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _educationCtrl),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Category (वर्ग)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _categoryCtrl),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Residence & Bank'),
            isActive: _currentStep >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Village / Area (गाँव)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _villageCtrl),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('District (ज़िला)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _districtCtrl),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bank Name (बैंक का नाम)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _bankNameCtrl),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Account No (खाता सं.)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _bankAcctCtrl),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Annual Income (वार्षिक आय ₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          TextField(controller: _annualIncomeCtrl, keyboardType: TextInputType.number),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('House Type (मकान प्रकार)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _houseType,
                            items: const [
                              DropdownMenuItem(value: 'pucca', child: Text('Pucca (पक्का)')),
                              DropdownMenuItem(value: 'semi_pucca', child: Text('Semi-Pucca')),
                              DropdownMenuItem(value: 'kutcha', child: Text('Kutcha (कच्चा)')),
                            ],
                            onChanged: (val) => setState(() => _houseType = val!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Husband Consent'),
            isActive: _currentStep >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.tealSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.tealPrimary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.tealPrimary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Husband\'s Information & Co-Applicant Consent is mandatory under RBI JLG Guidelines.',
                          style: TextStyle(fontSize: 12, color: AppTheme.tealDark, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _husbandNameCtrl,
                  decoration: const InputDecoration(labelText: 'Husband Name (पति का नाम) *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _husbandFatherCtrl,
                        decoration: const InputDecoration(labelText: 'Husband\'s Father (ससुर का नाम)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _husbandDobCtrl,
                        decoration: const InputDecoration(labelText: 'Husband DOB (जन्म तिथि)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _husbandConsentGiven,
                  onChanged: (val) => setState(() => _husbandConsentGiven = val!),
                  title: const Text(
                    'Husband\'s written consent obtained for loan liability (पति की सहमति प्राप्त)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _addressVisited,
                  onChanged: (val) => setState(() => _addressVisited = val!),
                  title: const Text(
                    'Physical address and living standards verified at residence by Field Officer',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _declarationAccepted,
                  onChanged: (val) => setState(() => _declarationAccepted = val!),
                  title: const Text(
                    'Applicant signed self-declaration & credit bureau check consent',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
