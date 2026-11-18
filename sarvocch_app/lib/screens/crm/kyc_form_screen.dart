import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/customer_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../services/secure_attachment_service.dart';
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
    this.edu = '',
    this.rel = '',
    required String occ,
  }) : name = TextEditingController(text: name),
       age = TextEditingController(text: age),
       occ = TextEditingController(text: occ);

  void dispose() {
    name.dispose();
    age.dispose();
    occ.dispose();
  }

  Map<String, dynamic> toMap() => {
    'name': name.text.trim(),
    'age': int.tryParse(age.text),
    'edu': edu,
    'rel': rel,
    'occ': occ.text.trim(),
  };
}

class _KycFormScreenState extends State<KycFormScreen> {
  final _attachments = SecureAttachmentService();
  final Map<String, Future<Uint8List?>> _kycImageReads = {};
  final Set<String> _pendingAttachmentReferences = {};
  bool _isSavingKyc = false;
  int _currentStep = 0;
  int? _selectedCustomerId;

  // Step 0: Applicant & Centre Details
  final _formDateCtrl = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  final _centerNoCtrl = TextEditingController();
  final _groupNoCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _guardianType = '';
  final _guardianNameCtrl = TextEditingController();
  String _education = '';
  String _religion = '';
  String _category = '';
  String? _applicantPhotoPath;

  // Step 1: Address & Family Members
  final _houseNoCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _postOfficeCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  String _state = '';
  final _pincodeCtrl = TextEditingController();
  final List<FamilyMemberInput> _familyMembers = [];

  // Step 2: Assets, Bank & Financials
  String _houseType = '';
  final _landHaCtrl = TextEditingController();
  final _livestockCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAcctCtrl = TextEditingController();
  bool _obscureBankAccount = true;
  String? _savedBankAccountMask;
  final _passbookNameCtrl = TextEditingController();
  String _povertyLine = '';
  final _distCenterMCtrl = TextEditingController();
  final _distBranchKmCtrl = TextEditingController();
  String _relativeInCenter = '';
  final _relativeNameCtrl = TextEditingController();
  final _annualIncomeCtrl = TextEditingController();
  final _otherLoansCtrl = TextEditingController();
  final _currentDebtCtrl = TextEditingController();
  String _repayFreq = '';

  // Co-Applicant
  final _coNameCtrl = TextEditingController();
  final _coPhoneCtrl = TextEditingController();
  String _coRelation = '';
  final _coIncomeCtrl = TextEditingController();

  // Step 3: Husband Consent & KYC Verification
  final _husbandNameCtrl = TextEditingController();
  final _husbandFatherCtrl = TextEditingController();
  final _husbandDobCtrl = TextEditingController();
  final _husbandAddressCtrl = TextEditingController();
  bool _husbandSameAddr = false;
  String? _husbandPhotoPath;
  bool _husbandConsentGiven = false;
  bool _declarationAccepted = false;
  bool _bureauConsentAccepted = false;
  bool _addressVisited = false;

  // Constants matching app.py
  final List<String> _educationOpts = [
    'Illiterate',
    'Primary (Class 5)',
    'Middle (Class 8)',
    'High School (Class 10)',
    'Intermediate (Class 12)',
    'Graduate & above',
  ];

