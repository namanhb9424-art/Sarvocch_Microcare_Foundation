import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

class FamilyMemberInput {
  TextEditingController name;
  TextEditingController age;
  String edu;
  String rel;
  TextEditingController occ;

  FamilyMemberInput({
    required String name,
    required String age,
    this.edu = 'Primary (Class 5)',
    this.rel = 'Self',
    required String occ,
  })  : name = TextEditingController(text: name),
        age = TextEditingController(text: age),
        occ = TextEditingController(text: occ);

  void dispose() {
    name.dispose();
    age.dispose();
    occ.dispose();
  }

  Map<String, dynamic> toMap() => {
        'name': name.text.trim(),
        'age': int.tryParse(age.text) ?? 0,
        'edu': edu,
        'rel': rel,
        'occ': occ.text.trim(),
      };
}

class _KycFormScreenState extends State<KycFormScreen> {
  int _currentStep = 0;
  int? _selectedCustomerId;

  // Step 0: Applicant & Centre Details
  final _formDateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _centerNoCtrl = TextEditingController(text: 'C-101');
  final _groupNoCtrl = TextEditingController(text: 'G-A');
  final _nameCtrl = TextEditingController(text: 'Sunita Verma');
  final _phoneCtrl = TextEditingController(text: '9876543210');
  final _dobCtrl = TextEditingController(text: '1988-06-15');
  String _guardianType = 'husband';
  final _guardianNameCtrl = TextEditingController(text: 'Ramesh Verma');
  String _education = 'Primary (Class 5)';
  String _religion = 'Hindu';
  String _category = 'OBC';
  String? _applicantPhotoPath;

  // Step 1: Address & Family Members
  final _houseNoCtrl = TextEditingController(text: '12');
  final _villageCtrl = TextEditingController(text: 'Vijay Nagar');
  final _postOfficeCtrl = TextEditingController(text: 'Vijay Nagar PO');
  final _districtCtrl = TextEditingController(text: 'Gorakhpur');
  String _state = 'Uttar Pradesh';
  final _pincodeCtrl = TextEditingController(text: '273001');
  final List<FamilyMemberInput> _familyMembers = [];

  // Step 2: Assets, Bank & Financials
  String _houseType = 'Pucca';
  final _landHaCtrl = TextEditingController(text: '0.5');
  final _livestockCtrl = TextEditingController(text: '1 cow, 2 goats');
  final _bankNameCtrl = TextEditingController(text: 'State Bank of India');
  final _bankAcctCtrl = TextEditingController(text: '30123456780');
  final _passbookNameCtrl = TextEditingController(text: 'Sunita Verma');
  String _povertyLine = 'BPL';
  final _distCenterMCtrl = TextEditingController(text: '300');
  final _distBranchKmCtrl = TextEditingController(text: '4.5');
  String _relativeInCenter = 'no';
  final _relativeNameCtrl = TextEditingController();
  final _annualIncomeCtrl = TextEditingController(text: '180000');
  final _otherLoansCtrl = TextEditingController(text: '0');
  final _currentDebtCtrl = TextEditingController(text: '0');
  String _repayFreq = 'monthly';

  // Co-Applicant
  final _coNameCtrl = TextEditingController(text: 'Ramesh Verma');
  final _coPhoneCtrl = TextEditingController(text: '9876543211');
  String _coRelation = 'Husband';
  final _coIncomeCtrl = TextEditingController(text: '12000');

  // Step 3: Husband Consent & KYC Verification
  final _husbandNameCtrl = TextEditingController(text: 'Ramesh Verma');
  final _husbandFatherCtrl = TextEditingController(text: 'Suresh Verma');
  final _husbandDobCtrl = TextEditingController(text: '1984-03-02');
  final _husbandAddressCtrl = TextEditingController(text: '12, Vijay Nagar, Gorakhpur');
  bool _husbandSameAddr = true;
  String? _husbandPhotoPath;
  bool _husbandConsentGiven = true;
  bool _declarationAccepted = true;
  bool _bureauConsentAccepted = true;
  bool _addressVisited = true;
  final _verifyRemarksCtrl = TextEditingController(text: 'Living conditions verified at residence.');

