import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../models/customer_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class KycVerifyScreen extends StatefulWidget {
  const KycVerifyScreen({super.key});

  @override
  State<KycVerifyScreen> createState() => _KycVerifyScreenState();
}

class _KycVerifyScreenState extends State<KycVerifyScreen> {
  int? _selectedCustomerId;
  final _aadhaarCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _voterCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _reviewRemarksCtrl = TextEditingController();

  bool _isAadhaarValid = false;
  bool _isPanValid = false;
  bool _originalDocumentsChecked = false;
  String? _verificationResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      final custProv = context.read<CustomerProvider>();
      if (user != null && custProv.customers.isEmpty && !custProv.isLoading) {
        custProv.fetchCustomers(actorUserId: user.id);
      }
    });
  }

  void _validateAadhaar(String val) {
    final clean = val.replaceAll(' ', '');
    setState(() {
      _isAadhaarValid = clean.length == 12 && int.tryParse(clean) != null;
    });
  }

  void _validatePan(String val) {
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
    setState(() {
      _isPanValid = panRegex.hasMatch(val.toUpperCase().trim());
    });
  }

  @override
  void dispose() {
    _aadhaarCtrl.clear();
    _panCtrl.clear();
    _voterCtrl.clear();
    _otpCtrl.clear();
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    _voterCtrl.dispose();
    _otpCtrl.dispose();
    _reviewRemarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyDocs() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first.')),
      );
      return;
    }
    if (!_isAadhaarValid || !_isPanValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 12-digit Aadhaar and 10-character PAN (e.g. ABCPE1234F).'),
        ),
      );
      return;
    }

    final customerId = _selectedCustomerId!;
    final actorUserId = context.read<AuthProvider>().currentUser?.id ?? 0;
    final aadhaar = _aadhaarCtrl.text.trim();
    final pan = _panCtrl.text.trim();
    final voter = _voterCtrl.text.trim();
    final success = await context.read<CustomerProvider>().verifyKycDocuments(
      customerId: customerId,
      actorUserId: actorUserId,
      aadhaar: aadhaar,
      pan: pan,
      voter: voter,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _aadhaarCtrl.clear();
        _panCtrl.clear();
        _voterCtrl.clear();
        _isAadhaarValid = false;
        _isPanValid = false;
        _verificationResult =
            'Document values recorded securely. Complete the Separate KYC Review below (by a reviewer other than the KYC form author) to mark KYC Verified.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Document values recorded. Ready for separate manual review.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Documents could not be saved. Check branch access and customer KYC status.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _confirmPhoneVerification() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first.')),
      );
      return;
    }
    final actorUserId = context.read<AuthProvider>().currentUser?.id;
    if (actorUserId == null) return;

    if (kDebugMode && _otpCtrl.text.trim().isNotEmpty) {
      final success = await context.read<CustomerProvider>().verifyWhatsAppOtp(
        customerId: _selectedCustomerId!,
        otp: _otpCtrl.text.trim(),
        actorUserId: actorUserId,
      );
      _otpCtrl.clear();
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The development OTP did not match (expected 123456).'),
            backgroundColor: AppTheme.danger,
          ),
        );
        return;
      }
    }

    final confirmed = await context.read<CustomerProvider>().confirmWhatsAppVerified(
          customerId: _selectedCustomerId!,
          actorUserId: actorUserId,
        );
    _otpCtrl.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          confirmed
              ? 'Borrower mobile / WhatsApp confirmed and queued for cloud sync.'
              : 'Could not confirm borrower mobile.',
        ),
        backgroundColor: confirmed ? AppTheme.success : AppTheme.danger,
      ),
    );
  }

  Future<void> _approveKyc() async {
    final reviewerId = context.read<AuthProvider>().currentUser?.id;
    if (_selectedCustomerId == null || reviewerId == null) return;

    final success = await context.read<CustomerProvider>().approveKyc(
      customerId: _selectedCustomerId!,
      reviewerId: reviewerId,
      remarks: _reviewRemarksCtrl.text,
      originalDocumentsChecked: _originalDocumentsChecked,
    );
    if (!mounted) return;

    setState(() {
      _verificationResult = success
          ? 'KYC approved after a separate manual review. No issuer database was queried.'
          : 'KYC approval was not recorded. Check reviewer permissions, maker-checker, consent and field-visit status.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'KYC manually approved.' : 'KYC approval failed.',
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final customers = _visibleCustomers(
      context.watch<CustomerProvider>().customers,
      currentUser,
    );
    final canReviewKyc = {
      'admin',
      'manager',
      'underwriter',
    }.contains(currentUser?.role);
    final selectedCustomer =
        customers.any((customer) => customer.id == _selectedCustomerId)
        ? customers.firstWhere((customer) => customer.id == _selectedCustomerId)
        : null;

    return Scaffold(
      appBar: const CustomAppBar(title: 'KYC Document Verification'),
      drawer: const CustomDrawer(currentRoute: '/kyc-verify'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.tealSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.tealPrimary.withOpacity(0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppTheme.tealPrimary,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Step 1: Record Aadhaar/PAN documents -> Step 2: Confirm borrower phone/WhatsApp -> Step 3: Separate Manager/Underwriter manual review & approval.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.tealDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Customer Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECT CUSTOMER TO VERIFY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: selectedCustomer?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Customer *',
                      ),
                      items: customers.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.name} (${c.phone}) - ${c.kycStatus.toUpperCase()}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCustomerId = val),
                    ),
                    if (selectedCustomer != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text(
                              'KYC: ${selectedCustomer.kycStatus.toUpperCase()}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            backgroundColor:
                                selectedCustomer.kycStatus == 'verified'
                                ? AppTheme.successLight
                                : AppTheme.warningLight,
                          ),
                          if (selectedCustomer.aadhaar != null &&
                              selectedCustomer.aadhaar!.isNotEmpty)
                            Chip(
                              label: Text(
                                'Aadhaar: ${selectedCustomer.aadhaar}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          if (selectedCustomer.pan != null &&
                              selectedCustomer.pan!.isNotEmpty)
                            Chip(
                              label: Text(
                                'PAN: ${selectedCustomer.pan}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          Chip(
                            label: Text(
                              selectedCustomer.waVerified == 1
                                  ? 'Phone / WhatsApp Verified'
                                  : 'Phone Unverified',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Document Fields Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DOCUMENT NUMBERS & FORMAT CHECK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Aadhaar
                    TextField(
                      controller: _aadhaarCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      onChanged: _validateAadhaar,
                      decoration: InputDecoration(
                        labelText: 'Aadhaar Number (12 Digits) *',
                        prefixIcon: const Icon(Icons.fingerprint),
                        suffixIcon: _aadhaarCtrl.text.isEmpty
                            ? null
                            : Icon(
                                _isAadhaarValid
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _isAadhaarValid
                                    ? AppTheme.success
                                    : AppTheme.danger,
                              ),
                        errorText:
                            _aadhaarCtrl.text.isNotEmpty && !_isAadhaarValid
                            ? 'Aadhaar must be exactly 12 digits'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // PAN
                    TextField(
                      controller: _panCtrl,
                      textCapitalization: TextCapitalization.characters,
                      obscureText: true,
                      onChanged: _validatePan,
                      decoration: InputDecoration(
                        labelText: 'PAN Card (ABCPE1234F format) *',
                        prefixIcon: const Icon(Icons.credit_card),
                        suffixIcon: _panCtrl.text.isEmpty
                            ? null
                            : Icon(
                                _isPanValid ? Icons.check_circle : Icons.error,
                                color: _isPanValid
                                    ? AppTheme.success
                                    : AppTheme.danger,
                              ),
                        errorText: _panCtrl.text.isNotEmpty && !_isPanValid
                            ? 'Invalid PAN format: 5 letters, 4 digits, 1 letter'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Voter ID
                    TextField(
                      controller: _voterCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Voter ID (EPIC Number)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.verified, size: 18),
                        label: const Text('Record Documents for Manual Review'),
                        onPressed: _verifyDocs,
                      ),
                    ),

                    if (_verificationResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.successLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.success,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _verificationResult!,
                                style: const TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (canReviewKyc && selectedCustomer?.kycStatus == 'pending') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SEPARATE KYC REVIEW',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Review the applicant’s original documents and field visit record in person. This approval is a staff attestation; no government issuer service is connected.',
                        style: TextStyle(fontSize: 12),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _originalDocumentsChecked,
                        onChanged: (value) => setState(
                          () => _originalDocumentsChecked = value ?? false,
                        ),
                        title: const Text(
                          'I checked the original identity documents and consent record.',
                          style: TextStyle(fontSize: 12),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      TextField(
                        controller: _reviewRemarksCtrl,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Review notes *',
                          hintText:
                              'Record what was checked and any exceptions.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _originalDocumentsChecked &&
                                  _reviewRemarksCtrl.text.trim().length >= 10
                              ? _approveKyc
                              : null,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Approve KYC After Review'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Borrower Phone & WhatsApp Confirmation Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BORROWER MOBILE & WHATSAPP VERIFICATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedCustomer == null
                          ? 'Select a customer above to confirm phone / WhatsApp reachability.'
                          : selectedCustomer.waVerified == 1
                          ? 'Borrower mobile (${selectedCustomer.phone}) is verified for WhatsApp & SMS alerts.'
                          : 'Verify borrower phone (${selectedCustomer.phone}) after call/WhatsApp check.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (kDebugMode) ...[
                      TextField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Optional Dev OTP (123456)',
                          prefixIcon: Icon(Icons.message_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                        ),
                        onPressed: selectedCustomer == null ||
                                selectedCustomer.waVerified == 1
                            ? null
                            : _confirmPhoneVerification,
                        icon: const Icon(Icons.verified_user, size: 18),
                        label: Text(
                          selectedCustomer?.waVerified == 1
                              ? 'WhatsApp / Mobile Verified'
                              : 'Confirm Borrower Mobile / WhatsApp',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
