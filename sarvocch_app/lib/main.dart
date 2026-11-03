import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cloud_quote_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/pregrt_provider.dart';

import 'screens/applications/applications_screen.dart';
import 'screens/applications/apply_loan_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/branches/branches_screen.dart';
import 'screens/calculator/emi_calculator_screen.dart';
import 'screens/cloud_quotations/cloud_quotation_screen.dart';
import 'screens/crm/crm_list_screen.dart';
import 'screens/crm/kyc_form_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/field/field_tasks_screen.dart';
import 'screens/hrm/hrm_screen.dart';
import 'screens/kyc_verify/kyc_verify_screen.dart';
import 'screens/loans/loans_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/portal/customer_portal_screen.dart';
import 'screens/pregrt/pregrt_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/settings/admin_settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/whatsapp/whatsapp_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI on desktop (macOS / Windows / Linux)
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const SarvoocchApp());
}

class SarvoocchApp extends StatelessWidget {
  const SarvoocchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LoanProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => PreGrtProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => CloudQuoteProvider()),
      ],
      child: MaterialApp(
        title: 'SARVOOCCH Microcare Foundation',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/dashboard': (_) => const DashboardScreen(),
          '/portal': (_) => const CustomerPortalScreen(),
          '/crm': (_) => const CrmListScreen(),
          '/kyc-form': (_) => const KycFormScreen(),
          '/pregrt': (_) => const PreGrtScreen(),
          '/apply': (_) => const ApplyLoanScreen(),
          '/applications': (_) => const ApplicationsScreen(),
          '/loans': (_) => const LoansListScreen(),
          '/kyc-verify': (_) => const KycVerifyScreen(),
          '/calculator': (_) => const EmiCalculatorScreen(),
          '/products': (_) => const ProductsScreen(),
          '/field': (_) => const FieldTasksScreen(),
          '/attendance': (_) => const AttendanceScreen(),
          '/branches': (_) => const BranchesScreen(),
          '/hrm': (_) => const HrmScreen(),
          '/whatsapp': (_) => const WhatsAppScreen(),
          '/cloud-quotes': (_) => const CloudQuotationScreen(),
          '/reports': (_) => const ReportsScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/settings': (_) => const AdminSettingsScreen(),
          // Route aliases
          '/kyc_form': (_) => const KycFormScreen(),
          '/apply_loan': (_) => const ApplyLoanScreen(),
        },
      ),
    );
  }
}
