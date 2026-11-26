import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/attendance_model.dart';
import '../models/branch_model.dart';
import '../services/sync_service.dart';

class AttendanceProvider extends ChangeNotifier {
  List<AttendanceRecordModel> _records = [];
  List<AttendanceRequestModel> _requests = [];
  List<BranchModel> _branches = [];
  AttendanceRecordModel? _todayRecord;
  bool _isLoading = false;
  int _sessionGeneration = 0;

  List<AttendanceRecordModel> get records => _records;
  List<AttendanceRequestModel> get requests => _requests;
  List<BranchModel> get branches => _branches;
  AttendanceRecordModel? get todayRecord => _todayRecord;
  bool get isLoading => _isLoading;

  void clearSessionData() {
    _sessionGeneration++;
    _records = [];
    _requests = [];
    _branches = [];
    _todayRecord = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAttendanceData(int userId) async {
    final sessionGeneration = _sessionGeneration;
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final userRows = await db.query(
        'users',
        columns: ['name', 'role', 'branch', 'auth_status'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (sessionGeneration != _sessionGeneration) return;
      final user = userRows.isEmpty ? null : userRows.first;
      if (user == null || user['auth_status'] != 'active') {
        _records = [];
        _requests = [];
        _branches = [];
        _todayRecord = null;
        return;
      }
      final role = user['role'] as String? ?? '';
      final userBranch = user['branch'] as String? ?? '';
      if (!{'admin', 'manager', 'underwriter', 'field_agent'}.contains(role) ||
          (role != 'admin' && userBranch.trim().isEmpty)) {
        _records = [];
        _requests = [];
        _branches = [];
        _todayRecord = null;
        return;
      }
      final requestRole = role;

      // 1. Fetch branches
      final bRows = await db.query(
        'branches',
        where: role == 'admin' ? 'active = 1' : 'active = 1 AND name = ?',
        whereArgs: role == 'admin' ? null : [userBranch],
      );
      if (sessionGeneration != _sessionGeneration) return;
      _branches = bRows.map((b) => BranchModel.fromMap(b)).toList();

      // 2. Fetch user's attendance records
      final attRows = await db.query(
        'attendance',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'day DESC',
      );
      if (sessionGeneration != _sessionGeneration) return;
      _records = attRows.map((r) => AttendanceRecordModel.fromMap(r)).toList();

      final todayList = _records.where((r) => r.day == todayStr).toList();
      _todayRecord = todayList.isNotEmpty ? todayList.first : null;

      // 3. Fetch requests with user names
      final reqRows = await db.rawQuery(
        '''
        SELECT r.*, u.name as user_name
        FROM att_requests r
        LEFT JOIN users u ON r.user_id = u.id
        WHERE (? = 'admin') OR r.user_id = ? OR (? = 'manager' AND r.branch = ?)
        ORDER BY r.id DESC
      ''',
        [requestRole, userId, requestRole, userBranch],
      );
      if (sessionGeneration != _sessionGeneration) return;
      _requests = reqRows
          .map((r) => AttendanceRequestModel.fromMap(r))
          .toList();
    } catch (_) {
      debugPrint('Attendance records could not be loaded.');
    } finally {
      if (sessionGeneration == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Haversine distance in meters
  double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R * 1000; R = 6371 km
  }

  Future<Map<String, dynamic>> punchIn({
    required int userId,
    required String branchName,
    required double currentLat,
    required double currentLng,
  }) async {
    double? distMeters;
    int? radiusMeters;
    try {
      if (userId <= 0 ||
          !currentLat.isFinite ||
          currentLat < -90 ||
          currentLat > 90 ||
          !currentLng.isFinite ||
          currentLng < -180 ||
          currentLng > 180) {
        return {'success': false, 'error': 'Current location is invalid.'};
      }
      final db = await DatabaseHelper.instance.database;
      final actorRows = await db.query(
        'users',
        columns: ['name', 'role', 'branch', 'auth_status'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (actorRows.isEmpty ||
          actorRows.first['auth_status'] != 'active' ||
          !{
            'admin',
            'manager',
            'underwriter',
            'field_agent',
          }.contains(actorRows.first['role']) ||
          (actorRows.first['role'] != 'admin' &&
              actorRows.first['branch'] != branchName)) {
        return {'success': false, 'error': 'Attendance access denied.'};
      }
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);
      final nowIso = now.toIso8601String().substring(0, 19);
      final operationId = const Uuid().v4();
      await db.transaction((txn) async {
        // Recheck access and uniqueness while holding the write transaction so
        // concurrent actions cannot create duplicate daily attendance rows.
        final activeActor = await txn.query(
          'users',
          columns: ['name', 'role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [userId],
          limit: 1,
        );
        if (activeActor.isEmpty ||
            activeActor.first['auth_status'] != 'active' ||
            !{
              'admin',
              'manager',
              'underwriter',
              'field_agent',
            }.contains(activeActor.first['role']) ||
            (activeActor.first['role'] != 'admin' &&
                activeActor.first['branch'] != branchName)) {
          throw StateError('Attendance access denied.');
        }
        final branches = await txn.query(
          'branches',
          columns: ['lat', 'lng', 'radius_m'],
          where: 'name = ? AND active = 1',
          whereArgs: [branchName],
          limit: 1,
        );
        if (branches.isEmpty ||
            branches.first['lat'] == null ||
            branches.first['lng'] == null) {
          throw StateError('Branch geofence is not configured.');
        }
        final branchLat = (branches.first['lat'] as num).toDouble();
        final branchLng = (branches.first['lng'] as num).toDouble();
        final branchRadius = (branches.first['radius_m'] as num?)?.toInt() ?? 0;
        radiusMeters = branchRadius;
        if (!branchLat.isFinite ||
            branchLat < -90 ||
            branchLat > 90 ||
            !branchLng.isFinite ||
            branchLng < -180 ||
            branchLng > 180 ||
            branchRadius <= 0) {
          throw StateError('Branch geofence is not configured.');
        }
        final distance = calculateDistanceMeters(
          currentLat,
          currentLng,
          branchLat,
          branchLng,
        );
        distMeters = distance;
        if (distance > branchRadius) {
          throw StateError(
            'Current location is outside the configured branch radius.',
          );
        }
        final existingPunches = await txn.query(
          'attendance',
          columns: ['id'],
          where: 'user_id = ? AND day = ?',
          whereArgs: [userId, todayStr],
          limit: 1,
        );
        if (existingPunches.isNotEmpty) {
          throw StateError('Punch-in already exists for today.');
        }
        final attendanceId = await txn.insert('attendance', {
          'user_id': userId,
          'day': todayStr,
          'in_time': nowIso,
          'lat': currentLat,
          'lng': currentLng,
        });
        await txn.insert('audit_log', {
          'operation_id': operationId,
          'entity_type': 'attendance',
          'entity_id': attendanceId,
          'action': 'attendance_punch_in',
          'actor_user_id': userId,
          'actor_role': activeActor.first['role'],
          'actor_name': activeActor.first['name'],
          'occurred_at': nowIso,
          'details': '{}',
        });
      });

      await SyncService().enqueueAction(
        userId: userId,
        action: 'attendance_punch_in',
        operationId: operationId,
        payload: {
          'day': todayStr,
          'in_time': nowIso,
          'lat': currentLat,
          'lng': currentLng,
          'in_dist': distMeters?.round(),
          'branch': branchName,
        },
      );
      SyncService().triggerFullSync(userId: userId);

      await fetchAttendanceData(userId);
      return {
        'success': true,
        'distance': distMeters!.round(),
        'within_radius': true,
        'radius_m': radiusMeters!,
      };
    } catch (error) {
      debugPrint('Attendance punch-in could not be recorded.');
      final message = error.toString();
      if (message.contains('Punch-in already exists for today.')) {
        return {
          'success': false,
          'error': 'Punch-in already exists for today.',
        };
      }
      if (message.contains('Attendance access denied.')) {
        return {'success': false, 'error': 'Attendance access denied.'};
      }
      if (message.contains('Branch geofence is not configured.')) {
        return {
          'success': false,
          'error': 'Branch GPS and radius must be configured before punch-in.',
        };
      }
      if (message.contains('outside the configured branch radius')) {
        return {
          'success': false,
          'error': 'Current location is outside the configured branch radius.',
          if (distMeters != null) 'distance': distMeters!.round(),
          if (radiusMeters != null) 'radius_m': radiusMeters,
        };
      }
      if (message.contains('UNIQUE constraint failed: attendance.user_id')) {
        return {
          'success': false,
          'error': 'Punch-in already exists for today.',
        };
      }
      return {
        'success': false,
        'error': 'Punch-in could not be recorded. Please try again.',
      };
    }
  }

  Future<bool> punchOut(int userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (userId <= 0) return false;
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);
      final nowIso = now.toIso8601String().substring(0, 19);

      final operationId = const Uuid().v4();
      final updated = await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'auth_status'],
          where: 'id = ?',
          whereArgs: [userId],
          limit: 1,
        );
        if (actors.isEmpty ||
            actors.first['auth_status'] != 'active' ||
            !{
              'admin',
              'manager',
              'underwriter',
              'field_agent',
            }.contains(actors.first['role'])) {
          return 0;
        }
        final changed = await txn.update(
          'attendance',
          {'out_time': nowIso},
          where: 'user_id = ? AND day = ? AND out_time IS NULL',
          whereArgs: [userId, todayStr],
        );
        if (changed == 1) {
          final rows = await txn.query(
            'attendance',
            columns: ['id'],
            where: 'user_id = ? AND day = ?',
            whereArgs: [userId, todayStr],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            await txn.insert('audit_log', {
              'operation_id': operationId,
              'entity_type': 'attendance',
              'entity_id': rows.first['id'],
              'action': 'attendance_punch_out',
              'actor_user_id': userId,
              'actor_role': actors.first['role'],
              'actor_name': actors.first['name'],
              'occurred_at': nowIso,
              'details': '{}',
            });
          }
        }
        return changed;
      });

      if (updated == 1) {
        await SyncService().enqueueAction(
          userId: userId,
          action: 'attendance_punch_out',
          operationId: operationId,
          payload: {'day': todayStr, 'out_time': nowIso},
        );
        SyncService().triggerFullSync(userId: userId);
      }

      await fetchAttendanceData(userId);
      return updated == 1;
    } catch (_) {
      debugPrint('Attendance punch-out could not be recorded.');
      return false;
    }
  }