  // Constants matching app.py
  final List<String> _educationOpts = [
    'Illiterate',
    'Primary (Class 5)',
    'Middle (Class 8)',
    'High School (Class 10)',
    'Intermediate (Class 12)',
    'Graduate & above',
  ];

  final List<String> _religionOpts = ['Hindu', 'Muslim', 'Christian', 'Sikh', 'Other'];
  final List<String> _categoryOpts = ['General', 'OBC', 'SC', 'ST', 'Minority'];
  final List<String> _stateOpts = [
    'Uttar Pradesh',
    'Madhya Pradesh',
    'Bihar',
    'Rajasthan',
    'Maharashtra',
    'Delhi',
  ];
  final List<String> _houseTypeOpts = ['Pucca', 'Semi-Pucca', 'Kachha', 'Rented'];
  final List<String> _coRelationOpts = ['Husband', 'Son', 'Daughter', 'Father', 'Mother', 'Brother', 'Other'];
  final List<String> _familyRelOpts = ['Self', 'Husband', 'Wife', 'Son', 'Daughter', 'Father', 'Mother', 'Brother', 'Sister', 'Other'];

  @override
  void initState() {
    super.initState();
    _initFamily();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final argCustomerId = ModalRoute.of(context)?.settings.arguments as int?;
      final customers = context.read<CustomerProvider>().customers;
      if (argCustomerId != null) {
        final exists = customers.any((c) => c.id == argCustomerId);
        if (exists && mounted) {
          setState(() {
            _selectedCustomerId = argCustomerId;
            _populateFromCustomer(customers.firstWhere((c) => c.id == argCustomerId));
          });
          return;
        }
      }
      if (customers.isNotEmpty && mounted) {
        setState(() {
          _selectedCustomerId = customers.first.id;
          _populateFromCustomer(customers.first);
        });
      }
    });
  }

  void _initFamily() {
    if (_familyMembers.isEmpty) {
      _familyMembers.add(
        FamilyMemberInput(
          name: _nameCtrl.text,
          age: _calcAge(_dobCtrl.text).toString(),
          edu: _education,
          rel: 'Self',
          occ: 'Tailoring',
        ),
      );
      _familyMembers.add(
        FamilyMemberInput(
          name: _guardianNameCtrl.text,
          age: '40',
          edu: 'High School (Class 10)',
          rel: 'Husband',
          occ: 'Daily wage worker',
        ),
      );
    }
  }

  void _populateFromCustomer(dynamic c) {
    _nameCtrl.text = c.name;
    _phoneCtrl.text = c.phone;
    if (c.dob != null && c.dob.isNotEmpty) _dobCtrl.text = c.dob;
    if (c.address != null && c.address.isNotEmpty) _villageCtrl.text = c.address;
    if (c.centerNo != null) _centerNoCtrl.text = c.centerNo!;
    if (c.groupNo != null) _groupNoCtrl.text = c.groupNo!;
    if (c.guardianName != null) {
      _guardianNameCtrl.text = c.guardianName!;
      _husbandNameCtrl.text = c.guardianName!;
    }
    if (c.annualIncome != null && c.annualIncome! > 0) {
      _annualIncomeCtrl.text = c.annualIncome!.toInt().toString();
    }
  }

  @override
  void dispose() {
    _formDateCtrl.dispose();
    _centerNoCtrl.dispose();
    _groupNoCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _guardianNameCtrl.dispose();
    _houseNoCtrl.dispose();
    _villageCtrl.dispose();
    _postOfficeCtrl.dispose();
    _districtCtrl.dispose();
    _pincodeCtrl.dispose();
    _landHaCtrl.dispose();
    _livestockCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAcctCtrl.dispose();
    _passbookNameCtrl.dispose();
    _distCenterMCtrl.dispose();
    _distBranchKmCtrl.dispose();
    _relativeNameCtrl.dispose();
    _annualIncomeCtrl.dispose();
    _otherLoansCtrl.dispose();
    _currentDebtCtrl.dispose();
    _coNameCtrl.dispose();
    _coPhoneCtrl.dispose();
    _coIncomeCtrl.dispose();
    _husbandNameCtrl.dispose();
    _husbandFatherCtrl.dispose();
    _husbandDobCtrl.dispose();
    _husbandAddressCtrl.dispose();
    _verifyRemarksCtrl.dispose();
    for (var m in _familyMembers) {
      m.dispose();
    }
    super.dispose();
  }

  int _calcAge(String dateStr) {
    try {
      final dob = DateTime.parse(dateStr);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 35;
    }
  }

  Future<void> _pickImage(bool isHusband) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked != null) {
        setState(() {
          if (isHusband) {
            _husbandPhotoPath = picked.path;
          } else {
            _applicantPhotoPath = picked.path;
          }
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> _submitKycForm() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer lead')),
      );
      return;
    }

    if (!_declarationAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the applicant declaration')),
      );
      return;
    }

    if (_guardianType == 'husband' && !_husbandConsentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Husband consent is required for loan approval')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final familyData = _familyMembers.map((m) => m.toMap()).toList();

    final success = await context.read<CustomerProvider>().saveKycForm(
      customerId: _selectedCustomerId!,
      agentId: auth.currentUser?.id ?? 4,
      centerNo: _centerNoCtrl.text.trim(),
      groupNo: _groupNoCtrl.text.trim(),
      guardianType: _guardianType,
      guardianName: _guardianNameCtrl.text.trim(),
      education: _education,
      religion: _religion,
      category: _category,
      houseNo: _houseNoCtrl.text.trim(),
      village: _villageCtrl.text.trim(),
      postOffice: _postOfficeCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      state: _state,
      pincode: _pincodeCtrl.text.trim(),
      houseType: _houseType,
      landHa: double.tryParse(_landHaCtrl.text) ?? 0.0,
      livestock: _livestockCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim(),
      bankAcct: _bankAcctCtrl.text.trim(),
      passbookName: _passbookNameCtrl.text.trim(),
      povertyLine: _povertyLine,
      annualIncome: double.tryParse(_annualIncomeCtrl.text) ?? 180000.0,
      distCenterM: double.tryParse(_distCenterMCtrl.text) ?? 300.0,
      distBranchKm: double.tryParse(_distBranchKmCtrl.text) ?? 4.0,
      relativeInCenter: _relativeInCenter,
      relativeName: _relativeNameCtrl.text.trim(),
      otherLoans: int.tryParse(_otherLoansCtrl.text) ?? 0,
      currentDebt: double.tryParse(_currentDebtCtrl.text) ?? 0.0,
      repayFreq: _repayFreq,
      coName: _coNameCtrl.text.trim(),
      coPhone: _coPhoneCtrl.text.trim(),
      coRelation: _coRelation,
      coIncome: double.tryParse(_coIncomeCtrl.text) ?? 0.0,
      photo: _applicantPhotoPath,
      husbandName: _husbandNameCtrl.text.trim(),
      husbandFather: _husbandFatherCtrl.text.trim(),
      husbandDob: _husbandDobCtrl.text.trim(),
      husbandAddress: _husbandSameAddr ? '${_houseNoCtrl.text}, ${_villageCtrl.text}, ${_districtCtrl.text}' : _husbandAddressCtrl.text.trim(),
      husbandPhoto: _husbandPhotoPath,
      consentGiven: _husbandConsentGiven ? 1 : 0,
      declaration: _declarationAccepted ? 1 : 0,
      bureauConsent: _bureauConsentAccepted ? 1 : 0,
      addressVerified: _addressVisited ? 1 : 0,
      verifiedBy: auth.currentUser?.name ?? 'Field Officer',
      verifyRemarks: _verifyRemarksCtrl.text.trim(),
      family: familyData,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bilingual KYC Form & Dossier saved successfully!'),
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

  Widget _buildPhotoTile({
    required String title,
    required String? photoPath,
    required VoidCallback onPick,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: photoPath != null && File(photoPath).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(File(photoPath), fit: BoxFit.cover),
                  )
                : const Icon(Icons.person, size: 36, color: Colors.grey),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  photoPath != null ? 'Photo selected' : 'No photo uploaded (JPG/PNG)',
                  style: TextStyle(fontSize: 11.5, color: photoPath != null ? AppTheme.success : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.camera_alt, size: 16),
            label: const Text('Capture'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Bilingual KYC Digital Form (प्रपत्र)'),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 3) {
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
                  child: Text(_currentStep == 3 ? 'Save & Submit KYC' : 'Next Step'),
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
          // Step 0: Applicant & Centre Details
          Step(
            title: const Text('Applicant'),
            isActive: _currentStep >= 0,
            content: SingleChildScrollView(
              child: Column(
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
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomerId = val;
                        if (val != null) {
                          final c = customers.firstWhere((x) => x.id == val);
                          _populateFromCustomer(c);
                        }
                      });
                    },
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
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Applicant Name (नाम) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _nameCtrl),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mobile (मोबाइल) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone),
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
                            const Text('Date of Birth (जन्म तिथि) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _dobCtrl,
                              decoration: InputDecoration(
                                hintText: 'YYYY-MM-DD',
                                suffixText: 'Age: ${_calcAge(_dobCtrl.text)}',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Relation of Guardian', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _guardianType,
                              items: const [
                                DropdownMenuItem(value: 'husband', child: Text('Husband (पति)')),
                                DropdownMenuItem(value: 'father', child: Text('Father (पिता)')),
                              ],
                              onChanged: (val) => setState(() => _guardianType = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_guardianType == 'husband' ? 'Husband' : 'Father'}\'s Name (पति/पिता का नाम) *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _guardianNameCtrl,
                        onChanged: (val) {
                          if (_guardianType == 'husband') {
                            _husbandNameCtrl.text = val;
                          }
                        },
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
                            const Text('Education (शिक्षा) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _education,
                              isExpanded: true,
                              items: _educationOpts.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) => setState(() => _education = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Religion (धर्म) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _religion,
                              items: _religionOpts.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (val) => setState(() => _religion = val!),
                            ),
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
                            const Text('Category (वर्ग) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _category,
                              items: _categoryOpts.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) => setState(() => _category = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildPhotoTile(
                    title: 'Applicant Photo (आवेदक का फोटो)',
                    photoPath: _applicantPhotoPath,
                    onPick: () => _pickImage(false),
                  ),
                ],
              ),
            ),
          ),

          // Step 1: Address & Family Members
          Step(
            title: const Text('Address & Family'),
            isActive: _currentStep >= 1,
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('House No (मकान सं.)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _houseNoCtrl),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Village / Area (गाँव/नगर) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _villageCtrl),
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
                            const Text('Post Office (पोस्ट)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _postOfficeCtrl),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('District (ज़िला) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
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
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('State (राज्य) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _state,
                              items: _stateOpts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setState(() => _state = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PIN Code *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _pincodeCtrl, keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Family Members / परिवार के सदस्य', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      TextButton.icon(
                        onPressed: _familyMembers.length >= 12
                            ? null
                            : () {
                                setState(() {
                                  _familyMembers.add(
                                    FamilyMemberInput(
                                      name: '',
                                      age: '20',
                                      edu: 'Class 5-8',
                                      rel: 'Son',
                                      occ: 'Student',
                                    ),
                                  );
                                });
                              },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Member'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _familyMembers.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, idx) {
                      final m = _familyMembers[idx];
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(radius: 12, backgroundColor: AppTheme.navyDark, child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: Colors.white))),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: m.name,
                                    decoration: const InputDecoration(isDense: true, hintText: 'Name / नाम', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    controller: m.age,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, hintText: 'Age', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                  ),
                                ),
                                if (idx > 0)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _familyMembers.removeAt(idx);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _familyRelOpts.contains(m.rel) ? m.rel : 'Other',
                                    isDense: true,
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                                    items: _familyRelOpts.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) => setState(() => m.rel = val!),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: m.occ,
                                    decoration: const InputDecoration(isDense: true, hintText: 'Occupation / व्यवसाय', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Step 2: Assets, Bank & Financials
          Step(
            title: const Text('Financials'),
            isActive: _currentStep >= 2,
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('House Type (मकान)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _houseType,
                              items: _houseTypeOpts.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                              onChanged: (val) => setState(() => _houseType = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Poverty Line (गरीबी रेखा)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _povertyLine,
                              items: const [
                                DropdownMenuItem(value: 'BPL', child: Text('BPL')),
                                DropdownMenuItem(value: 'APL', child: Text('APL')),
                              ],
                              onChanged: (val) => setState(() => _povertyLine = val!),
                            ),
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
                            const Text('Land (Hectare)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _landHaCtrl, keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Livestock (पशुधन)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _livestockCtrl),
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
                            const Text('Bank Name (बैंक)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
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
                            TextField(controller: _bankAcctCtrl, keyboardType: TextInputType.number),
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
                            const Text('Dist to Center (m)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _distCenterMCtrl, keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dist to Branch (km)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            TextField(controller: _distBranchKmCtrl, keyboardType: TextInputType.number),
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
                            const Text('Annual Income (वार्षिक आय ₹) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
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
                            const Text('Repay Frequency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _repayFreq,
                              items: const [
                                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly')),
                              ],
                              onChanged: (val) => setState(() => _repayFreq = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Co-Applicant Details (सह-आवेदक)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(controller: _coNameCtrl, decoration: const InputDecoration(labelText: 'Name (नाम)')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(controller: _coPhoneCtrl, decoration: const InputDecoration(labelText: 'Mobile'), keyboardType: TextInputType.phone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _coRelationOpts.contains(_coRelation) ? _coRelation : 'Husband',
                          decoration: const InputDecoration(labelText: 'Relation with applicant'),
                          items: _coRelationOpts.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (val) => setState(() => _coRelation = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(controller: _coIncomeCtrl, decoration: const InputDecoration(labelText: 'Monthly Income (₹)'), keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Step 3: Husband Consent & Declarations
          Step(
            title: const Text('Consent & Verify'),
            isActive: _currentStep >= 3,
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_guardianType == 'husband') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.gavel, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Text('Husband Information & Loan Consent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'मैं, ${_guardianNameCtrl.text}, प्रमाणित करता हूँ कि श्रीमती ${_nameCtrl.text} मेरी पत्नी हैं। मैं अपने परिवार की व्यावसायिक वृद्धि के लिए उन्हें सर्वोच्च माइक्रोकेयर फाउंडेशन से ऋण लेने की सहमति देता हूँ। मैं उनके केन्द्र बैठक में समय से जाने तथा समय से ऋण अदायगी के लिए जिम्मेदार रहूँगा।',
                            style: TextStyle(fontSize: 11.5, color: Colors.brown.shade800, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(controller: _husbandFatherCtrl, decoration: const InputDecoration(labelText: 'Husband\'s Father\'s Name (ससुर का नाम)')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _husbandDobCtrl,
                            decoration: InputDecoration(
                              labelText: 'Husband DOB (जन्म तिथि)',
                              suffixText: 'Age: ${_calcAge(_husbandDobCtrl.text)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _husbandSameAddr,
                      onChanged: (val) => setState(() => _husbandSameAddr = val!),
                      title: const Text('Husband address is same as applicant address', style: TextStyle(fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (!_husbandSameAddr)
                      TextField(controller: _husbandAddressCtrl, decoration: const InputDecoration(labelText: 'Husband Residence Address')),
                    const SizedBox(height: 10),
                    _buildPhotoTile(
                      title: 'Husband Photo (पति का फोटो)',
                      photoPath: _husbandPhotoPath,
                      onPick: () => _pickImage(true),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _husbandConsentGiven,
                      onChanged: (val) => setState(() => _husbandConsentGiven = val!),
                      title: const Text(
                        'The husband has read / heard the consent declaration and agrees. *',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const Divider(height: 24),
                  ],

                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _declarationAccepted,
                    onChanged: (val) => setState(() => _declarationAccepted = val!),
                    title: const Text(
                      'I declare that all information given in this form is complete and correct. (मैं घोषणा करता/करती हूँ कि इस प्रपत्र में दी गई सभी जानकारी पूर्णतया सही है) *',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _bureauConsentAccepted,
                    onChanged: (val) => setState(() => _bureauConsentAccepted = val!),
                    title: const Text(
                      'I agree that credit information may be shared with credit bureaus and insurance companies. (क्रेडिट ब्यूरो एवं बीमा कंपनी सहमति) *',
                      style: TextStyle(fontSize: 12),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _addressVisited,
                    onChanged: (val) => setState(() => _addressVisited = val!),
                    title: const Text(
                      'Field Officer: I visited applicant\'s home, verified address and physical assets. (सत्यापन) *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.navyDark),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _verifyRemarksCtrl,
                    decoration: const InputDecoration(labelText: 'Verification Remarks (सत्यापन टिप्पणी)'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
