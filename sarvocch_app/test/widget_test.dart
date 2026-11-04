import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sarvocch_app/data/database_helper.dart';
import 'package:sarvocch_app/providers/auth_provider.dart';
import 'package:sarvocch_app/providers/loan_provider.dart';
import 'package:sarvocch_app/providers/customer_provider.dart';
import 'package:sarvocch_app/providers/pregrt_provider.dart';
import 'package:sarvocch_app/providers/attendance_provider.dart';
import 'package:sarvocch_app/providers/cloud_quote_provider.dart';
import 'package:sarvocch_app/screens/login_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('LoginScreen Smoke & Demo Accounts Test', (WidgetTester tester) async {
    final authProvider = AuthProvider();

    await tester.runAsync(() async {
      await DatabaseHelper.instance.resetDatabase();
      await authProvider.init();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => LoanProvider()),
          ChangeNotifierProvider(create: (_) => CustomerProvider()),
          ChangeNotifierProvider(create: (_) => PreGrtProvider()),
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
          ChangeNotifierProvider(create: (_) => CloudQuoteProvider()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Sign In to Portal'), findsOneWidget);
    expect(find.text('Instant 1-Click Demo Accounts'), findsOneWidget);
    expect(find.text('Admin (Aarav)'), findsOneWidget);
    expect(find.text('Manager (Meera)'), findsOneWidget);
  });
}
