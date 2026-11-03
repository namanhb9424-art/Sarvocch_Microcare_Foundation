import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/cloud_quote_model.dart';
import '../../providers/cloud_quote_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class CloudQuotationScreen extends StatefulWidget {
  const CloudQuotationScreen({super.key});

  @override
  State<CloudQuotationScreen> createState() => _CloudQuotationScreenState();
}

class _CloudQuotationScreenState extends State<CloudQuotationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyInr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  // Connection form controllers
  final _endpointCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _projectRefCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final quotes = context.read<CloudQuoteProvider>().quotes;
    _tabController = TabController(length: quotes.length, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _prefillEndpoint(quotes[_tabController.index]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (quotes.isNotEmpty) {
        _prefillEndpoint(quotes.first);
      }
    });
  }

  void _prefillEndpoint(CloudDatabaseQuoteModel quote) {
    final active = context.read<CloudQuoteProvider>().activeConnection;
    if (active != null && active['provider_id'] == quote.id) {
      _endpointCtrl.text = active['endpoint_url'] ?? quote.defaultEndpointTemplate;
      _apiKeyCtrl.text = active['api_key'] ?? '';
      _projectRefCtrl.text = active['project_ref'] ?? '';
    } else {
      _endpointCtrl.text = quote.defaultEndpointTemplate;
      _apiKeyCtrl.text = 'demo-sarvocch-token-key-2026';
      _projectRefCtrl.text = 'sarvocch-mp-${quote.id}';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _endpointCtrl.dispose();
    _apiKeyCtrl.dispose();
    _projectRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _testAndConnect(String providerId) async {
    final cloudProv = context.read<CloudQuoteProvider>();
    final result = await cloudProv.testAndSaveConnection(
      providerId: providerId,
      endpointUrl: _endpointCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      projectRef: _projectRefCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success),
              SizedBox(width: 8),
              Text('Connection Verified 200 OK', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result['message'] as String),
              const SizedBox(height: 10),
              Text('Latency: ${result['latency_ms']}ms to ap-south-1 Mumbai data center.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              const Text('Website and Flutter app are now linked to the cloud database pool.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Great')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloudProv = context.watch<CloudQuoteProvider>();
    final quotes = cloudProv.quotes;
    final active = cloudProv.activeConnection;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Cloud Database Quotations & Sync'),
      drawer: const CustomDrawer(currentRoute: '/cloud-quotes'),
      body: Column(
        children: [
          // Banner explaining seamless website + application connection
          Container(
            color: AppTheme.tealPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seamless Web & Mobile Cloud Sync Quotations',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      Text(
                        'Compare pricing, capacity & directly connect SQLite to Cloud backend.',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Provider Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.tealPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.tealPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: quotes.map((q) => Tab(text: q.providerName.split('(').first.trim())).toList(),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: quotes.map((quote) => _buildQuoteDetails(quote, active, cloudProv)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteDetails(
    CloudDatabaseQuoteModel quote,
    Map<String, dynamic>? active,
    CloudQuoteProvider cloudProv,
  ) {
    final isCurrentlyConnected = active != null && active['provider_id'] == quote.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.tealSurface,
                            child: const Icon(Icons.cloud_outlined, color: AppTheme.tealPrimary),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(quote.providerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                              Text(quote.category, style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      if (isCurrentlyConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(4)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: AppTheme.success),
                              SizedBox(width: 4),
                              Text('CONNECTED', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 10)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(quote.tagLine, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 10),
                  const Text('SUITABILITY FOR SARVOCCH PORTAL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(quote.suitability, style: const TextStyle(fontSize: 12.5, height: 1.35)),
                  const SizedBox(height: 10),
                  const Text('SYNC ARCHITECTURE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(quote.syncArchitecture, style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.tealDark)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Subscription Plans Quotations
          const Text(
            'SUBSCRIPTION PLANS & PRICING QUOTATION',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          Column(
            children: quote.plans.map((tier) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: tier.isRecommended ? AppTheme.tealPrimary : AppTheme.border,
                    width: tier.isRecommended ? 1.8 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tier.tierName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          if (tier.isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.tealPrimary, borderRadius: BorderRadius.circular(4)),
                              child: const Text('RECOMMENDED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            tier.priceMonthlyUsd == 0 ? 'Free' : '\$${tier.priceMonthlyUsd.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.tealPrimary),
                          ),
                          const SizedBox(width: 4),
                          Text('/ month', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          if (tier.priceMonthlyInr > 0)
                            Text(
                              '(${currencyInr.format(tier.priceMonthlyInr)} / mo approx)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 10),
                      _specRow('Database & File Storage', tier.storageGb),
                      _specRow('Compute & Operations', tier.readWriteQuota),
                      _specRow('Egress Bandwidth', tier.egressGb),
                      _specRow('Concurrency Limit', tier.concurrency),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: tier.highlights.map((h) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check, size: 14, color: AppTheme.success),
                                const SizedBox(width: 6),
                                Expanded(child: Text(h, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Live Connection & Credentials Setup Card
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SEAMLESS CONNECTION SETUP',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                      ),
                      const Icon(Icons.link, color: AppTheme.tealPrimary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _endpointCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cloud API Endpoint / Connection URI *',
                      helperText: 'Connects website and mobile client to same DB pool',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _projectRefCtrl,
                          decoration: const InputDecoration(labelText: 'Project Reference / ID'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _apiKeyCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Secret API Key / Token'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: cloudProv.isLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: const Text('Test & Link Cloud DB'),
                          onPressed: cloudProv.isLoading ? null : () => _testAndConnect(quote.id),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: cloudProv.isSyncing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync, size: 18),
                          label: const Text('Trigger Live Sync'),
                          onPressed: cloudProv.isSyncing ? null : () => cloudProv.triggerCloudSync(),
                        ),
                      ),
                    ],
                  ),

                  if (cloudProv.isSyncing || cloudProv.syncProgress < 1.0) ...[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: cloudProv.syncProgress, color: AppTheme.tealPrimary),
                    const SizedBox(height: 6),
                    Text(
                      cloudProv.syncStatusMessage,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.tealDark, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
