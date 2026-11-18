import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  int _pendingCount = 0;
  String _lastSyncStatus = 'Idle';

  int get pendingCount => _pendingCount;
  String get lastSyncStatus => _lastSyncStatus;

  Future<void> init() async {
    await updatePendingCount();
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
  Future<bool> enqueueAction({
    required int userId,
    required String action,
    required Map<String, dynamic> payload,
    required String operationId,
  }) async {
    final normalizedAction = action.trim();
    final normalizedOperationId = operationId.trim();
    if (userId <= 0 ||
        normalizedAction.isEmpty ||
        normalizedOperationId.isEmpty ||
        normalizedOperationId.length > 128) {
      return false;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final encodedPayload = jsonEncode({
        'action': normalizedAction,
        'data': payload,
      });
      final inserted = await db.transaction<bool>((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['id'],
          where: "id = ? AND auth_status = 'active'",
          whereArgs: [userId],
          limit: 1,
        );
        if (actors.isEmpty) return false;

        final existing = await txn.query(
          'sync_log',
          columns: ['user_id', 'payload'],
          where: 'uuid = ?',
          whereArgs: [normalizedOperationId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return existing.first['user_id'] == userId &&
              existing.first['payload'] == encodedPayload;
        }

        await txn.insert('sync_log', {
          'uuid': normalizedOperationId,
          'user_id': userId,
          'payload': encodedPayload,
          'captured_at': nowIso,
          'synced_at': null,
        });
        return true;
      });

      await updatePendingCount();
      return inserted;
    } catch (_) {
      debugPrint('Offline operation could not be queued.');
      return false;
    }
  }

  /// Report that sync is unavailable until a secure backend is configured.
  Future<bool> triggerFullSync({int? userId}) async {
    _lastSyncStatus =
        'Sync is not configured; pending changes remain on this device.';
    await updatePendingCount();
    notifyListeners();
    return false;
  }
}
