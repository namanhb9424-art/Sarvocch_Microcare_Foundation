import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/pregrt_model.dart';

class PreGrtProvider extends ChangeNotifier {
  List<PreGrtModel> _preGrts = [];
  bool _isLoading = false;

  List<PreGrtModel> get preGrts => _preGrts;
  bool get isLoading => _isLoading;

  Future<void> fetchPreGrts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final groupRows = await db.query('pregrt', orderBy: 'id DESC');

      List<PreGrtModel> list = [];
      for (var grp in groupRows) {
        final gId = grp['id'] as int;
        final memRows = await db.query('pregrt_members', where: 'pregrt_id = ?', whereArgs: [gId], orderBy: 'sno ASC');
        final members = memRows.map((m) => PreGrtMemberModel.fromMap(m)).toList();
        list.add(PreGrtModel.fromMap(grp, members: members));
      }

      _preGrts = list;
    } catch (e) {
      debugPrint('Error fetching Pre-GRT: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> reviewPreGrt({
    required int pregrtId,
    required String status, // 'verified' or 'returned'
    required String reviewRemarks,
    required String verifiedBy,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      await db.update(
        'pregrt',
        {
          'status': status,
          'review_remarks': reviewRemarks,
          'verified_by': verifiedBy,
          'verified_on': todayStr,
        },
        where: 'id = ?',
        whereArgs: [pregrtId],
      );

      await fetchPreGrts();
      return true;
    } catch (e) {
      debugPrint('Error reviewing Pre-GRT: $e');
      return false;
    }
  }

  Future<int?> createPreGrt({
    required String branch,
    required String centerNo,
    required String groupNo,
    required String village,
    required String district,
    required String psoName,
    required String psoEmpid,
    required String bmName,
    required String bmEmpid,
    required String notes,
    required int agentId,
    required List<Map<String, dynamic>> members,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final todayStr = nowIso.substring(0, 10);

      final pgId = await db.insert('pregrt', {
        'branch': branch,
        'center_no': centerNo,
        'group_no': groupNo,
        'village': village,
        'district': district,
        'form_date': todayStr,
        'pso_name': psoName,
        'pso_empid': psoEmpid,
        'bm_name': bmName,
        'bm_empid': bmEmpid,
        'leader_knows_duties': 'yes',
        'notes': notes,
        'agent_id': agentId,
        'status': 'submitted',
        'created_at': nowIso,
      });

      for (int i = 0; i < members.length; i++) {
        final m = members[i];
        await db.insert('pregrt_members', {
          'pregrt_id': pgId,
          'sno': i + 1,
          'customer_id': m['customer_id'],
          'name': m['name'],
          'husband_name': m['husband_name'] ?? '',
          'age': m['age'] ?? 30,
          'voter_id': m['voter_id'] ?? '',
          'aadhaar4': m['aadhaar4'] ?? '0000',
          'family_in_group': 'no',
          'house_type': m['house_type'] ?? 'pucca',
          'land_ha': m['land_ha'] ?? 0.0,
          'livestock': m['livestock'] ?? '',
          'annual_income': m['annual_income'] ?? 180000.0,
          'family_size': m['family_size'] ?? 4,
          'category': m['category'] ?? 'OBC',
          'loan_amount': m['loan_amount'] ?? 20000.0,
          'purpose': m['purpose'] ?? 'Micro-business',
          'frequency': 'monthly',
          'instalments': 12,
          'c_meeting': 1,
          'c_joint': 1,
          'c_fee': 1,
          'c_rate': 1,
          'c_insurance': 1,
          'c_company': 1,
          'c_group': 1,
        });
      }

      await fetchPreGrts();
      return pgId;
    } catch (e) {
      debugPrint('Error creating Pre-GRT: $e');
      return null;
    }
  }
}
