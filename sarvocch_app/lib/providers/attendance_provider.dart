import 'dart:math';
import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/attendance_model.dart';
import '../models/branch_model.dart';

class AttendanceProvider extends ChangeNotifier {
  List<AttendanceRecordModel> _records = [];
  List<AttendanceRequestModel> _requests = [];
  List<BranchModel> _branches = [];
  AttendanceRecordModel? _todayRecord;
  bool _isLoading = false;

  List<AttendanceRecordModel> get records => _records;
  List<AttendanceRequestModel> get requests => _requests;
  List<BranchModel> get branches => _branches;
  AttendanceRecordModel? get todayRecord => _todayRecord;
  bool get isLoading => _isLoading;

  Future<void> fetchAttendanceData(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // 1. Fetch branches
      final bRows = await db.query('branches', where: 'active = 1');
      _branches = bRows.map((b) => BranchModel.fromMap(b)).toList();

      // 2. Fetch user's attendance records
      final attRows = await db.query(
        'attendance',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'day DESC',
      );
      _records = attRows.map((r) => AttendanceRecordModel.fromMap(r)).toList();

      final todayList = _records.where((r) => r.day == todayStr).toList();
      _todayRecord = todayList.isNotEmpty ? todayList.first : null;

      // 3. Fetch requests with user names
      final reqRows = await db.rawQuery('''
        SELECT r.*, u.name as user_name
        FROM att_requests r
        LEFT JOIN users u ON r.user_id = u.id
        ORDER BY r.id DESC
      ''');
      _requests = reqRows.map((r) => AttendanceRequestModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Haversine distance in meters
  double calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R * 1000; R = 6371 km
  }

  Future<Map<String, dynamic>> punchIn({
    required int userId,
    required String branchName,
    required double currentLat,
    required double currentLng,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final branch = _branches.firstWhere(
        (b) => b.name == branchName,
        orElse: () => _branches.first,
      );

      final distMeters = calculateDistanceMeters(currentLat, currentLng, branch.lat, branch.lng);
      final isWithinRadius = distMeters <= branch.radiusM;

      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);
      final nowIso = now.toIso8601String().substring(0, 19);

      if (_todayRecord == null) {
        await db.insert('attendance', {
          'user_id': userId,
          'day': todayStr,
          'in_time': nowIso,
          'lat': currentLat,
          'lng': currentLng,
        });
      }

      await fetchAttendanceData(userId);
      return {
        'success': true,
        'distance': distMeters.round(),
        'within_radius': isWithinRadius,
        'radius_m': branch.radiusM,
      };
    } catch (e) {
      debugPrint('Error punch in: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> punchOut(int userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);
      final nowIso = now.toIso8601String().substring(0, 19);

      await db.update(
        'attendance',
        {'out_time': nowIso},
        where: 'user_id = ? AND day = ?',
        whereArgs: [userId, todayStr],
      );

      await fetchAttendanceData(userId);
      return true;
    } catch (e) {
      debugPrint('Error punch out: $e');
      return false;
    }
  }

  Future<bool> submitRequest({
    required int userId,
    required String branch,
    required String day,
    required String inTime,
    required String outTime,
    required String reason,
    required String approverRole,
    required int approverId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);

      await db.insert('att_requests', {
        'user_id': userId,
        'branch': branch,
        'day': day,
        'in_time': inTime,
        'out_time': outTime,
        'reason': reason,
        'status': 'pending',
        'approver_role': approverRole,
        'approver_id': approverId,
        'requested_at': nowIso,
      });

      await fetchAttendanceData(userId);
      return true;
    } catch (e) {
      debugPrint('Error submitting attendance request: $e');
      return false;
    }
  }

  Future<bool> decideRequest({
    required int requestId,
    required String decision, // 'approved' or 'rejected'
    required String decidedBy,
    required String remarks,
    required int userId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);

      await db.update(
        'att_requests',
        {
          'status': decision,
          'decided_by': decidedBy,
          'decided_at': nowIso,
          'remarks': remarks,
        },
        where: 'id = ?',
        whereArgs: [requestId],
      );

      await fetchAttendanceData(userId);
      return true;
    } catch (e) {
      debugPrint('Error deciding request: $e');
      return false;
    }
  }
}
