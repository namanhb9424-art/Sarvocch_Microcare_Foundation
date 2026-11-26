import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../services/sync_service.dart';

class GrievanceProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _grievances = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get grievances => _grievances;
  bool get isLoading => _isLoading;

  void clearSessionData() {
    _grievances = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchGrievances({required int actorUserId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      final users = await db.query(
        'users',
        columns: ['role', 'branch', 'phone', 'customer_id', 'auth_status'],
        where: 'id = ?',
        whereArgs: [actorUserId],
        limit: 1,
      );
      if (users.isEmpty || users.first['auth_status'] != 'active') {
        _grievances = [];
        return;
      }
      final u = users.first;
      final role = u['role'] as String? ?? '';
      final branch = (u['branch'] as String? ?? '').trim();

      if (role == 'admin') {
        _grievances = await db.query('grievances', orderBy: 'id DESC');
      } else if (role == 'customer') {
        final cid = u['customer_id'] as int?;
        final phone = (u['phone'] as String? ?? '').trim();
        _grievances = await db.query(
          'grievances',
          where: cid != null ? 'customer_id = ? OR phone = ?' : 'phone = ?',
          whereArgs: cid != null ? [cid, phone] : [phone],
          orderBy: 'id DESC',
        );
      } else {
        _grievances = await db.query(
          'grievances',
          where: 'branch = ?',
          whereArgs: [branch],
          orderBy: 'id DESC',
        );
      }
    } catch (_) {
      _grievances = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createGrievance({
    required int actorUserId,
    required String name,
    required String phone,
    required String category,
    required String details,
    required String branch,
    int? customerId,
  }) async {
    if (name.trim().isEmpty || details.trim().isEmpty) return null;
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final datePart =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final suffix = const Uuid().v4().substring(0, 4).toUpperCase();
      final ticketNo = 'GRV-$datePart-$suffix';
      final createdAt = now.toIso8601String().substring(0, 19);

      await db.insert('grievances', {
        'ticket_no': ticketNo,
        'customer_id': customerId,
        'name': name.trim(),
        'phone': phone.trim(),
        'category': category.trim(),
        'details': details.trim(),
        'status': 'open',
        'branch': branch.trim().isNotEmpty ? branch.trim() : 'Bhopal Head Office',
        'created_at': createdAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await SyncService().enqueueAction(
        userId: actorUserId,
        action: 'grievance_created',
        operationId: 'grv_create_$ticketNo',
        payload: {
          'ticket_no': ticketNo,
          'customer_id': customerId,
          'name': name.trim(),
          'phone': phone.trim(),
          'category': category.trim(),
          'details': details.trim(),
          'branch': branch.trim(),
        },
      );
      SyncService().triggerFullSync(userId: actorUserId);

      await fetchGrievances(actorUserId: actorUserId);
      return ticketNo;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateGrievance({
    required int actorUserId,
    required int id,
    required String ticketNo,
    required String status,
    required String resolutionNotes,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowStr = DateTime.now().toIso8601String().substring(0, 19);
      await db.update(
        'grievances',
        {
          'status': status,
          'resolution_notes': resolutionNotes.trim(),
          'resolved_at': status == 'resolved' ? nowStr : null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await SyncService().enqueueAction(
        userId: actorUserId,
        action: 'grievance_updated',
        operationId: 'grv_upd_${ticketNo}_${DateTime.now().millisecondsSinceEpoch}',
        payload: {
          'ticket_no': ticketNo,
          'status': status,
          'resolution_notes': resolutionNotes.trim(),
        },
      );
      SyncService().triggerFullSync(userId: actorUserId);

      await fetchGrievances(actorUserId: actorUserId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
