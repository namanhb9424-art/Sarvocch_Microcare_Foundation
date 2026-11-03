import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import 'api_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;
  int _pendingCount = 0;
  String _lastSyncStatus = 'Idle';
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String get lastSyncStatus => _lastSyncStatus;
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> init() async {
    await updatePendingCount();
    Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result.any((r) => r != ConnectivityResult.none);
      if (isOnline && _pendingCount > 0 && !_isSyncing) {
        triggerFullSync();
      }
    });
  }

  Future<int> updatePendingCount() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM sync_log WHERE synced_at IS NULL OR synced_at = ''",
      );
      _pendingCount = (res.first['cnt'] as num?)?.toInt() ?? 0;
      notifyListeners();
      return _pendingCount;
    } catch (_) {
      return 0;
    }
  }

  /// Add offline action to sync queue
  Future<void> enqueueAction({
    required int userId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final uuid = 'SYNC-${DateTime.now().millisecondsSinceEpoch}-$userId';

      final fullPayload = {
        'action': action,
        'data': payload,
      };

      await db.insert('sync_log', {
        'uuid': uuid,
        'user_id': userId,
        'payload': jsonEncode(fullPayload),
        'captured_at': nowIso,
        'synced_at': null,
      });

      await updatePendingCount();
    } catch (e) {
      debugPrint('SyncService enqueue error: $e');
    }
  }

  /// Trigger full bidirectional sync with server
  Future<bool> triggerFullSync({int? userId}) async {
    if (_isSyncing) return false;
    _isSyncing = true;
    _lastSyncStatus = 'Synchronizing...';
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch pending items from queue
      final pendingRows = await db.query(
        'sync_log',
        where: "synced_at IS NULL OR synced_at = ''",
        orderBy: 'id ASC',
      );

      if (pendingRows.isNotEmpty) {
        final List<Map<String, dynamic>> queueItems = [];
        for (var row in pendingRows) {
          queueItems.add({
            'uuid': row['uuid'],
            'user_id': row['user_id'],
            'payload': jsonDecode(row['payload'] as String),
            'captured_at': row['captured_at'],
          });
        }

        // Push to server
        final pushed = await ApiService().pushOfflineQueue(queueItems);
        if (pushed) {
          final nowIso = DateTime.now().toIso8601String().substring(0, 19);
          for (var row in pendingRows) {
            await db.update(
              'sync_log',
              {'synced_at': nowIso},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      }

      // 2. Pull latest bundle from server
      final serverBundle = await ApiService().fetchSyncBundle();
      if (serverBundle != null) {
        // Server bundle received successfully
        _lastSyncStatus = 'Up-to-date';
      } else {
        _lastSyncStatus = pendingRows.isEmpty ? 'Local queue clear (Server offline)' : 'Pending sync';
      }

      _lastSyncTime = DateTime.now();
      await updatePendingCount();
      return true;
    } catch (e) {
      debugPrint('SyncService error: $e');
      _lastSyncStatus = 'Sync error: $e';
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}

