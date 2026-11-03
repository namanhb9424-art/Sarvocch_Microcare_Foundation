import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'dart:math';

class DemoSeedData {
  static Future<void> seedDatabase(Database db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowIso = now.toIso8601String().substring(0, 19);
    final todayStr = today.toIso8601String().substring(0, 10);

    // 1. Branches
    final branches = [
      {'name': 'Indore - Vijay Nagar', 'code': 'IND-VN', 'address': 'Vijay Nagar, Indore, MP', 'phone': '0731-255001', 'head_name': 'Meera Manager', 'lat': 22.7533, 'lng': 75.8937, 'radius_m': 2000},
      {'name': 'Indore - Palasia', 'code': 'IND-PL', 'address': 'Palasia, Indore, MP', 'phone': '0731-255002', 'head_name': 'Sneha Field Officer', 'lat': 22.7241, 'lng': 75.8839, 'radius_m': 2000},
      {'name': 'Bhopal - MP Nagar', 'code': 'BPL-MP', 'address': 'MP Nagar, Bhopal, MP', 'phone': '0755-244001', 'head_name': 'Imran Field Officer', 'lat': 23.2332, 'lng': 77.4340, 'radius_m': 2000},
      {'name': 'Pipariya Branch', 'code': 'PPR', 'address': 'Pipariya, Madhya Pradesh', 'phone': '07576-22001', 'head_name': 'Ravi Field Officer', 'lat': 22.7388, 'lng': 78.3563, 'radius_m': 2500},
      {'name': 'Bhopal Head Office', 'code': 'BPL-HO', 'address': 'Bhopal Office, Arera Hills, Bhopal', 'phone': '0755-288000', 'head_name': 'Aarav Admin', 'lat': 23.2799, 'lng': 77.4522, 'radius_m': 3000},
    ];

    for (var b in branches) {
      await db.insert('branches', b);
    }

    // 2. Users (Demo Logins for all possible roles)
    // admin/admin123, manager1/manager123, uw1/uw123, agent1-3/agent123, cust1/cust123
    final users = [
      {'id': 1, 'username': 'admin', 'pw': 'admin123', 'name': 'Aarav Admin', 'role': 'admin', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000001'},
      {'id': 2, 'username': 'manager1', 'pw': 'manager123', 'name': 'Meera Manager', 'role': 'manager', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000002'},
      {'id': 3, 'username': 'uw1', 'pw': 'uw123', 'name': 'Uday Underwriter', 'role': 'underwriter', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000003'},
      {'id': 4, 'username': 'agent1', 'pw': 'agent123', 'name': 'Ravi Field Officer', 'role': 'field_agent', 'branch': 'Indore - Vijay Nagar', 'phone': '9800000004', 'lat': 22.7510, 'lng': 75.8900},
      {'id': 5, 'username': 'agent2', 'pw': 'agent123', 'name': 'Sneha Field Officer', 'role': 'field_agent', 'branch': 'Indore - Palasia', 'phone': '9800000005', 'lat': 22.7240, 'lng': 75.8830},
      {'id': 6, 'username': 'agent3', 'pw': 'agent123', 'name': 'Imran Field Officer', 'role': 'field_agent', 'branch': 'Bhopal - MP Nagar', 'phone': '9800000006', 'lat': 23.2330, 'lng': 77.4340},
      {'id': 7, 'username': 'cust1', 'pw': 'cust123', 'name': 'Sunita Verma', 'role': 'customer', 'branch': 'Indore - Vijay Nagar', 'phone': '9811111111', 'customer_id': 1},
    ];

    for (var u in users) {
      await db.insert('users', u);
    }

    // 3. Employees
    final employees = [
      {'id': 1, 'user_id': 1, 'name': 'Aarav Admin', 'designation': 'Director', 'branch': 'Indore - Vijay Nagar', 'manager_id': null, 'phone': '9800000001', 'email': 'admin@sarvocch.demo', 'joined': '2024-01-01', 'status': 'active', 'bg_check': 'cleared', 'docs': '["Aadhaar","PAN","Degree"]', 'salary': 90000.0},
      {'id': 2, 'user_id': 2, 'name': 'Meera Manager', 'designation': 'Regional Manager', 'branch': 'Indore - Vijay Nagar', 'manager_id': 1, 'phone': '9800000002', 'email': 'manager1@sarvocch.demo', 'joined': '2024-03-01', 'status': 'active', 'bg_check': 'cleared', 'docs': '["Aadhaar","PAN","Experience"]', 'salary': 60000.0},
      {'id': 3, 'user_id': 3, 'name': 'Uday Underwriter', 'designation': 'Credit Underwriter', 'branch': 'Indore - Vijay Nagar', 'manager_id': 2, 'phone': '9800000003', 'email': 'uw1@sarvocch.demo', 'joined': '2024-06-01', 'status': 'active', 'bg_check': 'cleared', 'docs': '["Aadhaar","PAN","Certifications"]', 'salary': 45000.0},
      {'id': 4, 'user_id': 4, 'name': 'Ravi Field Officer', 'designation': 'Field Officer', 'branch': 'Indore - Vijay Nagar', 'manager_id': 2, 'phone': '9800000004', 'email': 'agent1@sarvocch.demo', 'joined': '2024-08-01', 'status': 'active', 'bg_check': 'cleared', 'docs': '["Aadhaar","PAN","Driving License"]', 'salary': 25000.0},
      {'id': 5, 'user_id': 5, 'name': 'Sneha Field Officer', 'designation': 'Field Officer', 'branch': 'Indore - Palasia', 'manager_id': 2, 'phone': '9800000005', 'email': 'agent2@sarvocch.demo', 'joined': '2024-08-15', 'status': 'active', 'bg_check': 'cleared', 'docs': '["Aadhaar","PAN"]', 'salary': 25000.0},
      {'id': 6, 'user_id': 6, 'name': 'Imran Field Officer', 'designation': 'Field Officer', 'branch': 'Bhopal - MP Nagar', 'manager_id': 2, 'phone': '9800000006', 'email': 'agent3@sarvocch.demo', 'joined': '2024-09-01', 'status': 'active', 'bg_check': 'cleared', 'docs': '["Aadhaar","PAN"]', 'salary': 25000.0},
      {'id': 7, 'user_id': null, 'name': 'Pooja New-Joiner', 'designation': 'Field Officer Trainee', 'branch': 'Indore - Palasia', 'manager_id': 2, 'phone': '9800000099', 'email': 'pooja@sarvocch.demo', 'joined': todayStr, 'status': 'onboarding', 'bg_check': 'in_progress', 'docs': '["Aadhaar","PAN"]', 'salary': 22000.0},
    ];

    for (var e in employees) {
      await db.insert('employees', e);
    }

    // 4. Products
    final products = [
      {'id': 1, 'name': 'Micro Business Loan', 'rate': 18.0, 'min_amt': 10000.0, 'max_amt': 100000.0, 'min_tenure': 6, 'max_tenure': 24, 'method': 'reducing', 'fee_pct': 2.0, 'active': 1},
      {'id': 2, 'name': 'Income Generation Loan', 'rate': 22.0, 'min_amt': 5000.0, 'max_amt': 50000.0, 'min_tenure': 6, 'max_tenure': 18, 'method': 'flat', 'fee_pct': 1.5, 'active': 1},
      {'id': 3, 'name': 'Emergency Loan', 'rate': 24.0, 'min_amt': 2000.0, 'max_amt': 25000.0, 'min_tenure': 3, 'max_tenure': 12, 'method': 'reducing', 'fee_pct': 1.0, 'active': 1},
    ];

    for (var p in products) {
      await db.insert('products', p);
    }

    // 5. Customers
    final customers = [
      {'id': 1, 'name': 'Sunita Verma', 'phone': '9811111111', 'dob': '1988-04-12', 'address': '12 Vijay Nagar, Indore', 'branch': 'Indore - Vijay Nagar', 'agent_id': 4, 'stage': 'customer', 'aadhaar': 'XXXXXXXX8901', 'pan': 'ABCPE1230F', 'voter': 'MP0123401', 'kyc_status': 'verified', 'wa_verified': 1, 'created': '2024-03-10T10:00:00'},
      {'id': 2, 'name': 'Rajesh Patel', 'phone': '9822222222', 'dob': '1985-09-03', 'address': '45 Palasia, Indore', 'branch': 'Indore - Palasia', 'agent_id': 5, 'stage': 'customer', 'aadhaar': 'XXXXXXXX8902', 'pan': 'ABCPE1231F', 'voter': 'MP0123402', 'kyc_status': 'verified', 'wa_verified': 1, 'created': '2024-04-15T10:00:00'},
      {'id': 3, 'name': 'Kavita Sharma', 'phone': '9833333333', 'dob': '1990-01-25', 'address': '7 Bhawarkuan, Indore', 'branch': 'Indore - Vijay Nagar', 'agent_id': 4, 'stage': 'customer', 'aadhaar': 'XXXXXXXX8903', 'pan': 'ABCPE1232F', 'voter': 'MP0123403', 'kyc_status': 'verified', 'wa_verified': 0, 'created': '2024-05-20T10:00:00'},
      {'id': 4, 'name': 'Mohan Lal', 'phone': '9844444444', 'dob': '1979-11-30', 'address': '88 Rajwada, Indore', 'branch': 'Indore - Vijay Nagar', 'agent_id': 4, 'stage': 'customer', 'aadhaar': 'XXXXXXXX8904', 'pan': 'ABCPE1233F', 'voter': 'MP0123404', 'kyc_status': 'verified', 'wa_verified': 0, 'created': '2024-06-12T10:00:00'},
      {'id': 5, 'name': 'Farida Khan', 'phone': '9855555555', 'dob': '1992-06-18', 'address': '21 MP Nagar, Bhopal', 'branch': 'Bhopal - MP Nagar', 'agent_id': 6, 'stage': 'prospect', 'aadhaar': null, 'pan': null, 'voter': null, 'kyc_status': 'pending', 'wa_verified': 0, 'created': '2024-07-01T10:00:00'},
      {'id': 6, 'name': 'Deepak Joshi', 'phone': '9866666666', 'dob': '1987-02-09', 'address': '3 Rau, Indore', 'branch': 'Indore - Palasia', 'agent_id': 5, 'stage': 'lead', 'aadhaar': null, 'pan': null, 'voter': null, 'kyc_status': 'pending', 'wa_verified': 0, 'created': '2024-08-01T10:00:00'},
      {'id': 7, 'name': 'Anita Yadav', 'phone': '9877777777', 'dob': '1995-12-01', 'address': '19 Sarafa, Indore', 'branch': 'Indore - Vijay Nagar', 'agent_id': 4, 'stage': 'lead', 'aadhaar': null, 'pan': null, 'voter': null, 'kyc_status': 'pending', 'wa_verified': 0, 'created': '2024-08-10T10:00:00'},
      {'id': 8, 'name': 'Vikram Singh', 'phone': '9888888888', 'dob': '1983-07-21', 'address': '54 Vijay Nagar, Indore', 'branch': 'Indore - Vijay Nagar', 'agent_id': 4, 'stage': 'prospect', 'aadhaar': null, 'pan': null, 'voter': null, 'kyc_status': 'pending', 'wa_verified': 0, 'created': '2024-08-25T10:00:00'},
    ];

    for (var c in customers) {
      await db.insert('customers', c);
    }

    // 6. KYC Forms (Bilingual form data)
    final kycList = [
      {
        'customer_id': 1,
        'created_by': 4,
        'created_at': nowIso,
        'updated_at': nowIso,
        'form_date': '2024-03-10',
        'center_no': 'C-101',
        'group_no': 'G-A',
        'guardian_type': 'husband',
        'guardian_name': 'Ramesh Verma',
        'education': 'Secondary (10th)',
        'religion': 'Hindu',
        'category': 'OBC',
        'house_no': '12',
        'village': 'Vijay Nagar',
        'post_office': 'Vijay Nagar PO',
        'district': 'Indore',
        'state': 'Madhya Pradesh',
        'pincode': '452010',
        'family': jsonEncode([
          {'name': 'Sunita Verma', 'age': 38, 'edu': 'Secondary (10th)', 'rel': 'Self', 'occ': 'Tailoring'},
          {'name': 'Ramesh Verma', 'age': 42, 'edu': 'Secondary (10th)', 'rel': 'Husband', 'occ': 'Shopkeeper'},
          {'name': 'Aarav Verma', 'age': 14, 'edu': 'Class 8', 'rel': 'Son', 'occ': 'Student'},
        ]),
        'house_type': 'pucca',
        'land_ha': 0.0,
        'livestock': '1 cow, 2 goats',
        'bank_name': 'State Bank of India',
        'bank_acct': '30123456780',
        'passbook_name': 'Sunita Verma',
        'poverty_line': 'APL',
        'dist_center_m': 300.0,
        'dist_branch_km': 4.5,
        'relative_in_center': 'no',
        'annual_income': 216000.0,
        'other_loans': 0,
        'current_debt': 0.0,
        'repay_freq': 'monthly',
        'h_name': 'Ramesh Verma',
        'h_father': 'Suresh Verma',
        'h_dob': '1984-03-02',
        'h_address': '12 Vijay Nagar, Indore',
        'consent_given': 1,
        'consent_date': '2024-03-10',
        'declaration': 1,
        'bureau_consent': 1,
        'address_verified': 1,
        'verified_by': 'Ravi Field Officer',
        'verified_on': '2024-03-12',
      },
      {
        'customer_id': 2,
        'created_by': 5,
        'created_at': nowIso,
        'updated_at': nowIso,
        'form_date': '2024-04-15',
        'center_no': 'C-202',
        'group_no': 'G-B',
        'guardian_type': 'father',
        'guardian_name': 'Mohanlal Patel',
        'education': 'Senior Secondary (12th)',
        'religion': 'Hindu',
        'category': 'General',
        'house_no': '45',
        'village': 'Palasia',
        'post_office': 'Palasia PO',
        'district': 'Indore',
        'state': 'Madhya Pradesh',
        'pincode': '452001',
        'family': jsonEncode([
          {'name': 'Rajesh Patel', 'age': 41, 'edu': '12th', 'rel': 'Self', 'occ': 'Kirana Store'},
        ]),
        'house_type': 'pucca',
        'land_ha': 0.5,
        'livestock': 'none',
        'bank_name': 'Bank of Baroda',
        'bank_acct': '30123456781',
        'passbook_name': 'Rajesh Patel',
        'poverty_line': 'APL',
        'dist_center_m': 450.0,
        'dist_branch_km': 2.0,
        'relative_in_center': 'no',
        'annual_income': 240000.0,
        'other_loans': 0,
        'current_debt': 0.0,
        'repay_freq': 'monthly',
        'h_name': '',
        'h_father': '',
        'consent_given': 0,
        'declaration': 1,
        'bureau_consent': 1,
        'address_verified': 1,
        'verified_by': 'Sneha Field Officer',
        'verified_on': '2024-04-16',
      },
      {
        'customer_id': 3,
        'created_by': 4,
        'created_at': nowIso,
        'updated_at': nowIso,
        'form_date': '2024-05-20',
        'center_no': 'C-101',
        'group_no': 'G-A',
        'guardian_type': 'husband',
        'guardian_name': 'Anil Sharma',
        'education': 'Secondary (10th)',
        'religion': 'Hindu',
        'category': 'General',
        'house_no': '7',
        'village': 'Bhawarkuan',
        'post_office': 'Bhawarkuan PO',
        'district': 'Indore',
        'state': 'Madhya Pradesh',
        'pincode': '452014',
        'family': jsonEncode([
          {'name': 'Kavita Sharma', 'age': 36, 'edu': '10th', 'rel': 'Self', 'occ': 'Dairy / Milk sales'},
        ]),
        'house_type': 'pucca',
        'land_ha': 0.2,
        'livestock': '1 cow, 1 buffalo',
        'bank_name': 'Punjab National Bank',
        'bank_acct': '30123456782',
        'passbook_name': 'Kavita Sharma',
        'poverty_line': 'APL',
        'dist_center_m': 200.0,
        'dist_branch_km': 6.0,
        'relative_in_center': 'no',
        'annual_income': 190000.0,
        'other_loans': 0,
        'current_debt': 0.0,
        'repay_freq': 'monthly',
        'h_name': 'Anil Sharma',
        'h_father': 'Gopal Sharma',
        'h_dob': '1986-08-19',
        'consent_given': 1,
        'consent_date': '2024-05-20',
        'declaration': 1,
        'bureau_consent': 1,
        'address_verified': 1,
        'verified_by': 'Ravi Field Officer',
        'verified_on': '2024-05-22',
      },
      {
        'customer_id': 4,
        'created_by': 4,
        'created_at': nowIso,
        'updated_at': nowIso,
        'form_date': '2024-06-12',
        'center_no': 'C-101',
        'group_no': 'G-C',
        'guardian_type': 'father',
        'guardian_name': 'Ramlal',
        'education': 'Primary (5th)',
        'religion': 'Hindu',
        'category': 'SC',
        'house_no': '88',
        'village': 'Rajwada',
        'post_office': 'Rajwada PO',
        'district': 'Indore',
        'state': 'Madhya Pradesh',
        'pincode': '452002',
        'family': '[]',
        'house_type': 'kutcha',
        'land_ha': 0.0,
        'livestock': 'none',
        'bank_name': 'State Bank of India',
        'bank_acct': '30123456783',
        'passbook_name': 'Mohan Lal',
        'poverty_line': 'BPL',
        'dist_center_m': 600.0,
        'dist_branch_km': 5.0,
        'relative_in_center': 'no',
        'annual_income': 96000.0,
        'other_loans': 0,
        'current_debt': 0.0,
        'repay_freq': 'monthly',
        'declaration': 1,
        'bureau_consent': 1,
        'address_verified': 1,
        'verified_by': 'Ravi Field Officer',
        'verified_on': '2024-06-14',
      },
    ];

    for (var k in kycList) {
      await db.insert('kyc_forms', k);
    }

    // 7. Comm Logs
    await db.insert('comm_logs', {
      'customer_id': 1,
      'channel': 'call',
      'note': 'Reminded about upcoming EMI installment via phone call',
      'by_name': 'Ravi Field Officer',
      'at': nowIso,
    });
    await db.insert('comm_logs', {
      'customer_id': 6,
      'channel': 'visit',
      'note': 'Home visit completed. Interested in Business Loan, gathering electricity bill',
      'by_name': 'Sneha Field Officer',
      'at': nowIso,
    });

    // 8. Helper to calculate EMI schedule and insert
    Future<int> seedLoanWithSchedule({
      required int appId,
      required int custId,
      required int prodId,
      required double principal,
      required double rate,
      required int tenure,
      required String method,
      required DateTime startDate,
      required String status,
      String? closureDate,
      required String branch,
      required int agentId,
      required int paidInstallments,
      required String payChannel,
    }) async {
      double emi;
      if (method == 'flat') {
        emi = ((principal + (principal * rate / 100 * tenure / 12)) / tenure);
      } else {
        final r = rate / 1200;
        emi = (principal * r * pow(1 + r, tenure) / (pow(1 + r, tenure) - 1));
      }
      emi = double.parse(emi.toStringAsFixed(2));

      final loanId = await db.insert('loans', {
        'application_id': appId,
        'customer_id': custId,
        'product_id': prodId,
        'principal': principal,
        'rate': rate,
        'tenure': tenure,
        'method': method,
        'emi': emi,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'status': status,
        'closure_date': closureDate,
        'branch': branch,
        'agent_id': agentId,
      });

      double bal = principal;
      for (int i = 1; i <= tenure; i++) {
        double interest;
        double prin;
        if (method == 'flat') {
          interest = double.parse((principal * rate / 100 / 12).toStringAsFixed(2));
          prin = double.parse((principal / tenure).toStringAsFixed(2));
        } else {
          interest = double.parse((bal * rate / 1200).toStringAsFixed(2));
          prin = double.parse((emi - interest).toStringAsFixed(2));
        }
        if (i == tenure) {
          prin = double.parse(bal.toStringAsFixed(2));
        }
        bal = double.parse(max(0, bal - prin).toStringAsFixed(2));

        // Skip weekend to Monday
        var due = DateTime(startDate.year, startDate.month + i, startDate.day);
        if (due.weekday == DateTime.saturday) due = due.add(const Duration(days: 2));
        if (due.weekday == DateTime.sunday) due = due.add(const Duration(days: 1));
        final dueStr = due.toIso8601String().substring(0, 10);

        final isPaid = i <= paidInstallments ? 1 : 0;
        final paidOn = isPaid == 1 ? dueStr : null;

        final schedId = await db.insert('schedule', {
          'loan_id': loanId,
          'no': i,
          'due_date': dueStr,
          'emi': emi,
          'principal': prin,
          'interest': interest,
          'balance': bal,
          'paid': isPaid,
          'paid_on': paidOn,
        });

        if (isPaid == 1) {
          await db.insert('payments', {
            'loan_id': loanId,
            'schedule_id': schedId,
            'amount': emi,
            'channel': payChannel,
            'ref': '${payChannel.toUpperCase()}${100000 + schedId}',
            'at': '${dueStr}T11:00:00',
          });
        }
      }

      return loanId;
    }

    // Helper for Application
    Future<int> seedApp({
      required int custId,
      required int prodId,
      required double amount,
      required int tenure,
      required double rate,
      required String status,
      required int agentId,
      required String branch,
      required String createdDate,
    }) async {
      final appId = await db.insert('applications', {
        'customer_id': custId,
        'product_id': prodId,
        'amount': amount,
        'tenure': tenure,
        'rate': rate,
        'purpose': 'Small Business & Inventory Expansion',
        'income': 30000.0,
        'occupation': 'Shop Owner',
        'employer': 'Self Employed',
        'co_name': 'Family Member',
        'co_phone': '9899999999',
        'co_relation': 'Spouse',
        'co_income': 12000.0,
        'status': status,
        'agent_id': agentId,
        'branch': branch,
        'created': createdDate,
        'docs': '["Aadhaar","Voter ID","Bank Passbook"]',
      });

      await db.insert('app_extra', {
        'application_id': appId,
        'prev_loans': '[]',
        'insurance_wanted': 'yes',
        'insurance_for': 'husband',
        'docs_deposited': '["aadhaar","voter"]',
        'docs_other': '',
        'inc_agri': 0.0,
        'inc_business': 24000.0,
        'inc_job': 0.0,
        'inc_other': 6000.0,
        'exp_basic': 9000.0,
        'exp_education': 2000.0,
        'exp_festival': 1500.0,
        'exp_health': 1000.0,
        'exp_emi': 0.0,
        'exp_other': 1500.0,
        'group_rec': amount,
        'center_rec': amount,
        'loan_cycle': 1,
        'requested_amt': amount,
        'income_total': 30000.0,
        'expense_total': 15000.0,
        'net_saving': 15000.0,
        'declaration': 1,
      });

      await db.insert('approvals', {
        'application_id': appId,
        'stage': 'Submitted',
        'by_user': 'Ravi Field Officer',
        'by_role': 'field_agent',
        'amount': amount,
        'remarks': 'KYC and initial visit completed',
        'at': createdDate,
      });

      if (['under_review', 'approved', 'sanctioned', 'disbursed'].contains(status)) {
        await db.insert('approvals', {
          'application_id': appId,
          'stage': 'Under Review',
          'by_user': 'Uday Underwriter',
          'by_role': 'underwriter',
          'amount': amount,
          'remarks': 'Credit score verified, cashflow positive',
          'at': createdDate,
        });
      }
      if (['approved', 'sanctioned', 'disbursed'].contains(status)) {
        await db.insert('approvals', {
          'application_id': appId,
          'stage': 'Approved',
          'by_user': 'Uday Underwriter',
          'by_role': 'underwriter',
          'amount': amount,
          'remarks': 'Approved within branch limit',
          'at': createdDate,
        });
      }
      if (['sanctioned', 'disbursed'].contains(status)) {
        await db.insert('approvals', {
          'application_id': appId,
          'stage': 'Sanctioned',
          'by_user': 'Meera Manager',
          'by_role': 'manager',
          'amount': amount,
          'remarks': 'Sanction letter generated and signed',
          'at': createdDate,
        });
      }
      if (status == 'disbursed') {
        await db.insert('approvals', {
          'application_id': appId,
          'stage': 'Disbursed',
          'by_user': 'Meera Manager',
          'by_role': 'manager',
          'amount': amount,
          'remarks': 'Disbursed to borrower account via NEFT',
          'at': createdDate,
        });
      }

      return appId;
    }

    // 9. Seed Demo Loans (Active, Closed, Overdue, Autopay)
    // Loan 1: Active, 2 paid, overdue
    final a1 = await seedApp(
      custId: 1,
      prodId: 1,
      amount: 60000.0,
      tenure: 12,
      rate: 18.0,
      status: 'disbursed',
      agentId: 4,
      branch: 'Indore - Vijay Nagar',
      createdDate: today.subtract(const Duration(days: 120)).toIso8601String().substring(0, 10),
    );
    await seedLoanWithSchedule(
      appId: a1,
      custId: 1,
      prodId: 1,
      principal: 60000.0,
      rate: 18.0,
      tenure: 12,
      method: 'reducing',
      startDate: today.subtract(const Duration(days: 110)),
      status: 'active',
      branch: 'Indore - Vijay Nagar',
      agentId: 4,
      paidInstallments: 2,
      payChannel: 'upi',
    );

    // Loan 2: Closed 20 days ago (NOC Eligible)
    final a2 = await seedApp(
      custId: 2,
      prodId: 3,
      amount: 12000.0,
      tenure: 6,
      rate: 24.0,
      status: 'disbursed',
      agentId: 5,
      branch: 'Indore - Palasia',
      createdDate: today.subtract(const Duration(days: 230)).toIso8601String().substring(0, 10),
    );
    await seedLoanWithSchedule(
      appId: a2,
      custId: 2,
      prodId: 3,
      principal: 12000.0,
      rate: 24.0,
      tenure: 6,
      method: 'reducing',
      startDate: today.subtract(const Duration(days: 200)),
      status: 'closed',
      closureDate: today.subtract(const Duration(days: 20)).toIso8601String().substring(0, 10),
      branch: 'Indore - Palasia',
      agentId: 5,
      paidInstallments: 6,
      payChannel: 'card',
    );

    // Loan 3: Active with AutoPay / eNACH
    final a3 = await seedApp(
      custId: 3,
      prodId: 2,
      amount: 20000.0,
      tenure: 10,
      rate: 22.0,
      status: 'disbursed',
      agentId: 4,
      branch: 'Indore - Vijay Nagar',
      createdDate: today.subtract(const Duration(days: 70)).toIso8601String().substring(0, 10),
    );
    final l3 = await seedLoanWithSchedule(
      appId: a3,
      custId: 3,
      prodId: 2,
      principal: 20000.0,
      rate: 22.0,
      tenure: 10,
      method: 'flat',
      startDate: today.subtract(const Duration(days: 62)),
      status: 'active',
      branch: 'Indore - Vijay Nagar',
      agentId: 4,
      paidInstallments: 1,
      payChannel: 'autopay',
    );
    await db.insert('mandates', {
      'loan_id': l3,
      'mtype': 'eNACH',
      'bank': 'PNB',
      'acct_last4': '4321',
      'status': 'active',
      'created': nowIso,
    });

    // Loan 4: Closed 5 days ago (NOC pending 15-day clearance)
    final a4 = await seedApp(
      custId: 4,
      prodId: 3,
      amount: 6000.0,
      tenure: 3,
      rate: 24.0,
      status: 'disbursed',
      agentId: 4,
      branch: 'Indore - Vijay Nagar',
      createdDate: today.subtract(const Duration(days: 130)).toIso8601String().substring(0, 10),
    );
    await seedLoanWithSchedule(
      appId: a4,
      custId: 4,
      prodId: 3,
      principal: 6000.0,
      rate: 24.0,
      tenure: 3,
      method: 'reducing',
      startDate: today.subtract(const Duration(days: 100)),
      status: 'closed',
      closureDate: today.subtract(const Duration(days: 5)).toIso8601String().substring(0, 10),
      branch: 'Indore - Vijay Nagar',
      agentId: 4,
      paidInstallments: 3,
      payChannel: 'cash',
    );

    // 10. Pipeline Applications (Submitted, Under Review, Approved)
    await seedApp(
      custId: 8,
      prodId: 1,
      amount: 40000.0,
      tenure: 12,
      rate: 18.0,
      status: 'submitted',
      agentId: 4,
      branch: 'Indore - Vijay Nagar',
      createdDate: todayStr,
    );
    await seedApp(
      custId: 5,
      prodId: 3,
      amount: 10000.0,
      tenure: 6,
      rate: 24.0,
      status: 'under_review',
      agentId: 6,
      branch: 'Bhopal - MP Nagar',
      createdDate: todayStr,
    );
    await seedApp(
      custId: 1,
      prodId: 2,
      amount: 15000.0,
      tenure: 8,
      rate: 22.0,
      status: 'approved',
      agentId: 4,
      branch: 'Indore - Vijay Nagar',
      createdDate: todayStr,
    );

    // 11. Pre-GRT (Group Recognition Test)
    final pgId = await db.insert('pregrt', {
      'branch': 'Indore - Vijay Nagar',
      'center_no': 'C-101',
      'group_no': 'G-A',
      'village': 'Vijay Nagar',
      'district': 'Indore',
      'form_date': today.subtract(const Duration(days: 3)).toIso8601String().substring(0, 10),
      'pso_name': 'Ravi Field Officer',
      'pso_empid': 'E-1004',
      'bm_name': 'Meera Manager',
      'bm_empid': 'E-1002',
      'leader_knows_duties': 'yes',
      'notes': '5 group members passed the 3-day CGT training',
      'agent_id': 4,
      'status': 'submitted',
      'created_at': nowIso,
    });

    final members = [
      {'name': 'Sunita Verma', 'husband_name': 'Ramesh Verma', 'age': 38, 'voter_id': 'DMO1234501', 'customer_id': 1, 'loan_amount': 20000.0, 'purpose': 'Tailoring shop'},
      {'name': 'Kavita Sharma', 'husband_name': 'Anil Sharma', 'age': 36, 'voter_id': 'DMO1234502', 'customer_id': 3, 'loan_amount': 20000.0, 'purpose': 'Grocery stock'},
      {'name': 'Meena Chouhan', 'husband_name': 'Dinesh Chouhan', 'age': 41, 'voter_id': 'DMO1234503', 'customer_id': null, 'loan_amount': 20000.0, 'purpose': 'Vegetable vending'},
      {'name': 'Lata Parmar', 'husband_name': 'Rakesh Parmar', 'age': 33, 'voter_id': 'DMO1234504', 'customer_id': null, 'loan_amount': 20000.0, 'purpose': 'Dairy animal'},
      {'name': 'Geeta Solanki', 'husband_name': 'Mahesh Solanki', 'age': 39, 'voter_id': 'DMO1234505', 'customer_id': null, 'loan_amount': 20000.0, 'purpose': 'Bangle shop'},
    ];

    for (int idx = 0; idx < members.length; idx++) {
      final m = members[idx];
      await db.insert('pregrt_members', {
        'pregrt_id': pgId,
        'sno': idx + 1,
        'customer_id': m['customer_id'],
        'name': m['name'],
        'husband_name': m['husband_name'],
        'age': m['age'],
        'voter_id': m['voter_id'],
        'aadhaar4': '890$idx',
        'family_in_group': 'no',
        'house_type': 'pucca',
        'land_ha': 0.0,
        'livestock': '',
        'annual_income': 180000.0,
        'family_size': 4,
        'category': 'OBC',
        'loan_amount': m['loan_amount'],
        'purpose': m['purpose'],
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

    // 12. Field Tasks
    final tasks = [
      {'title': 'Collection - Vijay Nagar', 'customer_id': 1, 'ttype': 'collection', 'lat': 22.7533, 'lng': 75.8937, 'due_date': todayStr, 'officer_id': 4},
      {'title': 'Collection - Scheme 54', 'customer_id': 8, 'ttype': 'collection', 'lat': 22.7470, 'lng': 75.8920, 'due_date': todayStr, 'officer_id': 4},
      {'title': 'KYC visit - Palasia', 'customer_id': 2, 'ttype': 'verification', 'lat': 22.7244, 'lng': 75.8839, 'due_date': todayStr, 'officer_id': 5},
      {'title': 'Verification - Rajwada', 'customer_id': 4, 'ttype': 'verification', 'lat': 22.7185, 'lng': 75.8575, 'due_date': todayStr, 'officer_id': 4},
      {'title': 'Collection - Sarafa', 'customer_id': 7, 'ttype': 'collection', 'lat': 22.7176, 'lng': 75.8560, 'due_date': todayStr, 'officer_id': 4},
      {'title': 'Collection - Bhawarkuan', 'customer_id': 3, 'ttype': 'collection', 'lat': 22.6890, 'lng': 75.8680, 'due_date': todayStr, 'officer_id': 4},
    ];

    for (var t in tasks) {
      await db.insert('tasks', t);
    }

    // Done task
    await db.insert('tasks', {
      'title': 'Collection - Done Morning',
      'customer_id': 1,
      'ttype': 'collection',
      'lat': 22.75,
      'lng': 75.89,
      'due_date': todayStr,
      'officer_id': 4,
      'status': 'done',
      'collected': 5200.0,
      'notes': 'Received in cash at centre meeting',
      'done_at': nowIso,
    });

    // 13. Attendance & Requests
    await db.insert('attendance', {
      'user_id': 4,
      'day': todayStr,
      'in_time': '${todayStr}T09:30:00',
      'lat': 22.7510,
      'lng': 75.8900,
    });

    await db.insert('att_requests', {
      'user_id': 4,
      'branch': 'Indore - Vijay Nagar',
      'day': today.subtract(const Duration(days: 2)).toIso8601String().substring(0, 10),
      'in_time': '09:45',
      'out_time': '18:15',
      'reason': 'Forgot to punch, was conducting centre meeting in field',
      'status': 'pending',
      'approver_role': 'manager',
      'approver_id': 2,
      'requested_at': nowIso,
    });

    // 14. Settings
    final settings = [
      {'key': 'min_age', 'value': '18'},
      {'key': 'max_age', 'value': '55'},
      {'key': 'min_group', 'value': '2'},
      {'key': 'max_group', 'value': '5'},
      {'key': 'max_household_income', 'value': '300000'},
      {'key': 'max_emi_pct', 'value': '60'},
      {'key': 'gst_rate', 'value': '18'},
      {'key': 'punch_radius_m', 'value': '2000'},
    ];

    for (var s in settings) {
      await db.insert('settings', s);
    }

    // 15. Default Active Cloud Database Configuration (Ready to link)
    await db.insert('cloud_connections', {
      'provider_id': 'supabase',
      'endpoint_url': 'https://sarvocch-microcare-preview.supabase.co/rest/v1',
      'api_key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.demo-sarvocch-token',
      'project_ref': 'sarvocch-microcare-mp',
      'status': 'connected',
      'last_synced': nowIso,
    });

    // 16. Employee Leaves
    final leaves = [
      {
        'id': 1,
        'user_id': 4,
        'from_d': today.add(const Duration(days: 4)).toIso8601String().substring(0, 10),
        'to_d': today.add(const Duration(days: 6)).toIso8601String().substring(0, 10),
        'reason': 'Family religious function & village visit',
        'status': 'pending',
      },
      {
        'id': 2,
        'user_id': 5,
        'from_d': today.subtract(const Duration(days: 15)).toIso8601String().substring(0, 10),
        'to_d': today.subtract(const Duration(days: 13)).toIso8601String().substring(0, 10),
        'reason': 'Viral fever & medical checkup',
        'status': 'approved',
      },
      {
        'id': 3,
        'user_id': 6,
        'from_d': today.subtract(const Duration(days: 28)).toIso8601String().substring(0, 10),
        'to_d': today.subtract(const Duration(days: 27)).toIso8601String().substring(0, 10),
        'reason': 'Personal administrative work',
        'status': 'approved',
      },
    ];
    for (var l in leaves) {
      await db.insert('leaves', l);
    }

    // 17. Performance Evaluations
    final perf = [
      {
        'id': 1,
        'user_id': 4,
        'period': 'Q3 2026',
        'rating': 5,
        'notes': 'Exceeded collection targets in Vijay Nagar. Excellent borrower relationships.',
        'by_name': 'Meera Manager',
      },
      {
        'id': 2,
        'user_id': 5,
        'period': 'Q3 2026',
        'rating': 4,
        'notes': 'Met disbursement quota for Palasia. Good documentation discipline.',
        'by_name': 'Meera Manager',
      },
      {
        'id': 3,
        'user_id': 6,
        'period': 'Q3 2026',
        'rating': 4,
        'notes': 'Fast KYC turnaround time in Bhopal MP Nagar.',
        'by_name': 'Meera Manager',
      },
    ];
    for (var p in perf) {
      await db.insert('perf', p);
    }

    // 18. Official Public Holidays (for banking / schedule date calculation)
    final holidays = [
      {'day': '2026-01-26', 'name': 'Republic Day'},
      {'day': '2026-03-04', 'name': 'Holi'},
      {'day': '2026-04-14', 'name': 'Ambedkar Jayanti'},
      {'day': '2026-08-15', 'name': 'Independence Day'},
      {'day': '2026-10-02', 'name': 'Gandhi Jayanti'},
      {'day': '2026-11-01', 'name': 'Madhya Pradesh Foundation Day'},
      {'day': '2026-11-12', 'name': 'Diwali Deepawali'},
      {'day': '2026-12-25', 'name': 'Christmas'},
    ];
    for (var h in holidays) {
      await db.insert('holidays', h);
    }
  }
}
