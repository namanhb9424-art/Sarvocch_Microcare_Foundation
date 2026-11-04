import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sarvocch_app/data/database_helper.dart';
import 'package:sarvocch_app/providers/customer_provider.dart';
import 'package:sarvocch_app/providers/loan_provider.dart';
import 'package:sarvocch_app/services/pdf_service.dart';
import 'package:sarvocch_app/services/sync_service.dart';
import 'package:sarvocch_app/utils/route_guard.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SARVOOCCH Microcare Parity & Architecture Verification Tests', () {
    testWidgets('Verify KYC Dossier & Family Members Persistence', (tester) async {
      await tester.runAsync(() async {
        final db = await DatabaseHelper.instance.database;
        await DatabaseHelper.instance.resetDatabase();

        final custProv = CustomerProvider();
        await custProv.fetchCustomers();
        expect(custProv.customers.isNotEmpty, isTrue);

        final testCustId = custProv.customers.first.id;
        final familyData = [
          {'name': 'Sunita Verma', 'age': 34, 'edu': 'Primary', 'rel': 'Self', 'occ': 'Tailor'},
          {'name': 'Ramesh Verma', 'age': 38, 'edu': 'Secondary', 'rel': 'Husband', 'occ': 'Carpenter'},
          {'name': 'Amit Verma', 'age': 12, 'edu': 'School', 'rel': 'Son', 'occ': 'Student'},
        ];

        final saved = await custProv.saveKycForm(
          customerId: testCustId,
          agentId: 4,
          centerNo: 'C-202',
          groupNo: 'G-B',
          guardianType: 'husband',
          guardianName: 'Ramesh Verma',
          education: 'Primary (Class 5)',
          religion: 'Hindu',
          category: 'OBC',
          houseNo: '45-B',
          village: 'Shanti Nagar',
          postOffice: 'Shanti Nagar PO',
          district: 'Gorakhpur',
          state: 'Uttar Pradesh',
          pincode: '273001',
          houseType: 'Pucca',
          landHa: 0.75,
          livestock: '2 cows',
          bankName: 'Bank of Baroda',
          bankAcct: '123456789012',
          passbookName: 'Sunita Verma',
          povertyLine: 'BPL',
          annualIncome: 240000.0,
          distCenterM: 150.0,
          distBranchKm: 3.5,
          relativeInCenter: 'no',
          otherLoans: 1,
          currentDebt: 15000.0,
          repayFreq: 'monthly',
          coName: 'Ramesh Verma',
          coPhone: '9876543211',
          coRelation: 'Husband',
          coIncome: 14000.0,
          husbandName: 'Ramesh Verma',
          husbandFather: 'Suresh Verma',
          husbandDob: '1986-04-12',
          consentGiven: 1,
          declaration: 1,
          bureauConsent: 1,
          addressVerified: 1,
          verifiedBy: 'Ravi Field Officer',
          family: familyData,
        );

        expect(saved, isTrue);

        // Verify database row
        final kycRows = await db.query('kyc_forms', where: 'customer_id = ?', whereArgs: [testCustId]);
        expect(kycRows.isNotEmpty, isTrue);
        final kyc = kycRows.first;

        expect(kyc['center_no'], 'C-202');
        expect(kyc['dist_center_m'], 150.0);
        expect(kyc['co_name'], 'Ramesh Verma');
        expect(kyc['co_relation'], 'Husband');
        expect(kyc['co_income'], 14000.0);

        final rawFam = jsonDecode(kyc['family'] as String) as List;
        expect(rawFam.length, 3);
        expect(rawFam[0]['name'], 'Sunita Verma');
        expect(rawFam[1]['rel'], 'Husband');
        expect(rawFam[2]['name'], 'Amit Verma');
      });
    });

    testWidgets('Verify Loan Application Cashflow & Documents Appraisal', (tester) async {
      await tester.runAsync(() async {
        final db = await DatabaseHelper.instance.database;
        final loanProv = LoanProvider();
        await loanProv.fetchAll();

        final custProv = CustomerProvider();
        await custProv.fetchCustomers();
        final custId = custProv.customers.first.id;

        final appId = await loanProv.submitNewLoanApplication(
          customerId: custId,
          productId: 1,
          amount: 50000.0,
          tenure: 12,
          purpose: 'Dairy livestock purchase and fodder stock',
          income: 30000.0,
          occupation: 'Dairy Farming',
          agentId: 4,
          branch: 'Gorakhpur - Main',
          employer: 'Self-employed Farm',
          coName: 'Ramesh Verma',
          coPhone: '9876543211',
          coRelation: 'Husband',
          coIncome: 14000.0,
          incAgri: 18000.0,
          incBusiness: 12000.0,
          incJob: 0.0,
          incOther: 14000.0,
          expBasic: 12000.0,
          expEducation: 3000.0,
          expFestival: 2000.0,
          expHealth: 1500.0,
          expEmi: 2000.0,
          expOther: 1500.0,
          docsDeposited: ['aadhaar', 'voter', 'passbook'],
          docsOther: 'Ration card copy attached',
          insuranceWanted: 'yes',
          insuranceFor: 'both',
          groupRec: 50000.0,
          centerRec: 50000.0,
          loanCycle: 2,
          declaration: 1,
        );

        expect(appId, isNotNull);

        // Verify applications table
        final appRows = await db.query('applications', where: 'id = ?', whereArgs: [appId]);
        expect(appRows.isNotEmpty, isTrue);
        expect(appRows.first['amount'], 50000.0);
        expect(appRows.first['employer'], 'Self-employed Farm');
        expect(appRows.first['co_name'], 'Ramesh Verma');

        // Verify app_extra table
        final extraRows = await db.query('app_extra', where: 'application_id = ?', whereArgs: [appId]);
        expect(extraRows.isNotEmpty, isTrue);
        final extra = extraRows.first;
        expect(extra['loan_cycle'], 2);
        expect(extra['insurance_wanted'], 'yes');
        expect(extra['insurance_for'], 'both');
        expect(extra['docs_other'], 'Ration card copy attached');
        expect((extra['income_total'] as num).toDouble(), 44000.0); // 18k + 12k + 14k
        expect((extra['expense_total'] as num).toDouble(), 22000.0); // 12+3+2+1.5+2+1.5
        expect((extra['net_saving'] as num).toDouble(), 22000.0);
      });
    });

    test('Verify Authentic PDF Generation Service', () async {
      // 1. Sanction Letter PDF
      final sanctionBytes = await PdfService.generateSanctionLetter(
        loanId: '101',
        customerName: 'Sunita Verma',
        customerId: 'CUST-001',
        phone: '9876543210',
        branch: 'Gorakhpur - Main',
        amount: 40000.0,
        rate: 18.0,
        tenure: 12,
        emi: 3667.0,
        purpose: 'Garments and retail inventory',
        sanctionDate: '2026-11-03',
        coBorrower: 'Ramesh Verma (Husband)',
      );
      expect(sanctionBytes.isNotEmpty, isTrue);
      expect(sanctionBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF header

      // 2. Passbook Card PDF
      final passbookBytes = await PdfService.generatePassbookCard(data: {
        'id': '101',
        'customer_name': 'Sunita Verma',
        'center_no': 'C-101',
        'group_no': 'G-A',
        'branch': 'Gorakhpur',
        'principal': 40000,
        'rate': 18,
        'tenure': 12,
        'emi': 3667,
      });
      expect(passbookBytes.isNotEmpty, isTrue);
      expect(passbookBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);

      // 3. NOC Certificate PDF
      final nocBytes = await PdfService.generateNocCertificate(
        loanId: '101',
        customerName: 'Sunita Verma',
        customerId: 'CUST-001',
        branch: 'Gorakhpur - Main',
        closureDate: '2026-11-03',
      );
      expect(nocBytes.isNotEmpty, isTrue);
      expect(nocBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);

      // 4. Pre-GRT Certificate PDF
      final preGrtBytes = await PdfService.generatePreGrtCertificate(data: {
        'center_no': 'C-101',
        'group_no': 'G-A',
        'village': 'Vijay Nagar',
        'district': 'Gorakhpur',
        'branch': 'Gorakhpur',
        'pso_name': 'Ravi Field Officer',
        'pso_empid': 'EMP-004',
        'verified_by': 'Meera Manager',
        'verified_on': '2026-11-03',
      });
      expect(preGrtBytes.isNotEmpty, isTrue);
      expect(preGrtBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });

    test('Verify RouteGuard Access Authorization Matrix', () {
      // Super Admin has universal access
      expect(RouteGuard.hasAccess('/dashboard', 'admin'), isTrue);
      expect(RouteGuard.hasAccess('/reports', 'admin'), isTrue);
      expect(RouteGuard.hasAccess('/kyc_form', 'admin'), isTrue);
      expect(RouteGuard.hasAccess('/customer_portal', 'admin'), isTrue);

      // Customer role is gated to portal and profile only
      expect(RouteGuard.hasAccess('/customer_portal', 'customer'), isTrue);
      expect(RouteGuard.hasAccess('/profile', 'customer'), isTrue);
      expect(RouteGuard.hasAccess('/dashboard', 'customer'), isFalse);
      expect(RouteGuard.hasAccess('/reports', 'customer'), isFalse);
      expect(RouteGuard.hasAccess('/kyc_form', 'customer'), isFalse);

      // Field Agent has field, CRM, KYC, attendance access but not executive reports
      expect(RouteGuard.hasAccess('/field_tasks', 'field_agent'), isTrue);
      expect(RouteGuard.hasAccess('/kyc_form', 'field_agent'), isTrue);
      expect(RouteGuard.hasAccess('/apply_loan', 'field_agent'), isTrue);
      expect(RouteGuard.hasAccess('/attendance', 'field_agent'), isTrue);
      expect(RouteGuard.hasAccess('/reports', 'field_agent'), isFalse);

      // Branch Manager has reports and operational access
      expect(RouteGuard.hasAccess('/reports', 'branch_manager'), isTrue);
      expect(RouteGuard.hasAccess('/dashboard', 'branch_manager'), isTrue);
    });

    testWidgets('Verify SyncService Offline Action Enqueuing & Count', (tester) async {
      await tester.runAsync(() async {
        final syncService = SyncService();
        await syncService.enqueueAction(
          userId: 4,
          action: 'repayment_collection',
          payload: {'loan_id': 1, 'amount': 3667.0, 'mode': 'cash'},
        );

        final pending = await syncService.updatePendingCount();
        expect(pending, greaterThanOrEqualTo(1));
        expect(syncService.pendingCount, greaterThanOrEqualTo(1));
      });
    });
  });
}

