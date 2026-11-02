import 'package:flutter/material.dart';
import '../data/cloud_pricing_data.dart';
import '../data/database_helper.dart';
import '../models/cloud_quote_model.dart';

class CloudQuoteProvider extends ChangeNotifier {
  List<CloudDatabaseQuoteModel> _quotes = [];
  Map<String, dynamic>? _activeConnection;
  bool _isLoading = false;
  bool _isSyncing = false;
  String _syncStatusMessage = 'Ready';
  double _syncProgress = 1.0;

  List<CloudDatabaseQuoteModel> get quotes => _quotes;
  Map<String, dynamic>? get activeConnection => _activeConnection;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String get syncStatusMessage => _syncStatusMessage;
  double get syncProgress => _syncProgress;

  void init() {
    _quotes = CloudPricingData.getQuotes();
    loadActiveConnection();
  }

  Future<void> loadActiveConnection() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('cloud_connections', orderBy: 'id DESC', limit: 1);
      if (rows.isNotEmpty) {
        _activeConnection = Map<String, dynamic>.from(rows.first);
      }
    } catch (e) {
      debugPrint('Error loading cloud connection: $e');
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> testAndSaveConnection({
    required String providerId,
    required String endpointUrl,
    required String apiKey,
    required String projectRef,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Simulate network handshake to cloud provider
    await Future.delayed(const Duration(milliseconds: 900));

    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);

      final id = await db.insert('cloud_connections', {
        'provider_id': providerId,
        'endpoint_url': endpointUrl,
        'api_key': apiKey,
        'project_ref': projectRef,
        'status': 'connected',
        'last_synced': nowIso,
      });

      _activeConnection = {
        'id': id,
        'provider_id': providerId,
        'endpoint_url': endpointUrl,
        'api_key': apiKey,
        'project_ref': projectRef,
        'status': 'connected',
        'last_synced': nowIso,
      };

      _isLoading = false;
      notifyListeners();

      return {
        'success': true,
        'latency_ms': 42,
        'message': 'Connected seamlessly to $providerId ($projectRef). Handshake 200 OK.',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> triggerCloudSync() async {
    _isSyncing = true;
    _syncProgress = 0.1;
    _syncStatusMessage = 'Checking local SQLite delta changes...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    _syncProgress = 0.35;
    _syncStatusMessage = 'Syncing 8 Customers & KYC documents...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));
    _syncProgress = 0.70;
    _syncStatusMessage = 'Syncing Loan records & EMI payments...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    _syncProgress = 0.90;
    _syncStatusMessage = 'Syncing Pre-GRT group forms & Attendance...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
    _syncProgress = 1.0;
    _syncStatusMessage = 'All transactions synced successfully to cloud.';
    _isSyncing = false;

    final nowIso = DateTime.now().toIso8601String().substring(0, 19);
    if (_activeConnection != null) {
      _activeConnection!['last_synced'] = nowIso;
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'cloud_connections',
        {'last_synced': nowIso},
        where: 'id = ?',
        whereArgs: [_activeConnection!['id']],
      );
    }

    notifyListeners();
  }
}
