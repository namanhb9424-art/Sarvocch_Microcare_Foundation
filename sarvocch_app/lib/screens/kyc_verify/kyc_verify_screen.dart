import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final _aadhaarCtrl = TextEditingController(text: '234567890123');
  final _panCtrl = TextEditingController(text: 'ABCPE1234F');
  final _voterCtrl = TextEditingController(text: 'MP0123405');
  final _otpCtrl = TextEditingController(text: '123456');

  bool _isAadhaarValid = true;
  bool _isPanValid = true;
  String? _verificationResult;

  @override
  void initState() {
    super.initState();
    final customers = context.read<CustomerProvider>().customers;
    if (customers.isNotEmpty) {
      _selectedCustomerId = customers.first.id;
    }
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

  Future<void> _verifyDocs() async {
    if (_selectedCustomerId == null) return;
    if (!_isAadhaarValid || !_isPanValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct invalid document formats')),
      );
      return;
    }

    final success = await context.read<CustomerProvider>().verifyKycDocuments(
          customerId: _selectedCustomerId!,
          aadhaar: _aadhaarCtrl.text.trim(),
          pan: _panCtrl.text.trim(),
          voter: _voterCtrl.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      setState(() {
        _verificationResult = 'Identity Verified: NSDL & UIDAI Mock Handshake Passed 200 OK.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KYC documents verified successfully!'), backgroundColor: AppTheme.success),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_selectedCustomerId == null) return;
    final success = await context.read<CustomerProvider>().verifyWhatsAppOtp(
          _selectedCustomerId!,
          _otpCtrl.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp OTP (123456) Verified!'), backgroundColor: AppTheme.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Use demo OTP: 123456'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;

    return Scaffold(
      appBar: const CustomAppBar(title: 'KYC Document Verification'),
      drawer: const CustomDrawer(currentRoute: '/kyc'),
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
                border: Border.all(color: AppTheme.tealPrimary.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.tealPrimary, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'UIDAI, NSDL PAN, & WhatsApp OTP Verification Simulation. Zero external paid APIs required.',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.tealDark),
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
                    const Text('SELECT CUSTOMER TO VERIFY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _selectedCustomerId,
                      decoration: const InputDecoration(labelText: 'Customer *'),
                      items: customers.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.name} (${c.phone}) - ${c.kycStatus.toUpperCase()}'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCustomerId = val),
                    ),
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
                    const Text('DOCUMENT NUMBERS & FORMAT CHECK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 14),

                    // Aadhaar
                    TextField(
                      controller: _aadhaarCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: _validateAadhaar,
                      decoration: InputDecoration(
                        labelText: 'Aadhaar Number (12 Digits) *',
                        prefixIcon: const Icon(Icons.fingerprint),
                        suffixIcon: Icon(
                          _isAadhaarValid ? Icons.check_circle : Icons.error,
                          color: _isAadhaarValid ? AppTheme.success : AppTheme.danger,
                        ),
                        errorText: _isAadhaarValid ? null : 'Aadhaar must be exactly 12 digits',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // PAN
                    TextField(
                      controller: _panCtrl,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: _validatePan,
                      decoration: InputDecoration(
                        labelText: 'PAN Card (ABCPE1234F format) *',
                        prefixIcon: const Icon(Icons.credit_card),
                        suffixIcon: Icon(
                          _isPanValid ? Icons.check_circle : Icons.error,
                          color: _isPanValid ? AppTheme.success : AppTheme.danger,
                        ),
                        errorText: _isPanValid ? null : 'Invalid PAN format: 5 letters, 4 digits, 1 letter',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Voter ID
                    TextField(
                      controller: _voterCtrl,
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
                        label: const Text('Verify Identity Documents'),
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
                            const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _verificationResult!,
                                style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600),
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

            // WhatsApp OTP Mock Verification Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WHATSAPP MOBILE OTP VERIFICATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    const Text(
                      'Sends an automated OTP to borrower WhatsApp for e-sign verification.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Demo OTP (Enter 123456)',
                              prefixIcon: Icon(Icons.message_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _verifyOtp,
                          child: const Text('Verify OTP'),
                        ),
                      ],
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
}
