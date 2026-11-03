import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sarvocch_app/data/database_helper.dart';
import 'package:sarvocch_app/providers/auth_provider.dart';
import 'package:sarvocch_app/providers/loan_provider.dart';
import 'package:sarvocch_app/providers/customer_provider.dart';
import 'package:sarvocch_app/providers/pregrt_provider.dart';
import 'package:sarvocch_app/providers/attendance_provider.dart';
import 'package:sarvocch_app/providers/cloud_quote_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SARVOOCCH Microcare Foundation — Comprehensive User Flow & Role Tests', () {
    late AuthProvider auth;
    late LoanProvider loan;
    late CustomerProvider customer;
    late PreGrtProvider pregrt;
    late AttendanceProvider attendance;
    late CloudQuoteProvider cloud;

    setUp(() async {
      await DatabaseHelper.instance.resetDatabase();

      auth = AuthProvider();
      loan = LoanProvider();
      customer = CustomerProvider();
      pregrt = PreGrtProvider();
      attendance = AttendanceProvider();
      cloud = CloudQuoteProvider();

      await auth.init();
      await loan.fetchAll();
      await customer.fetchCustomers();
      await pregrt.fetchPreGrts();
      cloud.init();
    });

    test('Flow 1: Admin User (Aarav Admin) — Full Control & Policies', () async {
      // 1. Login as Admin
      final loginSuccess = await auth.login('admin', 'admin123');
      expect(loginSuccess, isTrue);
      expect(auth.currentUser?.role, 'admin');
      expect(auth.currentUser?.can('settings'), isTrue);
      expect(auth.currentUser?.can('dashboard'), isTrue);

      // 2. Check Portfolio KPIs
      expect(loan.totalDisbursed, greaterThan(0));
      expect(loan.activeLoansCount, greaterThan(0));
      expect(loan.products.length, 3);

      // 3. Admin updates lending policy settings
      final db = await DatabaseHelper.instance.database;
      await db.insert('settings', {'key': 'max_emi_pct', 'value': '55'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      final val = await db.query('settings', where: 'key = ?', whereArgs: ['max_emi_pct']);
      expect(val.first['value'], '55');
    });

    test('Flow 2: Branch Manager (Meera Manager) — Pre-GRT & Sanctions', () async {
      // 1. Login as Branch Manager
      final loginSuccess = await auth.login('manager1', 'manager123');
      expect(loginSuccess, isTrue);
      expect(auth.currentUser?.role, 'manager');
      expect(auth.currentUser?.can('pregrt'), isTrue);
      expect(auth.currentUser?.can('applications'), isTrue);

      // 2. Review Pre-GRT group
      expect(pregrt.preGrts.isNotEmpty, isTrue);
      final submittedGroup = pregrt.preGrts.firstWhere((g) => g.status == 'submitted');
      expect(submittedGroup.members.length, 5);

      final reviewSuccess = await pregrt.reviewPreGrt(
        pregrtId: submittedGroup.id,
        status: 'verified',
        reviewRemarks: 'All 5 members passed the 3-day CGT training',
        verifiedBy: auth.currentUser!.name,
      );
      expect(reviewSuccess, isTrue);
      expect(pregrt.preGrts.firstWhere((g) => g.id == submittedGroup.id).status, 'verified');

      // 3. Sanction & Disburse loan application
      final app = loan.applications.firstWhere((a) => a.status == 'approved');
      final sanctionSuccess = await loan.advanceApplication(
        applicationId: app.id,
        targetStage: 'sanctioned',
        byUser: auth.currentUser!.name,
        byRole: auth.currentUser!.role,
        sanctionedAmount: app.amount,
        remarks: 'Digital Sanction letter generated',
      );
      expect(sanctionSuccess, isTrue);

      final disburseSuccess = await loan.advanceApplication(
        applicationId: app.id,
        targetStage: 'disbursed',
        byUser: auth.currentUser!.name,
        byRole: auth.currentUser!.role,
        sanctionedAmount: app.amount,
        remarks: 'Funds released via IMPS/NEFT',
      );
      expect(disburseSuccess, isTrue);
    });

    test('Flow 3: Credit Underwriter (Uday Underwriter) — Review & Risk Limit', () async {
      // 1. Login as Underwriter
      final loginSuccess = await auth.login('uw1', 'uw123');
      expect(loginSuccess, isTrue);
      expect(auth.currentUser?.role, 'underwriter');
      expect(auth.currentUser?.can('approve'), isTrue);

      // 2. Review application & adjust sanction amount as per repayment capacity
      final app = loan.applications.firstWhere((a) => a.status == 'under_review');
      final approveSuccess = await loan.advanceApplication(
        applicationId: app.id,
        targetStage: 'approved',
        byUser: auth.currentUser!.name,
        byRole: auth.currentUser!.role,
        sanctionedAmount: 8000.0, // Reduced from 10,000 for credit risk safety
        remarks: 'Reduced to ₹8,000 to maintain EMI < 60% household income',
      );
      expect(approveSuccess, isTrue);
    });

    test('Flow 4: Field Officer / PSO (Ravi) — Customer KYC, Punch, & Collection', () async {
      // 1. Login as Field Officer
      final loginSuccess = await auth.login('agent1', 'agent123');
      expect(loginSuccess, isTrue);
      expect(auth.currentUser?.role, 'field_agent');

      // 2. Add New Customer Lead
      final newCustId = await customer.createCustomer(
        name: 'Priyanka Sen',
        phone: '9899112233',
        dob: '1991-08-14',
        address: '15 Vijay Nagar, Indore',
        branch: 'Indore - Vijay Nagar',
        agentId: auth.currentUser!.id,
        stage: 'lead',
      );
      expect(newCustId, isNotNull);

      // 3. Fill and Save Bilingual KYC Form with Husband Information & Mandatory Consent
      final kycSuccess = await customer.saveKycForm(
        customerId: newCustId!,
        agentId: auth.currentUser!.id,
        centerNo: 'C-101',
        groupNo: 'G-A',
        guardianType: 'husband',
        guardianName: 'Amit Sen',
        education: 'Secondary (10th)',
        religion: 'Hindu',
        category: 'OBC',
        houseNo: '15',
        village: 'Vijay Nagar',
        postOffice: 'Vijay Nagar PO',
        district: 'Indore',
        state: 'Madhya Pradesh',
        pincode: '452010',
        houseType: 'pucca',
        landHa: 0.0,
        livestock: '1 cow',
        bankName: 'SBI',
        bankAcct: '30123456789',
        passbookName: 'Priyanka Sen',
        povertyLine: 'APL',
        annualIncome: 200000.0,
        husbandName: 'Amit Sen',
        husbandFather: 'Rajesh Sen',
        husbandDob: '1987-04-10',
        consentGiven: 1, // Consent obtained
        addressVerified: 1,
        verifiedBy: auth.currentUser!.name,
      );
      expect(kycSuccess, isTrue);

      // Verify customer moved to 'customer' stage
      final updatedCust = customer.customers.firstWhere((c) => c.id == newCustId);
      expect(updatedCust.stage, 'customer');
      expect(updatedCust.kycStatus, 'verified');

      // 4. Punch Attendance within 2000m Geofence
      await attendance.fetchAttendanceData(auth.currentUser!.id);
      final punchRes = await attendance.punchIn(
        userId: auth.currentUser!.id,
        branchName: 'Indore - Vijay Nagar',
        currentLat: 22.7533,
        currentLng: 75.8937,
      );
      expect(punchRes['success'], isTrue);
      expect(punchRes['within_radius'], isTrue);

      // 5. Submit New Loan Application
      final appId = await loan.submitNewLoanApplication(
        customerId: newCustId,
        productId: 1,
        amount: 30000,
        tenure: 12,
        purpose: 'Small grocery shop inventory',
        income: 25000,
        occupation: 'Kirana Shop',
        agentId: auth.currentUser!.id,
        branch: 'Indore - Vijay Nagar',
        incBusiness: 20000,
        expBasic: 8000,
        docsDeposited: ['aadhaar', 'voter'],
      );
      expect(appId, isNotNull);
    });

    test('Flow 5: Customer / Borrower (Sunita Verma) — Portal, UPI Pay, Settle', () async {
      // 1. Login as Customer
      final loginSuccess = await auth.login('cust1', 'cust123');
      expect(loginSuccess, isTrue);
      expect(auth.currentUser?.role, 'customer');

      // 2. Fetch Customer Loan
      final myLoans = loan.loans.where((l) => l.customerId == 1).toList();
      expect(myLoans.isNotEmpty, isTrue);
      final activeLoan = myLoans.firstWhere((l) => l.status == 'active');
      expect(activeLoan.emi, greaterThan(0));

      // 3. Schedule and Pay 1 Installment via UPI
      final schedule = await loan.getSchedule(activeLoan.id);
      final unpaid = schedule.firstWhere((s) => s.paid == 0);
      final paySuccess = await loan.payInstallment(
        loanId: activeLoan.id,
        scheduleId: unpaid.id,
        amount: unpaid.emi,
        channel: 'upi',
      );
      expect(paySuccess, isTrue);

      // 4. Settle Loan in Full (Principal + Next Interest)
      final quote = await loan.getSettlementQuote(activeLoan.id);
      expect(quote, isNotNull);
      expect(quote!['total_settlement'], greaterThan(0));

      final settleSuccess = await loan.settleLoanFull(activeLoan.id, 'upi');
      expect(settleSuccess, isTrue);

      final settledLoan = loan.loans.firstWhere((l) => l.id == activeLoan.id);
      expect(settledLoan.status, 'closed');
    });

    test('Flow 6: Cloud Database Quotations & Sync Engine Handshake', () async {
      expect(cloud.quotes.length, 6);

      // Connect to Supabase
      final connectRes = await cloud.testAndSaveConnection(
        providerId: 'supabase',
        endpointUrl: 'https://sarvocch-microcare.supabase.co/rest/v1',
        apiKey: 'demo-supabase-jwt-key',
        projectRef: 'sarvocch-mp',
      );
      expect(connectRes['success'], isTrue);
      expect(cloud.activeConnection?['provider_id'], 'supabase');

      // Trigger delta sync
      await cloud.triggerCloudSync();
      expect(cloud.syncProgress, 1.0);
      expect(cloud.syncStatusMessage, contains('synced successfully'));
    });
  });
}