  Future<bool> submitRequest({
    required int actorUserId,
    required String day,
    required String inTime,
    required String outTime,
    required String reason,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final cleanReason = reason.trim();
      if (actorUserId <= 0 ||
          cleanReason.isEmpty ||
          !_isValidCorrection(day, inTime, outTime)) {
        return false;
      }
      final submitted = await db.transaction((txn) async {
        final actorRows = await txn.query(
          'users',
          columns: ['name', 'branch', 'role', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actorRows.isEmpty ||
            actorRows.first['auth_status'] != 'active' ||
            !{'manager', 'field_agent'}.contains(actorRows.first['role']) ||
            (actorRows.first['branch'] as String? ?? '').trim().isEmpty) {
          return false;
        }
        final branches = await txn.query(
          'branches',
          columns: ['id'],
          where: 'name = ? AND active = 1',
          whereArgs: [actorRows.first['branch']],
          limit: 1,
        );
        if (branches.isEmpty) return false;
        final pendingRequests = await txn.query(
          'att_requests',
          columns: ['id'],
          where: "user_id = ? AND day = ? AND status = 'pending'",
          whereArgs: [actorUserId, day],
          limit: 1,
        );
        if (pendingRequests.isNotEmpty) return false;
        final requestId = await txn.insert('att_requests', {
          'user_id': actorUserId,
          'branch': actorRows.first['branch'],
          'day': day,
          'in_time': inTime,
          'out_time': outTime,
          'reason': cleanReason,
          'status': 'pending',
          'approver_role': 'manager',
          'approver_id': null,
          'requested_at': nowIso,
        });
        await txn.insert('audit_log', {
          'operation_id': const Uuid().v4(),
          'entity_type': 'attendance_request',
          'entity_id': requestId,
          'action': 'attendance_request_submitted',
          'actor_user_id': actorUserId,
          'actor_role': actorRows.first['role'],
          'actor_name': actorRows.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({'day': day}),
        });
        return true;
      });
      if (!submitted) return false;

      await fetchAttendanceData(actorUserId);
      return true;
    } catch (_) {
      debugPrint('Attendance correction request could not be submitted.');
      return false;
    }
  }

  Future<bool> decideRequest({
    required int requestId,
    required String decision, // 'approved' or 'rejected'
    required int actorUserId,
    required String remarks,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      if (actorUserId <= 0 ||
          requestId <= 0 ||
          !{'approved', 'rejected'}.contains(decision) ||
          remarks.trim().isEmpty) {
        return false;
      }
      final operationId = const Uuid().v4();
      final changed = await db.transaction((txn) async {
        final actors = await txn.query(
          'users',
          columns: ['name', 'role', 'branch', 'auth_status'],
          where: 'id = ?',
          whereArgs: [actorUserId],
          limit: 1,
        );
        if (actors.isEmpty ||
            actors.first['auth_status'] != 'active' ||
            !{'admin', 'manager'}.contains(actors.first['role'])) {
          return 0;
        }
        final requests = await txn.query(
          'att_requests',
          where: "id = ? AND status = 'pending'",
          whereArgs: [requestId],
          limit: 1,
        );
        if (requests.isEmpty) return 0;
        final request = requests.first;
        final requestUserId = request['user_id'] as int?;
        final requestDay = request['day'] as String? ?? '';
        final inTime = request['in_time'] as String? ?? '';
        final outTime = request['out_time'] as String? ?? '';
        if ((actors.first['role'] == 'manager' &&
                (actors.first['branch'] as String? ?? '').trim() !=
                    (request['branch'] as String? ?? '').trim()) ||
            requestUserId == null ||
            requestUserId == actorUserId ||
            (request['branch'] as String? ?? '').trim().isEmpty ||
            !_isValidCorrection(requestDay, inTime, outTime)) {
          return 0;
        }
        final targetUsers = await txn.query(
          'users',
          columns: ['auth_status', 'branch'],
          where: 'id = ?',
          whereArgs: [requestUserId],
          limit: 1,
        );
        if (targetUsers.isEmpty ||
            targetUsers.first['auth_status'] != 'active' ||
            targetUsers.first['branch'] != request['branch']) {
          return 0;
        }
        final otherPendingRows = await txn.rawQuery(
          '''
          SELECT COUNT(*) AS count FROM att_requests
          WHERE user_id = ? AND day = ? AND status = 'pending' AND id != ?
          ''',
          [requestUserId, requestDay, requestId],
        );
        if ((otherPendingRows.first['count'] as int? ?? 0) > 0) return 0;
        final attendanceRows = await txn.rawQuery(
          'SELECT COUNT(*) AS count FROM attendance WHERE user_id = ? AND day = ?',
          [requestUserId, requestDay],
        );
        if ((attendanceRows.first['count'] as int? ?? 0) > 1) return 0;
        final count = await txn.update(
          'att_requests',
          {
            'status': decision,
            'decided_by': actors.first['name'],
            'decided_at': nowIso,
            'remarks': remarks.trim(),
            'approver_id': actorUserId,
          },
          where: "id = ? AND status = 'pending'",
          whereArgs: [requestId],
        );
        if (count != 1) return 0;
        if (decision == 'approved') {
          final existing = await txn.query(
            'attendance',
            columns: ['id'],
            where: 'user_id = ? AND day = ?',
            whereArgs: [requestUserId, requestDay],
            orderBy: 'id ASC',
            limit: 1,
          );
          if (existing.isEmpty) {
            await txn.insert('attendance', {
              'user_id': requestUserId,
              'day': requestDay,
              'in_time': inTime,
              'out_time': outTime,
              'lat': null,
              'lng': null,
            });
          } else {
            await txn.update(
              'attendance',
              {'in_time': inTime, 'out_time': outTime},
              where: 'id = ?',
              whereArgs: [existing.first['id']],
            );
          }
        }
        await txn.insert('audit_log', {
          'operation_id': operationId,
          'entity_type': 'attendance_request',
          'entity_id': requestId,
          'action': 'attendance_request_$decision',
          'actor_user_id': actorUserId,
          'actor_role': actors.first['role'],
          'actor_name': actors.first['name'],
          'occurred_at': nowIso,
          'details': jsonEncode({
            'remarks': remarks.trim(),
            'day': requestDay,
            'in_time': inTime,
            'out_time': outTime,
          }),
        });
        return count;
      });
      if (changed != 1) return false;
      await fetchAttendanceData(actorUserId);
      return true;
    } catch (_) {
      debugPrint('Attendance correction request could not be reviewed.');
      return false;
    }
  }

  bool _isValidCorrection(String day, String inTime, String outTime) {
    final parsedDay = DateTime.tryParse(day);
    if (parsedDay == null ||
        parsedDay.toIso8601String().substring(0, 10) != day ||
        day.compareTo(DateTime.now().toIso8601String().substring(0, 10)) > 0) {
      return false;
    }
    final timePattern = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!timePattern.hasMatch(inTime) || !timePattern.hasMatch(outTime)) {
      return false;
    }
    final inParts = inTime.split(':').map(int.parse).toList();
    final outParts = outTime.split(':').map(int.parse).toList();
    final inMinutes = inParts[0] * 60 + inParts[1];
    final outMinutes = outParts[0] * 60 + outParts[1];
    if (outMinutes <= inMinutes) return false;
    final today = DateTime.now();
    if (day == today.toIso8601String().substring(0, 10)) {
      final nowMinutes = today.hour * 60 + today.minute;
      if (outMinutes > nowMinutes) return false;
    }
    return true;
  }
}