  final List<String> _religionOpts = [
    'Hindu',
    'Muslim',
    'Christian',
    'Sikh',
    'Other',
  ];
  final List<String> _categoryOpts = ['General', 'OBC', 'SC', 'ST', 'Minority'];
  final List<String> _stateOpts = [
    'Uttar Pradesh',
    'Madhya Pradesh',
    'Bihar',
    'Rajasthan',
    'Maharashtra',
    'Delhi',
  ];
  final List<String> _houseTypeOpts = [
    'Pucca',
    'Semi-Pucca',
    'Kachha',
    'Rented',
  ];
  final List<String> _coRelationOpts = [
    'Husband',
    'Son',
    'Daughter',
    'Father',
    'Mother',
    'Brother',
    'Other',
  ];
  final List<String> _familyRelOpts = [
    'Self',
    'Husband',
    'Wife',
    'Son',
    'Daughter',
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Other',
  ];

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
        final matches = customers.where((c) => c.id == argCustomerId);
        if (matches.isNotEmpty && mounted) _loadCustomer(matches.first);
      }
    });
  }

  void _clearForm() {
    _discardPendingAttachments();
    for (final controller in [
      _centerNoCtrl,
      _groupNoCtrl,
      _nameCtrl,
      _phoneCtrl,
      _dobCtrl,
      _guardianNameCtrl,
      _houseNoCtrl,
      _villageCtrl,
      _postOfficeCtrl,
      _districtCtrl,
      _pincodeCtrl,
      _landHaCtrl,
      _livestockCtrl,
      _bankNameCtrl,
      _bankAcctCtrl,
      _passbookNameCtrl,
      _distCenterMCtrl,
      _distBranchKmCtrl,
      _relativeNameCtrl,
      _annualIncomeCtrl,
      _otherLoansCtrl,
      _currentDebtCtrl,
      _coNameCtrl,
      _coPhoneCtrl,
      _coIncomeCtrl,
      _husbandNameCtrl,
      _husbandFatherCtrl,
      _husbandDobCtrl,
      _husbandAddressCtrl,
    ]) {
      controller.clear();
    }
    for (final member in _familyMembers) {
      member.dispose();
    }
    _familyMembers.clear();
    _guardianType = '';
    _education = '';
    _religion = '';
    _category = '';
    _state = '';
    _houseType = '';
    _povertyLine = '';
    _relativeInCenter = '';
    _repayFreq = '';
    _coRelation = '';
    _husbandSameAddr = false;
    _husbandConsentGiven = false;
    _declarationAccepted = false;
    _bureauConsentAccepted = false;
    _addressVisited = false;
    _applicantPhotoPath = null;
    _husbandPhotoPath = null;
    _obscureBankAccount = true;
    _savedBankAccountMask = null;
  }

  Future<void> _loadCustomer(CustomerModel c) async {
    setState(() {
      _selectedCustomerId = c.id;
      _kycImageReads.clear();
      _clearForm();
      _populateFromCustomer(c);
    });
    final actorUserId = context.read<AuthProvider>().currentUser?.id;
    if (actorUserId == null) return;
    final form = await context.read<CustomerProvider>().getKycForm(
      c.id,
      actorUserId: actorUserId,
    );
    if (!mounted || _selectedCustomerId != c.id || form == null) return;
    setState(() => _populateFromKycForm(form));
  }

  void _populateFromCustomer(CustomerModel c) {
    _nameCtrl.text = c.name;
    _phoneCtrl.text = c.phone;
    if (c.dob.isNotEmpty) _dobCtrl.text = c.dob;
    if (c.address.isNotEmpty) {
      _villageCtrl.text = c.address;
    }
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

  void _populateFromKycForm(Map<String, Object?> form) {
    void setText(TextEditingController controller, String key) {
      final value = form[key];
      if (value != null) controller.text = value.toString();
    }

    setText(_centerNoCtrl, 'center_no');
    setText(_groupNoCtrl, 'group_no');
    setText(_guardianNameCtrl, 'guardian_name');
    setText(_houseNoCtrl, 'house_no');
    setText(_villageCtrl, 'village');
    setText(_postOfficeCtrl, 'post_office');
    setText(_districtCtrl, 'district');
    setText(_pincodeCtrl, 'pincode');
    setText(_landHaCtrl, 'land_ha');
    setText(_livestockCtrl, 'livestock');
    setText(_bankNameCtrl, 'bank_name');
    setText(_bankAcctCtrl, 'bank_acct');
    _savedBankAccountMask = form['bank_acct_masked'] as String?;
    setText(_passbookNameCtrl, 'passbook_name');
    setText(_distCenterMCtrl, 'dist_center_m');
    setText(_distBranchKmCtrl, 'dist_branch_km');
    setText(_relativeNameCtrl, 'relative_name');
    setText(_annualIncomeCtrl, 'annual_income');
    setText(_otherLoansCtrl, 'other_loans');
    setText(_currentDebtCtrl, 'current_debt');
    setText(_coNameCtrl, 'co_name');
    setText(_coPhoneCtrl, 'co_phone');
    setText(_coIncomeCtrl, 'co_income');
    setText(_husbandNameCtrl, 'h_name');
    setText(_husbandFatherCtrl, 'h_father');
    setText(_husbandDobCtrl, 'h_dob');
    setText(_husbandAddressCtrl, 'h_address');

    _guardianType = ['husband', 'father'].contains(form['guardian_type'])
        ? form['guardian_type'] as String
        : '';
    _education = _educationOpts.contains(form['education'])
        ? form['education'] as String
        : '';
    _religion = _religionOpts.contains(form['religion'])
        ? form['religion'] as String
        : '';
    _category = _categoryOpts.contains(form['category'])
        ? form['category'] as String
        : '';
    _state = _stateOpts.contains(form['state']) ? form['state'] as String : '';
    _houseType = _houseTypeOpts.contains(form['house_type'])
        ? form['house_type'] as String
        : '';
    _povertyLine = ['BPL', 'APL'].contains(form['poverty_line'])
        ? form['poverty_line'] as String
        : '';
    _relativeInCenter = form['relative_in_center'] as String? ?? '';
    _repayFreq = ['monthly', 'weekly', 'biweekly'].contains(form['repay_freq'])
        ? form['repay_freq'] as String
        : '';
    _coRelation = _coRelationOpts.contains(form['co_relation'])
        ? form['co_relation'] as String
        : '';
    _applicantPhotoPath = form['photo'] as String?;
    _husbandPhotoPath = form['h_photo'] as String?;

    final familyData = form['family'];
    if (familyData is String && familyData.isNotEmpty) {
      try {
        final decoded = jsonDecode(familyData);
        if (decoded is List) {
          for (final member in decoded.whereType<Map>()) {
            _familyMembers.add(
              FamilyMemberInput(
                name: member['name']?.toString() ?? '',
                age: member['age']?.toString() ?? '',
                edu: member['edu']?.toString() ?? '',
                rel: _familyRelOpts.contains(member['rel'])
                    ? member['rel'].toString()
                    : '',
                occ: member['occ']?.toString() ?? '',
              ),
            );
          }
        }
      } catch (_) {
        _familyMembers.clear();
      }
    }
  }

  @override
  void dispose() {
    if (!_isSavingKyc) {
      _discardPendingAttachments();
    }
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
    for (var m in _familyMembers) {
      m.dispose();
    }
    super.dispose();
  }

  int? _calcAge(String dateStr) {
    try {
      final dob = DateTime.parse(dateStr);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage(bool isHusband) async {
    if (_isSavingKyc) return;
    try {
      final previousReference = isHusband
          ? _husbandPhotoPath
          : _applicantPhotoPath;
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) {
        final reference = await _attachments.storeImagePath(picked.path);
        if (!mounted) {
          await _attachments.deleteImage(reference);
          return;
        }
        _pendingAttachmentReferences.add(reference);
        setState(() {
          if (isHusband) {
            _husbandPhotoPath = reference;
          } else {
            _applicantPhotoPath = reference;
          }
        });
        if (previousReference != null &&
            _pendingAttachmentReferences.remove(previousReference)) {
          await _attachments.deleteImage(previousReference);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The selected image could not be saved securely.'),
          ),
        );
      }
    }
  }

  void _clearPhoto(bool isHusband) {
    if (_isSavingKyc) return;
    final reference = isHusband ? _husbandPhotoPath : _applicantPhotoPath;
    setState(() {
      if (isHusband) {
        _husbandPhotoPath = '';
      } else {
        _applicantPhotoPath = '';
      }
    });
    if (reference != null && _pendingAttachmentReferences.remove(reference)) {
      unawaited(_attachments.deleteImage(reference));
    }
  }

  void _discardPendingAttachments() {
    final pending = _pendingAttachmentReferences.toList(growable: false);
    _pendingAttachmentReferences.clear();
    for (final reference in pending) {
      unawaited(_attachments.deleteImage(reference));
    }
  }

  Widget _photoPreview(String? photoPath, {required bool husbandPhoto}) {
    if (photoPath == null || photoPath.isEmpty) {
      return const Icon(Icons.person, size: 36, color: Colors.grey);
    }
    final customerId = _selectedCustomerId;
    final actorUserId = context.read<AuthProvider>().currentUser?.id;
    if (customerId == null || actorUserId == null) {
      return const Icon(Icons.broken_image_outlined, color: Colors.red);
    }
    final cacheKey = '$customerId:$husbandPhoto:$photoPath';
    final future = _kycImageReads.putIfAbsent(
      cacheKey,
      () => context.read<CustomerProvider>().readKycAttachment(
        customerId: customerId,
        actorUserId: actorUserId,
        reference: photoPath,
        husbandPhoto: husbandPhoto,
      ),
    );
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError || (snapshot.hasData && snapshot.data == null)) {
          return const Icon(Icons.broken_image_outlined, color: Colors.red);
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.broken_image_outlined, color: Colors.red),
        );
      },
    );
  }

  Future<void> _submitKycForm() async {
    if (_isSavingKyc) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer lead')),
      );
      return;
    }

    if (_nameCtrl.text.trim().isEmpty ||
        !RegExp(r'^\+?[0-9\s()-]{10,20}$').hasMatch(_phoneCtrl.text.trim()) ||
        DateTime.tryParse(_dobCtrl.text.trim()) == null ||
        (_calcAge(_dobCtrl.text.trim()) ?? 0) < 18 ||
        (_calcAge(_dobCtrl.text.trim()) ?? 100) > 65 ||
        _phoneCtrl.text.trim().isEmpty ||
        _dobCtrl.text.trim().isEmpty ||
        _guardianType.isEmpty ||
        _education.isEmpty ||
        _religion.isEmpty ||
        _category.isEmpty ||
        _state.isEmpty ||
        _houseType.isEmpty ||
        _povertyLine.isEmpty ||
        _repayFreq.isEmpty ||
        (double.tryParse(_annualIncomeCtrl.text) ?? 0) <= 0 ||
        _villageCtrl.text.trim().isEmpty ||
        _districtCtrl.text.trim().isEmpty ||
        !RegExp(r'^[0-9]{6}$').hasMatch(_pincodeCtrl.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the required applicant details before saving',
          ),
        ),
      );
      return;
    }

    if (!_declarationAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the applicant declaration'),
        ),
      );
      return;
    }

    if (_guardianType == 'husband' && !_husbandConsentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Husband consent is required for loan approval'),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    final familyData = _familyMembers.map((m) => m.toMap()).toList();

    setState(() => _isSavingKyc = true);
    var success = false;
    try {
      success = await context.read<CustomerProvider>().saveKycForm(
        customerId: _selectedCustomerId!,
        agentId: currentUser.id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        dob: _dobCtrl.text.trim(),
        address: [
          _houseNoCtrl.text.trim(),
          _villageCtrl.text.trim(),
          _postOfficeCtrl.text.trim(),
          _districtCtrl.text.trim(),
          _state,
          _pincodeCtrl.text.trim(),
        ].where((part) => part.isNotEmpty).join(', '),
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
        landHa: double.tryParse(_landHaCtrl.text),
        livestock: _livestockCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim(),
        bankAcct: _bankAcctCtrl.text.trim(),
        passbookName: _passbookNameCtrl.text.trim(),
        povertyLine: _povertyLine,
        annualIncome: double.tryParse(_annualIncomeCtrl.text) ?? 0.0,
        distCenterM: double.tryParse(_distCenterMCtrl.text),
        distBranchKm: double.tryParse(_distBranchKmCtrl.text),
        relativeInCenter: _relativeInCenter,
        relativeName: _relativeNameCtrl.text.trim(),
        otherLoans: int.tryParse(_otherLoansCtrl.text),
        currentDebt: double.tryParse(_currentDebtCtrl.text),
        repayFreq: _repayFreq,
        coName: _coNameCtrl.text.trim(),
        coPhone: _coPhoneCtrl.text.trim(),
        coRelation: _coRelation,
        coIncome: double.tryParse(_coIncomeCtrl.text),
        photo: _applicantPhotoPath,
        husbandName: _husbandNameCtrl.text.trim(),
        husbandFather: _husbandFatherCtrl.text.trim(),
        husbandDob: _husbandDobCtrl.text.trim(),
        husbandAddress: _husbandSameAddr
            ? '${_houseNoCtrl.text}, ${_villageCtrl.text}, ${_districtCtrl.text}'
            : _husbandAddressCtrl.text.trim(),
        husbandPhoto: _husbandPhotoPath,
        consentGiven: _husbandConsentGiven ? 1 : 0,
        declaration: _declarationAccepted ? 1 : 0,
        bureauConsent: _bureauConsentAccepted ? 1 : 0,
        addressVerified: _addressVisited ? 1 : 0,
        family: familyData,
      );
    } catch (_) {
      success = false;
    } finally {
      if (mounted) setState(() => _isSavingKyc = false);
    }

    if (!mounted) {
      if (success) {
        _pendingAttachmentReferences.clear();
      } else {
        _discardPendingAttachments();
      }
      return;
    }

    if (success) {
      _pendingAttachmentReferences.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC form saved and sent for manual review.'),
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
            'KYC was not saved. Check the required fields and try again.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Widget _buildPhotoTile({
    required String title,
    required String? photoPath,
    required bool husbandPhoto,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _photoPreview(photoPath, husbandPhoto: husbandPhoto),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPhoto ? 'Photo selected' : 'No photo uploaded (JPG/PNG)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hasPhoto ? AppTheme.success : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.camera_alt, size: 16),
            label: const Text('Select'),
          ),
          if (hasPhoto)
            IconButton(
              tooltip: 'Remove selected photo',
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = _visibleCustomers(
      context.watch<CustomerProvider>().customers,
      context.watch<AuthProvider>().currentUser,
    );

    return Scaffold(
      appBar: const CustomAppBar(title: 'Bilingual KYC Digital Form (प्रपत्र)'),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_isSavingKyc) return;
          if (_currentStep < 3) {
            setState(() => _currentStep += 1);
          } else {
            _submitKycForm();
          }
        },
        onStepCancel: () {
          if (_isSavingKyc) return;
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
                  onPressed: _isSavingKyc ? null : details.onStepContinue,
                  child: _isSavingKyc
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _currentStep == 3 ? 'Save & Submit KYC' : 'Next Step',
                        ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isSavingKyc ? null : details.onStepCancel,
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
                  const Text(
                    'Select Customer Lead (ग्राहक चुनें) *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: _selectedCustomerId,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: customers.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.phone}) - ${c.branch}'),
                      );
                    }).toList(),
                    onChanged: _isSavingKyc
                        ? null
                        : (val) {
                            if (val == null) return;
                            final matches = customers.where(
                              (customer) => customer.id == val,
                            );
                            if (matches.isNotEmpty) {
                              _loadCustomer(matches.first);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Center No (केंद्र सं.)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _centerNoCtrl,
                              decoration: const InputDecoration(
                                hintText: 'e.g. C-101',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Group No (समूह सं.)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _groupNoCtrl,
                              decoration: const InputDecoration(
                                hintText: 'e.g. G-A',
                              ),
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
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Applicant Name (नाम) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
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
                            const Text(
                              'Mobile (मोबाइल) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
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
                            const Text(
                              'Date of Birth (जन्म तिथि) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _dobCtrl,
                              decoration: InputDecoration(
                                hintText: 'YYYY-MM-DD',
                                suffixText: _calcAge(_dobCtrl.text) == null
                                    ? 'Age: not recorded'
                                    : 'Age: ${_calcAge(_dobCtrl.text)}',
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
                            const Text(
                              'Relation of Guardian',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _guardianType,
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('Select relation'),
                                ),
                                DropdownMenuItem(
                                  value: 'husband',
                                  child: Text('Husband (पति)'),
                                ),
                                DropdownMenuItem(
                                  value: 'father',
                                  child: Text('Father (पिता)'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _guardianType = val!),
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
                      Text(
                        "${_guardianType == 'husband'
                            ? 'Husband'
                            : _guardianType == 'father'
                            ? 'Father'
                            : 'Guardian'}'s Name *",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
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
                            const Text(
                              'Education (शिक्षा) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _education,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Select education'),
                                ),
                                ..._educationOpts.map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _education = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Religion (धर्म) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _religion,
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Select religion'),
                                ),
                                ..._religionOpts.map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _religion = val!),
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
                            const Text(
                              'Category (वर्ग) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _category,
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Select category'),
                                ),
                                ..._categoryOpts.map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _category = val!),
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
                    husbandPhoto: false,
                    onPick: () => _pickImage(false),
                    onClear: () => _clearPhoto(false),
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
                            const Text(
                              'House No (मकान सं.)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
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
                            const Text(
                              'Village / Area (गाँव/नगर) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
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
                            const Text(
                              'Post Office (पोस्ट)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
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
                            const Text(
                              'District (ज़िला) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
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
                            const Text(
                              'State (राज्य) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _state,
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Select state'),
                                ),
                                ..._stateOpts.map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                ),
                              ],
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
                            const Text(
                              'PIN Code *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _pincodeCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Family Members / परिवार के सदस्य',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _familyMembers.length >= 12
                            ? null
                            : () {
                                setState(() {
                                  _familyMembers.add(
                                    FamilyMemberInput(
                                      name: '',
                                      age: '',
                                      occ: '',
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
                    separatorBuilder: (_, _) => const Divider(height: 16),
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
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppTheme.navyDark,
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: m.name,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Name / नाम',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    controller: m.age,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Age',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                if (idx > 0)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
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
                                    value: m.rel,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: '',
                                        child: Text('Select relation'),
                                      ),
                                      ..._familyRelOpts.map(
                                        (r) => DropdownMenuItem(
                                          value: r,
                                          child: Text(
                                            r,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => m.rel = val!),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: m.occ,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Occupation / व्यवसाय',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
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
                            const Text(
                              'House Type (मकान)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _houseType,
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Select house type'),
                                ),
                                ..._houseTypeOpts.map(
                                  (h) => DropdownMenuItem(
                                    value: h,
                                    child: Text(h),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _houseType = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Poverty Line (गरीबी रेखा)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _povertyLine,
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('Select status'),
                                ),
                                DropdownMenuItem(
                                  value: 'BPL',
                                  child: Text('BPL'),
                                ),
                                DropdownMenuItem(
                                  value: 'APL',
                                  child: Text('APL'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _povertyLine = val!),
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
                            const Text(
                              'Land (Hectare)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _landHaCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Livestock (पशुधन)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
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
                            const Text(
                              'Bank Name (बैंक)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
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
                            const Text(
                              'Account No (खाता सं.)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _bankAcctCtrl,
                              keyboardType: TextInputType.number,
                              obscureText: _obscureBankAccount,
                              decoration: InputDecoration(
                                hintText: _savedBankAccountMask == null
                                    ? 'Optional'
                                    : 'Saved ${_savedBankAccountMask!}; blank keeps it',
                                helperText: 'Enter a value only to replace it',
                                suffixIcon: IconButton(
                                  tooltip: _obscureBankAccount
                                      ? 'Show account number'
                                      : 'Hide account number',
                                  icon: Icon(
                                    _obscureBankAccount
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(() {
                                    _obscureBankAccount = !_obscureBankAccount;
                                  }),
                                ),
                              ),
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
                            const Text(
                              'Dist to Center (m)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _distCenterMCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dist to Branch (km)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _distBranchKmCtrl,
                              keyboardType: TextInputType.number,
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
                            const Text(
                              'Annual Income (वार्षिक आय ₹) *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _annualIncomeCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Repay Frequency',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _repayFreq,
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('Select frequency'),
                                ),
                                DropdownMenuItem(
                                  value: 'monthly',
                                  child: Text('Monthly'),
                                ),
                                DropdownMenuItem(
                                  value: 'weekly',
                                  child: Text('Weekly'),
                                ),
                                DropdownMenuItem(
                                  value: 'biweekly',
                                  child: Text('Bi-Weekly'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _repayFreq = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Co-Applicant Details (सह-आवेदक)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _coNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name (नाम)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _coPhoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mobile',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _coRelation,
                          decoration: const InputDecoration(
                            labelText: 'Relation with applicant',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Select relation'),
                            ),
                            ..._coRelationOpts.map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _coRelation = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _coIncomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Monthly Income (₹)',
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
                              Text(
                                'Husband Information & Loan Consent',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'मैं, ${_guardianNameCtrl.text}, प्रमाणित करता हूँ कि श्रीमती ${_nameCtrl.text} मेरी पत्नी हैं। मैं अपने परिवार की व्यावसायिक वृद्धि के लिए उन्हें सर्वोच्च माइक्रोकेयर फाउंडेशन से ऋण लेने की सहमति देता हूँ। मैं उनके केन्द्र बैठक में समय से जाने तथा समय से ऋण अदायगी के लिए जिम्मेदार रहूँगा।',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.brown.shade800,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _husbandFatherCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Husband\'s Father\'s Name (ससुर का नाम)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _husbandDobCtrl,
                            decoration: InputDecoration(
                              labelText: 'Husband DOB (जन्म तिथि)',
                              suffixText: _calcAge(_husbandDobCtrl.text) == null
                                  ? 'Age: not recorded'
                                  : 'Age: ${_calcAge(_husbandDobCtrl.text)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _husbandSameAddr,
                      onChanged: (val) =>
                          setState(() => _husbandSameAddr = val!),
                      title: const Text(
                        'Husband address is same as applicant address',
                        style: TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (!_husbandSameAddr)
                      TextField(
                        controller: _husbandAddressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Husband Residence Address',
                        ),
                      ),
                    const SizedBox(height: 10),
                    _buildPhotoTile(
                      title: 'Husband Photo (पति का फोटो)',
                      photoPath: _husbandPhotoPath,
                      husbandPhoto: true,
                      onPick: () => _pickImage(true),
                      onClear: () => _clearPhoto(true),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _husbandConsentGiven,
                      onChanged: (val) =>
                          setState(() => _husbandConsentGiven = val!),
                      title: const Text(
                        'The husband has read / heard the consent declaration and agrees. *',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const Divider(height: 24),
                  ],
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _declarationAccepted,
                    onChanged: (val) =>
                        setState(() => _declarationAccepted = val!),
                    title: const Text(
                      'I declare that all information given in this form is complete and correct. (मैं घोषणा करता/करती हूँ कि इस प्रपत्र में दी गई सभी जानकारी पूर्णतया सही है) *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _bureauConsentAccepted,
                    onChanged: (val) =>
                        setState(() => _bureauConsentAccepted = val!),
                    title: const Text(
                      'I agree that credit information may be shared with credit bureaus and insurance companies. (क्रेडिट ब्यूरो एवं बीमा कंपनी सहमति)',
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.navyDark,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
        ],
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
