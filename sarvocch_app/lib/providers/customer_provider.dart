import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/customer_model.dart';

class CustomerProvider extends ChangeNotifier {
  List<CustomerModel> _customers = [];
  bool _isLoading = false;

  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;

  Future<void> fetchCustomers() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery('''
        SELECT c.*, k.center_no, k.group_no, k.guardian_type, k.guardian_name, k.education,
               k.religion, k.category, k.house_type, k.bank_name, k.bank_acct, k.passbook_name,
               k.annual_income, k.h_name, k.consent_given, k.address_verified
        FROM customers c
        LEFT JOIN kyc_forms k ON c.id = k.customer_id
        ORDER BY c.id ASC
      ''');
      _customers = results.map((m) => CustomerModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<CommLogModel>> getCommLogs(int customerId) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'comm_logs',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'id DESC',
    );
    return results.map((m) => CommLogModel.fromMap(m)).toList();
  }

  Future<void> addCommLog({
    required int customerId,
    required String channel,
    required String note,
    required String byName,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final nowIso = DateTime.now().toIso8601String().substring(0, 19);
    await db.insert('comm_logs', {
      'customer_id': customerId,
      'channel': channel,
      'note': note,
      'by_name': byName,
      'at': nowIso,
    });
    notifyListeners();
  }

  Future<int?> createCustomer({
    required String name,
    required String phone,
    required String dob,
    required String address,
    required String branch,
    required int agentId,
    String stage = 'lead',
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final id = await db.insert('customers', {
        'name': name,
        'phone': phone,
        'dob': dob,
        'address': address,
        'branch': branch,
        'agent_id': agentId,
        'stage': stage,
        'kyc_status': 'pending',
        'wa_verified': 0,
        'created': nowIso,
      });
      await fetchCustomers();
      return id;
    } catch (e) {
      debugPrint('Error creating customer: $e');
      return null;
    }
  }

  Future<bool> saveKycForm({
    required int customerId,
    required int agentId,
    required String centerNo,
    required String groupNo,
    required String guardianType,
    required String guardianName,
    required String education,
    required String religion,
    required String category,
    required String houseNo,
    required String village,
    required String postOffice,
    required String district,
    required String state,
    required String pincode,
    required String houseType,
    required double landHa,
    required String livestock,
    required String bankName,
    required String bankAcct,
    required String passbookName,
    required String povertyLine,
    required double annualIncome,
    String husbandName = '',
    String husbandFather = '',
    String husbandDob = '',
    int consentGiven = 0,
    int addressVerified = 1,
    String verifiedBy = '',
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowIso = DateTime.now().toIso8601String().substring(0, 19);
      final todayStr = nowIso.substring(0, 10);

      final existing = await db.query('kyc_forms', where: 'customer_id = ?', whereArgs: [customerId]);

      final formMap = {
        'customer_id': customerId,
        'created_by': agentId,
        'created_at': nowIso,
        'updated_at': nowIso,
        'form_date': todayStr,
        'center_no': centerNo,
        'group_no': groupNo,
        'guardian_type': guardianType,
        'guardian_name': guardianName,
        'education': education,
        'religion': religion,
        'category': category,
        'house_no': houseNo,
        'village': village,
        'post_office': postOffice,
        'district': district,
        'state': state,
        'pincode': pincode,
        'family': jsonEncode([]),
        'house_type': houseType,
        'land_ha': landHa,
        'livestock': livestock,
        'bank_name': bankName,
        'bank_acct': bankAcct,
        'passbook_name': passbookName,
        'poverty_line': povertyLine,
        'dist_center_m': 300.0,
        'dist_branch_km': 4.0,
        'relative_in_center': 'no',
        'annual_income': annualIncome,
        'other_loans': 0,
        'current_debt': 0.0,
        'repay_freq': 'monthly',
        'h_name': husbandName,
        'h_father': husbandFather,
        'h_dob': husbandDob,
        'consent_given': consentGiven,
        'consent_date': consentGiven == 1 ? todayStr : '',
        'declaration': 1,
        'bureau_consent': 1,
        'address_verified': addressVerified,
        'verified_by': verifiedBy,
        'verified_on': todayStr,
      };

      if (existing.isEmpty) {
        await db.insert('kyc_forms', formMap);
      } else {
        await db.update('kyc_forms', formMap, where: 'customer_id = ?', whereArgs: [customerId]);
      }

      await db.update(
        'customers',
        {'kyc_status': 'verified', 'stage': 'customer'},
        where: 'id = ?',
        whereArgs: [customerId],
      );

      await fetchCustomers();
      return true;
    } catch (e) {
      debugPrint('Error saving KYC form: $e');
      return false;
    }
  }

  Future<bool> verifyKycDocuments({
    required int customerId,
    required String aadhaar,
    required String pan,
    required String voter,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final maskedAadhaar = 'XXXXXXXX${aadhaar.replaceAll(' ', '').substring(max(0, aadhaar.replaceAll(' ', '').length - 4))}';

      await db.update(
        'customers',
        {
          'aadhaar': maskedAadhaar,
          'pan': pan.toUpperCase().trim(),
          'voter': voter.toUpperCase().trim(),
          'kyc_status': 'verified',
        },
        where: 'id = ?',
        whereArgs: [customerId],
      );

      await fetchCustomers();
      return true;
    } catch (e) {
      debugPrint('Error verifying KYC: $e');
      return false;
    }
  }

  Future<bool> verifyWhatsAppOtp(int customerId, String otp) async {
    if (otp == '123456') {
      final db = await DatabaseHelper.instance.database;
      await db.update('customers', {'wa_verified': 1}, where: 'id = ?', whereArgs: [customerId]);
      await fetchCustomers();
      return true;
    }
    return false;
  }
}
