import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = Platform.isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000';
  String? _sessionCookie;

  String get baseUrl => _baseUrl;
  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  void _updateCookie(http.Response response) {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      final index = rawCookie.indexOf(';');
      _sessionCookie = (index != -1) ? rawCookie.substring(0, index) : rawCookie;
    }
  }

  /// Login to backend
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final uri = Uri.parse('$_baseUrl/login');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'username': username, 'password': password},
          )
          .timeout(const Duration(seconds: 8));

      _updateCookie(res);

      if (res.statusCode == 200 || res.statusCode == 302) {
        if (_sessionCookie != null) {
          await SecureStorageService().write('session_cookie', _sessionCookie!);
        }
        return {'success': true, 'statusCode': res.statusCode};
      }
      return {'success': false, 'statusCode': res.statusCode, 'message': 'Invalid credentials'};
    } catch (e) {
      debugPrint('ApiService.login error: $e');
      return {'success': false, 'isOffline': true, 'error': e.toString()};
    }
  }

  /// Calculate EMI from server
  Future<double?> calculateEmi({
    required double principal,
    required double rate,
    required int tenureMonths,
    required String method,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/emi');
      final res = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode({
              'p': principal,
              'r': rate,
              'n': tenureMonths,
              'm': method,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['emi'] as num?)?.toDouble();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Punch Attendance
  Future<Map<String, dynamic>> punchAttendance({
    required int userId,
    required String type, // 'in' or 'out'
    required double lat,
    required double lng,
  }) async {
    try {
      final now = DateTime.now();
      final day = now.toIso8601String().substring(0, 10);
      final time = now.toIso8601String().substring(11, 16);

      final uri = Uri.parse('$_baseUrl/attendance/punch');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'user_id': userId.toString(),
              'day': day,
              'type': type,
              'time': time,
              'lat': lat.toString(),
              'lng': lng.toString(),
            },
          )
          .timeout(const Duration(seconds: 8));

      return {'success': res.statusCode == 200 || res.statusCode == 302};
    } catch (e) {
      return {'success': false, 'isOffline': true, 'error': e.toString()};
    }
  }

  /// Apply for Leave
  Future<bool> applyLeave({
    required int userId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required int days,
    required String reason,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/hrm/leave');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'user_id': userId.toString(),
              'leave_type': leaveType,
              'from_d': fromDate,
              'to_d': toDate,
              'days': days.toString(),
              'reason': reason,
            },
          )
          .timeout(const Duration(seconds: 8));

      return res.statusCode == 200 || res.statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  /// Verify KYC Document with government simulation
  Future<Map<String, dynamic>> verifyKycDocument({
    required int customerId,
    required String docType, // 'aadhaar', 'pan', 'voter'
    required String value,
    String? otp,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/kyc/verify');
      final res = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode({
              'customer_id': customerId,
              'type': docType,
              'value': value,
              if (otp != null) 'otp': otp,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'HTTP ${res.statusCode}'};
    } catch (e) {
      return {'status': 'offline', 'message': e.toString()};
    }
  }

  /// Record EMI Payment
  Future<bool> recordRepayment({
    required int loanId,
    required double amount,
    required String payDate,
    required String mode,
    required String txnRef,
    required String remarks,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/pay/$loanId');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'amount': amount.toString(),
              'pay_date': payDate,
              'mode': mode,
              'txn_ref': txnRef,
              'remarks': remarks,
            },
          )
          .timeout(const Duration(seconds: 8));

      return res.statusCode == 200 || res.statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  /// Pull latest Sync Bundle from Server
  Future<Map<String, dynamic>?> fetchSyncBundle() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/sync');
      final res = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('fetchSyncBundle offline: $e');
      return null;
    }
  }

  /// Push Offline Queue to Server
  Future<bool> pushOfflineQueue(List<Map<String, dynamic>> items) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/sync');
      final res = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode({
              'sync_id': DateTime.now().millisecondsSinceEpoch,
              'queue': items,
            }),
          )
          .timeout(const Duration(seconds: 12));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

