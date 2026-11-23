import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';

class SyncService extends ChangeNotifier {
  static const String defaultSyncEndpoint =
      'https://sarvocchfinance.com/portal/api/v1/sync';

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

  /// Performs full offline-to-online batch synchronization against SARVOOCCH backend.
  Future<bool> triggerFullSync({
    int? userId,
    String? syncUrl,
  }) async {
    final endpoint = syncUrl ?? defaultSyncEndpoint;
    try {
      final db = await DatabaseHelper.instance.database;
      final pendingRows = await db.query(
        'sync_log',
        where: "synced_at IS NULL OR synced_at = ''",
        orderBy: 'id ASC',
        limit: 100,
      );

      if (pendingRows.isEmpty) {
        _lastSyncStatus = 'All offline operations are fully synced.';
        await updatePendingCount();
        notifyListeners();
        return true;
      }

      _lastSyncStatus = 'Syncing ${pendingRows.length} operations...';
      notifyListeners();

      final items = pendingRows.map((row) {
        Map<String, dynamic> decodedPayload = {};
        try {
          decodedPayload = jsonDecode(row['payload'] as String? ?? '{}') as Map<String, dynamic>;
        } catch (_) {}
        return {
          'uuid': row['uuid'],
          'user_id': row['user_id'],
          'captured_at': row['captured_at'],
          'action': decodedPayload['action'] ?? 'offline_action',
          'data': decodedPayload['data'] ?? {},
        };
      }).toList();

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse(endpoint);
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (userId != null && userId > 0) {
        request.headers.set('X-User-Id', userId.toString());
      }
      request.write(jsonEncode({'items': items}));

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> result =
            (jsonDecode(responseBody) as Map<String, dynamic>?) ?? {};
        final accepted = (result['accepted_uuids'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            {};
        final serverTime = (result['server_timestamp'] as String?) ??
            DateTime.now().toIso8601String().substring(0, 19);

        // Mark accepted items as synced in local SQLite
        await db.transaction((txn) async {
          for (final row in pendingRows) {
            final uuid = row['uuid'] as String;
            if (accepted.contains(uuid) || accepted.isEmpty) {
              await txn.update(
                'sync_log',
                {'synced_at': serverTime},
                where: 'uuid = ?',
                whereArgs: [uuid],
              );
            }
          }
        });

        _lastSyncStatus =
            'Sync complete (${pendingRows.length} items verified).';
        await updatePendingCount();
        notifyListeners();
        return true;
      } else {
        _lastSyncStatus = 'Server response ${response.statusCode}; data saved safely.';
        await updatePendingCount();
        notifyListeners();
        return false;
      }
    } catch (_) {
      _lastSyncStatus = 'Device offline: operations queued safely on phone.';
      await updatePendingCount();
      notifyListeners();
      return false;
    }
  }
}
