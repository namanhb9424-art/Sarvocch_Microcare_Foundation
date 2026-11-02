import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../theme/app_theme.dart';

class CrmDetailScreen extends StatefulWidget {
  final CustomerModel customer;

  const CrmDetailScreen({super.key, required this.customer});

  @override
  State<CrmDetailScreen> createState() => _CrmDetailScreenState();
}

class _CrmDetailScreenState extends State<CrmDetailScreen> {
  final _noteCtrl = TextEditingController();
  String _channel = 'call';
  List<CommLogModel> _logs = [];
  bool _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final list = await context.read<CustomerProvider>().getCommLogs(widget.customer.id);
    if (mounted) {
      setState(() {
        _logs = list;
        _loadingLogs = false;
      });
    }
  }

  Future<void> _addLog() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    await context.read<CustomerProvider>().addCommLog(
          customerId: widget.customer.id,
          channel: _channel,
          note: _noteCtrl.text.trim(),
          byName: auth.currentUser?.name ?? 'Field Officer',
        );
    _noteCtrl.clear();
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'Apply Loan',
            onPressed: () => Navigator.pushNamed(context, '/apply', arguments: c.id),
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'KYC Form',
            onPressed: () => Navigator.pushNamed(context, '/kyc-form', arguments: c.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Customer Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.tealSurface,
                          child: Text(
                            c.name.isNotEmpty ? c.name[0] : 'C',
                            style: const TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                              const SizedBox(height: 2),
                              Text(c.phone, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${c.branch} • Stage: ${c.stage.toUpperCase()}',
                                  style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildProfileStat('Aadhaar', c.aadhaar ?? 'Not Added'),
                        _buildProfileStat('PAN', c.pan ?? 'Not Added'),
                        _buildProfileStat('KYC Status', c.kycStatus.toUpperCase()),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Family & Address Summary Card (From Bilingual KYC form)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BILINGUAL KYC & LIVING DETAILS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _detailRow('Address', c.address),
                    _detailRow('Center & Group', '${c.centerNo ?? "C-101"} / ${c.groupNo ?? "G-A"}'),
                    _detailRow('Husband / Guardian', '${c.guardianType ?? "husband"}: ${c.husbandName ?? c.guardianName ?? "Ramesh Verma"}'),
                    _detailRow('Husband Consent', c.consentGiven == 1 ? 'Consent Signed with OTP' : 'Pending Consent'),
                    _detailRow('House Type', c.houseType ?? 'pucca'),
                    _detailRow('Bank Account', '${c.bankName ?? "SBI"} - ${c.bankAcct ?? "30123456780"}'),
                    _detailRow('Annual Income', '₹${c.annualIncome?.toStringAsFixed(0) ?? "2,16,000"} / year'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Add Interaction Log
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOG FIELD INTERACTION / CALL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _channel,
                          items: const [
                            DropdownMenuItem(value: 'call', child: Text('Call')),
                            DropdownMenuItem(value: 'visit', child: Text('Visit')),
                            DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                          ],
                          onChanged: (val) => setState(() => _channel = val!),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Enter observation / discussion note...',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addLog,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                          child: const Icon(Icons.send, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Timeline of past communications
            const Text(
              'INTERACTION TIMELINE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),

            _loadingLogs
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('No interaction records yet.', style: TextStyle(color: AppTheme.textSecondary))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.tealSurface,
                                child: Icon(
                                  log.channel == 'call'
                                      ? Icons.phone
                                      : log.channel == 'visit'
                                          ? Icons.directions_walk
                                          : Icons.chat,
                                  size: 16,
                                  color: AppTheme.tealPrimary,
                                ),
                              ),
                              title: Text(log.note, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(
                                '${log.byName} • ${log.at.replaceRange(16, log.at.length, "")}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
        ],
      ),
    );
  }
}
