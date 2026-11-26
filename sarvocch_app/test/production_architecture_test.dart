import 'package:flutter_test/flutter_test.dart';
import 'package:sarvocch_app/data/database_helper.dart';
import 'package:sarvocch_app/models/user_model.dart';
import 'package:sarvocch_app/providers/auth_provider.dart';
import 'package:sarvocch_app/providers/customer_provider.dart';
import 'package:sarvocch_app/services/currency_amount.dart';
import 'package:sarvocch_app/services/password_hash_service.dart';
import 'package:sarvocch_app/utils/route_guard.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('SARVOOCCH Production Architecture & Security Tests', () {
    test('CurrencyAmount accurately handles integer paise conversions', () {
      final minorUnits = CurrencyAmount.toMinorUnits(1500.50);
      expect(minorUnits, 150050);

      final rupees = CurrencyAmount.fromMinorUnits(minorUnits);
      expect(rupees, 1500.50);

      expect(CurrencyAmount.hasPaisePrecision(100.25), isTrue);
      expect(CurrencyAmount.hasPaisePrecision(100.255), isFalse);

      final normalized = CurrencyAmount.normalize(100.256);
      expect(normalized, 100.26);
    });

    test('PasswordHashService hashes and verifies passwords securely', () async {
      final password = 'AdminSecurePass2026!';
      final encodedHash = await PasswordHashService.hash(password);

      expect(encodedHash.isNotEmpty, isTrue);
      expect(encodedHash.startsWith('pbkdf2-sha256-v1\$'), isTrue);

      final isValid = await PasswordHashService.verify(password, encodedHash);
      expect(isValid, isTrue);

      final isInvalid = await PasswordHashService.verify('WrongPassword', encodedHash);
      expect(isInvalid, isFalse);
    });

    test('RouteGuard strictly validates role-based permissions', () {
      final adminUser = UserModel(
        id: 1,
        username: 'admin',
        name: 'Aarav Admin',
        role: 'admin',
        branch: 'Bhopal Head Office',
        phone: '9826011111',
      );

      final customerUser = UserModel(
        id: 5,
        username: 'cust1',
        name: 'Sunita Verma',
        role: 'customer',
        branch: 'Indore - Vijay Nagar',
        phone: '9826055555',
      );

      // Admin has access to settings, users, branches, etc.
      expect(RouteGuard.hasAccess('/settings', adminUser), isTrue);
      expect(RouteGuard.hasAccess('/users', adminUser), isTrue);
      expect(RouteGuard.hasAccess('/dashboard', adminUser), isTrue);
      expect(RouteGuard.hasAccess('/holidays', adminUser), isTrue);
      expect(RouteGuard.hasAccess('/grievances', adminUser), isTrue);
      expect(RouteGuard.hasAccess('/payments', adminUser), isTrue);
      expect(RouteGuard.hasAccess('/approvals', adminUser), isTrue);
      expect(RouteGuard.hasAccess('/disbursements', adminUser), isTrue);
      expect(RouteGuard.hasAccess('/sync', adminUser), isTrue);

      // Customer only has access to customer portal, calculator, grievances, payments
      expect(RouteGuard.hasAccess('/portal', customerUser), isTrue);
      expect(RouteGuard.hasAccess('/calculator', customerUser), isTrue);
      expect(RouteGuard.hasAccess('/grievances', customerUser), isTrue);
      expect(RouteGuard.hasAccess('/settings', customerUser), isFalse);
      expect(RouteGuard.hasAccess('/users', customerUser), isFalse);
      expect(RouteGuard.hasAccess('/hrm', customerUser), isFalse);
      expect(RouteGuard.hasAccess('/approvals', customerUser), isFalse);

      // Null user has no access to protected routes
      expect(RouteGuard.hasAccess('/dashboard', null), isFalse);

      // Field officer should reach dashboard, kyc-verify, products, attendance
      final agentUser = UserModel(
        id: 4,
        username: 'agent1',
        name: 'Ravi Field Officer',
        role: 'field_agent',
        branch: 'Indore - Vijay Nagar',
        phone: '9800000004',
      );
      expect(RouteGuard.hasAccess('/dashboard', agentUser), isTrue);
      expect(RouteGuard.hasAccess('/kyc-verify', agentUser), isTrue);
      expect(RouteGuard.hasAccess('/products', agentUser), isTrue);
      expect(RouteGuard.hasAccess('/attendance', agentUser), isTrue);
      expect(RouteGuard.hasAccess('/whatsapp', agentUser), isTrue);
      expect(RouteGuard.hasAccess('/settings', agentUser), isFalse);
      expect(RouteGuard.hasAccess('/users', agentUser), isFalse);
    });

    test('Seeded operational DB prevents unauthorized admin signup and supports geofences & CRM', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await DatabaseHelper.instance.resetDatabase();
      final db = await DatabaseHelper.instance.database;

      final auth = AuthProvider();
      await auth.init();
      expect(auth.needsInitialSetup, isFalse);

      final branches = await db.query('branches', where: 'active = 1 AND lat IS NOT NULL AND lng IS NOT NULL AND radius_m > 0');
      expect(branches.length, greaterThanOrEqualTo(8));

      final products = await db.query('products', where: 'active = 1');
      expect(products.length, greaterThanOrEqualTo(4));

      final custProv = CustomerProvider();
      final createdId = await custProv.createCustomer(
        name: 'Kiran Patel',
        phone: '+91 98260-77889',
        address: 'Vijay Nagar, Indore',
        branch: 'Indore - Vijay Nagar',
        actorUserId: 1,
      );
      expect(createdId, isNotNull);
    });
  });
}
