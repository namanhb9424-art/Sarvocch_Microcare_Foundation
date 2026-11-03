import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query('customers', orderBy: 'name ASC');
    if (mounted) {
      setState(() {
        _customers = results;
        _loading = false;
      });
    }
  }

  Future<void> _sendWhatsAppOtp(int customerId, String name, String phone) async {
    final otp = '${Random().nextInt(900000) + 100000}';
    final db = await DatabaseHelper.instance.database;
    await db.update('customers', {'wa_otp': otp}, where: 'id = ?', whereArgs: [customerId]);
    await _loadCustomers();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Text('WhatsApp OTP: $name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generated 6-digit OTP code for +91 $phone:'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF8C6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF25D366)),
              ),
              child: Center(
                child: Text(
                  otp,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4, color: Color(0xFF075E54)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Simulated WhatsApp text:\n"Hello $name, your SARVOOCCH Microcare verification code is $otp. Reply to confirm."',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Verify Now'),
            onPressed: () {
              Navigator.pop(ctx);
              _showVerifyDialog(customerId, otp);
            },
          ),
        ],
      ),
    );
  }

  void _showVerifyDialog(int customerId, String correctOtp) {
    final otpCtrl = TextEditingController(text: correctOtp);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify WhatsApp Number'),
        content: TextField(
          controller: otpCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Enter 6-digit WhatsApp OTP'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (otpCtrl.text.trim() == correctOtp) {
                final db = await DatabaseHelper.instance.database;
                final nowIso = DateTime.now().toIso8601String().substring(0, 19);
                final auth = context.read<AuthProvider>();

                await db.update('customers', {'wa_verified': 1, 'wa_otp': null}, where: 'id = ?', whereArgs: [customerId]);
                await db.insert('comm_logs', {
                  'customer_id': customerId,
                  'channel': 'whatsapp',
                  'note': 'WhatsApp mobile number verified via OTP',
                  'by_name': auth.currentUser?.name ?? 'Field Officer',
                  'at': nowIso,
                });

                if (ctx.mounted) Navigator.pop(ctx);
                await _loadCustomers();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('WhatsApp number verified successfully!'), backgroundColor: AppTheme.success),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid OTP code. Please re-check.'), backgroundColor: AppTheme.danger),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'WhatsApp Communication Hub'),
      drawer: const CustomDrawer(currentRoute: '/whatsapp'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _customers.length,
              itemBuilder: (ctx, i) {
                final c = _customers[i];
                final isVerified = (c['wa_verified'] as int? ?? 0) == 1;
                final hasPendingOtp = c['wa_otp'] != null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isVerified ? const Color(0xFFDCF8C6) : AppTheme.background,
                      child: Icon(
                        Icons.chat,
                        color: isVerified ? const Color(0xFF25D366) : AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                    title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text('Phone: +91 ${c['phone']} • ${c['branch']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          isVerified ? 'VERIFIED WHATSAPP NUMBER' : hasPendingOtp ? 'OTP Sent (Pending Verification)' : 'Not Verified',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isVerified ? AppTheme.success : hasPendingOtp ? Colors.orange.shade800 : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    trailing: isVerified
                        ? const Icon(Icons.verified, color: AppTheme.success, size: 22)
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.send, size: 14),
                            label: const Text('Send OTP', style: TextStyle(fontSize: 12)),
                            onPressed: () => _sendWhatsAppOtp(c['id'] as int, c['name'] as String, c['phone'] as String),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
