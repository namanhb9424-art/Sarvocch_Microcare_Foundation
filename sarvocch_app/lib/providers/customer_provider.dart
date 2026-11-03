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
        SELECT c.*, 
               k.center_no, k.group_no, k.guardian_type, k.guardian_name, k.education,
               k.religion, k.category, k.house_type, k.land_ha, k.livestock,
               k.bank_name, k.bank_acct, k.passbook_name, k.poverty_line,
               k.dist_center_m, k.dist_branch_km, k.relative_in_center, k.relative_name,
               k.annual_income, k.other_loans, k.current_debt, k.repay_freq,
               k.photo, k.h_name, k.h_father, k.h_dob, k.h_address, k.h_photo,
               k.consent_given, k.consent_date, k.declaration, k.bureau_consent,
               k.address_verified, k.verified_by, k.verified_on, k.verify_remarks,
               k.signed_copy, k.co_name, k.co_phone, k.co_relation, k.co_income,
               k.family
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
    double distCenterM = 300.0,
    double distBranchKm = 4.0,
    String relativeInCenter = 'no',
    String relativeName = '',
    int otherLoans = 0,
    double currentDebt = 0.0,
    String repayFreq = 'monthly',
    String coName = '',
    String coPhone = '',
    String coRelation = '',
    double coIncome = 0.0,
    String? photo,
    String husbandName = '',
    String husbandFather = '',
    String husbandDob = '',
    String husbandAddress = '',
    String? husbandPhoto,
    int consentGiven = 0,
    int declaration = 1,
    int bureauConsent = 1,
    int addressVerified = 1,
    String verifiedBy = '',
    String verifyRemarks = '',
    String? signedCopy,
    List<Map<String, dynamic>> family = const [],
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
        'family': jsonEncode(family),
        'house_type': houseType,
        'land_ha': landHa,
        'livestock': livestock,
        'bank_name': bankName,
        'bank_acct': bankAcct,
        'passbook_name': passbookName,
        'poverty_line': povertyLine,
        'dist_center_m': distCenterM,
        'dist_branch_km': distBranchKm,
        'relative_in_center': relativeInCenter,
        'relative_name': relativeName,
        'annual_income': annualIncome,
        'other_loans': otherLoans,
        'current_debt': currentDebt,
        'repay_freq': repayFreq,
        'photo': photo ?? (existing.isNotEmpty ? existing.first['photo'] : null),
        'h_name': husbandName,
        'h_father': husbandFather,
        'h_dob': husbandDob,
        'h_address': husbandAddress,
        'h_photo': husbandPhoto ?? (existing.isNotEmpty ? existing.first['h_photo'] : null),
        'consent_given': consentGiven,
        'consent_date': consentGiven == 1 ? todayStr : '',
        'declaration': declaration,
        'bureau_consent': bureauConsent,
        'address_verified': addressVerified,
        'verified_by': verifiedBy,
        'verified_on': todayStr,
        'verify_remarks': verifyRemarks,
        'signed_copy': signedCopy ?? (existing.isNotEmpty ? existing.first['signed_copy'] : null),
        'co_name': coName,
        'co_phone': coPhone,
        'co_relation': coRelation,
        'co_income': coIncome,
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
