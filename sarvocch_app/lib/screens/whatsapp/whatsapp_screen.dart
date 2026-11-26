import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../services/sync_service.dart';
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCustomers();
    });
  }

  Future<void> _loadCustomers() async {
    if (mounted) setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final results = await db.rawQuery(
        '''
        SELECT c.*
        FROM customers c
        JOIN users actor ON actor.id = ?
        WHERE actor.auth_status = 'active'
          AND (
            actor.role = 'admin'
            OR (actor.role IN ('manager', 'underwriter')
                AND trim(actor.branch) <> '' AND c.branch = actor.branch)
            OR (actor.role = 'field_agent' AND c.agent_id = actor.id
                AND trim(actor.branch) <> '' AND c.branch = actor.branch)
          )
        ORDER BY c.name ASC
        ''',
        [user.id],
      );
      if (mounted) {
        setState(() {
          _customers = results.map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncAndReload() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await SyncService().triggerFullSync(userId: user.id);
    if (!mounted) return;
    await _loadCustomers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SyncService().lastSyncStatus)),
      );
    }
  }

  Future<void> _openComposerDialog(Map<String, dynamic> c) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final custId = c['id'] as int;
    final name = (c['name'] as String?) ?? 'Borrower';
    final phone = (c['phone'] as String?) ?? '';
    final isVerified = (c['wa_verified'] as int? ?? 0) == 1;
    final msgCtrl = TextEditingController(
      text:
          'Namaste $name ji, this is a reminder from SARVOOCCH Microcare Foundation regarding your upcoming EMI / center meeting. Kindly keep your installment ready.',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'WhatsApp: $name',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mobile: $phone (${isVerified ? 'Verified' : 'Pending Verification'})',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('EMI Reminder', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      msgCtrl.text =
                          'Namaste $name ji, your SARVOOCCH EMI installment is due. Please pay on time to maintain a strong credit score.';
                    },
                  ),
                  ActionChip(
                    label: const Text('Center Meeting', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      msgCtrl.text =
                          'Namaste $name ji, reminder for your SARVOOCCH Center Meeting tomorrow at 10:00 AM with passbook.';
                    },
                  ),
                  ActionChip(
                    label: const Text('KYC Update', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      msgCtrl.text =
                          'Namaste $name ji, kindly keep your original Aadhaar & PAN ready for SARVOOCCH KYC verification.';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message Content *',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share App'),
            onPressed: () async {
              final text = msgCtrl.text.trim();
              if (text.isEmpty) return;
              await context.read<CustomerProvider>().sendWhatsAppNotice(
                    customerId: custId,
                    actorUserId: user.id,
                    message: text,
                  );
              await SharePlus.instance.share(
                ShareParams(text: text, subject: 'SARVOOCCH Notice for $name'),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Log & Send'),
            onPressed: () async {
              final text = msgCtrl.text.trim();
              if (text.isEmpty) return;
              final ok = await context.read<CustomerProvider>().sendWhatsAppNotice(
                    customerId: custId,
                    actorUserId: user.id,
                    message: text,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'WhatsApp communication logged & queued for cloud sync.'
                          : 'Could not log notification.',
                    ),
                    backgroundColor: ok ? AppTheme.success : AppTheme.danger,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
    msgCtrl.dispose();
  }

  Future<void> _confirmPhone(Map<String, dynamic> c) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final custId = c['id'] as int;
    final name = (c['name'] as String?) ?? 'Borrower';
    final phone = (c['phone'] as String?) ?? '';

    if (kDebugMode) {
      await _sendWhatsAppOtp(custId, name, phone);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Borrower WhatsApp'),
        content: Text(
          'Confirm that mobile number $phone belongs to $name and receives WhatsApp / SMS notices?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Verify'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<CustomerProvider>().confirmWhatsAppVerified(
          customerId: custId,
          actorUserId: user.id,
        );
    if (!mounted) return;
    await _loadCustomers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '$name WhatsApp number marked verified & queued for sync.'
              : 'Verification could not be recorded.',
        ),
        backgroundColor: ok ? AppTheme.success : AppTheme.danger,
      ),
    );
  }

  Future<void> _sendWhatsAppOtp(int custId, String name, String phone) async {
    if (!kDebugMode) return;
    final otp = '${Random().nextInt(900000) + 100000}';
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'WhatsApp OTP: $name',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Development-only OTP value:',
            ),
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
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xFF075E54),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Verify OTP'),
            onPressed: () {
              Navigator.pop(ctx);
              _showVerifyDialog(custId, otp);
            },
          ),
        ],
      ),
    );
  }

  void _showVerifyDialog(int custId, String correctOtp) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify WhatsApp Number'),
        content: TextField(
          controller: otpCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter 6-digit WhatsApp OTP',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (otpCtrl.text.trim() == correctOtp) {
                final user = context.read<AuthProvider>().currentUser;
                if (user != null) {
                  await context.read<CustomerProvider>().confirmWhatsAppVerified(
                        customerId: custId,
                        actorUserId: user.id,
                      );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadCustomers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('WhatsApp number verified.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid OTP code. Please re-check.'),
                    backgroundColor: AppTheme.danger,
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

  @override
  Widget build(BuildContext context) {
    final filtered = _customers.where((c) {
      final q = _searchQuery.toLowerCase();
      return q.isEmpty ||
          (c['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (c['phone']?.toString().contains(q) ?? false) ||
          (c['branch']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
    final verifiedCount =
        _customers.where((c) => (c['wa_verified'] as int? ?? 0) == 1).length;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'WhatsApp Communication Hub',
        actions: [
          IconButton(
            tooltip: 'Sync Contacts',
            icon: const Icon(Icons.refresh),
            onPressed: _syncAndReload,
          ),
        ],
      ),
      drawer: const CustomDrawer(currentRoute: '/whatsapp'),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search borrower by name, phone, branch...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _summaryBadge(
                      'Borrowers: ${_customers.length}',
                      AppTheme.tealSurface,
                      AppTheme.tealDark,
                    ),
                    const SizedBox(width: 8),
                    _summaryBadge(
                      'Verified: $verifiedCount',
                      AppTheme.successLight,
                      AppTheme.success,
                    ),
                    const SizedBox(width: 8),
                    _summaryBadge(
                      'Pending: ${_customers.length - verifiedCount}',
                      AppTheme.warningLight,
                      Colors.orange.shade900,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _customers.isEmpty
                                ? 'No borrowers found in your branch'
                                : 'No borrowers match "$_searchQuery"',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add customers in CRM or sync from Hostinger Cloud to send WhatsApp payment & meeting reminders.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _syncAndReload,
                            icon: const Icon(Icons.cloud_sync),
                            label: const Text('Sync Borrowers from Cloud'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _syncAndReload,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        final isVerified = (c['wa_verified'] as int? ?? 0) == 1;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isVerified
                                          ? const Color(0xFFDCF8C6)
                                          : AppTheme.background,
                                      child: Icon(
                                        Icons.chat,
                                        color: isVerified
                                            ? const Color(0xFF25D366)
                                            : AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['name'] as String? ?? 'Borrower',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Phone: ${c['phone']} • ${c['branch']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isVerified
                                            ? AppTheme.successLight
                                            : AppTheme.warningLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isVerified ? 'VERIFIED' : 'UNVERIFIED',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isVerified
                                              ? AppTheme.success
                                              : Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.send, size: 15),
                                        label: const Text(
                                          'Send Notice',
                                          style: TextStyle(fontSize: 12.5),
                                        ),
                                        onPressed: () => _openComposerDialog(c),
                                      ),
                                    ),
                                    if (!isVerified) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF25D366),
                                          ),
                                          icon: const Icon(Icons.verified_user,
                                              size: 15),
                                          label: const Text(
                                            'Verify Phone',
                                            style: TextStyle(fontSize: 12.5),
                                          ),
                                          onPressed: () => _confirmPhone(c),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
