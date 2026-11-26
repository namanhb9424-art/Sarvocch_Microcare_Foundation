import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/grievance_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/pregrt_provider.dart';
import 'services/sync_service.dart';

import 'screens/applications/applications_screen.dart';
import 'screens/applications/apply_loan_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/branches/branches_screen.dart';
import 'screens/calculator/emi_calculator_screen.dart';
import 'screens/crm/crm_list_screen.dart';
import 'screens/crm/kyc_form_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/field/field_tasks_screen.dart';
import 'screens/grievances/grievances_screen.dart';
import 'screens/hrm/hrm_screen.dart';
import 'screens/kyc_verify/kyc_verify_screen.dart';
import 'screens/loans/loans_list_screen.dart';
import 'screens/loans/payments_register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/portal/customer_portal_screen.dart';
import 'screens/pregrt/pregrt_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/settings/admin_settings_screen.dart';
import 'screens/settings/holidays_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/sync/sync_hub_screen.dart';
import 'screens/users/user_management_screen.dart';
import 'screens/whatsapp/whatsapp_screen.dart';
import 'theme/app_theme.dart';
import 'utils/route_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable();

  // Global Crash Shield: Intercept framework render exceptions
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[CRASH_SHIELD] Flutter Framework Error: ${details.exceptionAsString()}');
  };

  // Global Crash Shield: Intercept uncaught async zone exceptions
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[CRASH_SHIELD] Async Uncaught Error: $error');
    return true; // handled, prevent app termination
  };

  // Graceful Error Widget fallback instead of grey screen of death
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFF0F766E), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Temporary Display Issue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode
                    ? details.exceptionAsString()
                    : 'The view recovered safely. Please navigate back or retry.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Use the encrypted SQLite3MC build through FFI on native platforms.
  if (!kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const SarvoocchApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class SarvoocchApp extends StatelessWidget {
  const SarvoocchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final routeBuilders = <String, WidgetBuilder>{
      '/': (_) => const SplashScreen(),
      '/login': (_) => const LoginScreen(),
      '/setup': (_) => const LoginScreen(),
      '/dashboard': (_) => const DashboardScreen(),
      '/portal': (_) => const CustomerPortalScreen(),
      '/crm': (_) => const CrmListScreen(),
      '/kyc-form': (_) => const KycFormScreen(),
      '/pregrt': (_) => const PreGrtScreen(),
      '/apply': (_) => const ApplyLoanScreen(),
      '/applications': (_) => const ApplicationsScreen(),
      '/approvals': (_) => const ApplicationsScreen(
        initialStage: 'submitted',
        title: 'Approvals & Underwriting',
      ),
      '/disbursements': (_) => const ApplicationsScreen(
        initialStage: 'approved',
        title: 'Disbursements Queue',
      ),
      '/loans': (_) => const LoansListScreen(),
      '/payments': (_) => const PaymentsRegisterScreen(),
      '/kyc-verify': (_) => const KycVerifyScreen(),
      '/calculator': (_) => const EmiCalculatorScreen(),
      '/products': (_) => const ProductsScreen(),
      '/field': (_) => const FieldTasksScreen(),
      '/attendance': (_) => const AttendanceScreen(),
      '/branches': (_) => const BranchesScreen(),
      '/hrm': (_) => const HrmScreen(),
      '/grievances': (_) => const GrievancesScreen(),
      '/whatsapp': (_) => const WhatsAppScreen(),
      '/sync': (_) => const SyncHubScreen(),
      '/reports': (_) => const ReportsScreen(),
      '/holidays': (_) => const HolidaysScreen(),
      '/profile': (_) => const ProfileScreen(),
      '/settings': (_) => const AdminSettingsScreen(),
      '/users': (_) => const UserManagementScreen(),
      '/kyc_form': (_) => const KycFormScreen(),
      '/apply_loan': (_) => const ApplyLoanScreen(),
    };
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LoanProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => PreGrtProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => GrievanceProvider()),
        ChangeNotifierProvider.value(value: SyncService()),
      ],
      child: MaterialApp(
        navigatorKey: _rootNavigatorKey,
        title: 'Sarvoocch Saathi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        builder: (context, child) =>
            _SessionSecurityBoundary(child: child ?? const SizedBox.shrink()),
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';
          final pageBuilder = routeBuilders[name];
          if (pageBuilder == null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const _AccessDeniedScreen(),
            );
          }

          return MaterialPageRoute<void>(
            settings: settings,
            builder: (routeContext) {
              final auth = routeContext.read<AuthProvider>();
              final user = auth.currentUser;
              if (name == '/' || name == '/login') {
                return pageBuilder(routeContext);
              }
              if (name == '/setup') {
                return auth.needsInitialSetup
                    ? pageBuilder(routeContext)
                    : const LoginScreen();
              }
              if (user == null) return const LoginScreen();
              if (user.mustChangePassword && name != '/profile') {
                return const ProfileScreen();
              }
              if (!RouteGuard.hasAccess(name, user)) {
                return const _AccessDeniedScreen();
              }
              return pageBuilder(routeContext);
            },
          );
        },
      ),
    );
  }
}

class _SessionSecurityBoundary extends StatefulWidget {
  const _SessionSecurityBoundary({required this.child});

  final Widget child;

  @override
  State<_SessionSecurityBoundary> createState() =>
      _SessionSecurityBoundaryState();
}

class _SessionSecurityBoundaryState extends State<_SessionSecurityBoundary>
    with WidgetsBindingObserver {
  static const _idleTimeout = Duration(minutes: 5);

  AuthProvider? _auth;
  Timer? _idleTimer;
  DateTime? _lastInteraction;
  DateTime? _backgroundedAt;
  int? _observedUserId;
  bool _appObscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (identical(auth, _auth)) return;
    _auth?.removeListener(_handleAuthChanged);
    _auth = auth;
    auth.addListener(_handleAuthChanged);
    _handleAuthChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _auth?.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    final userId = _auth?.currentUser?.id;
    if (_observedUserId != null && userId != _observedUserId) {
      _clearSessionData();
    }
    if (userId == null) {
      _observedUserId = null;
      _lastInteraction = null;
      _idleTimer?.cancel();
      return;
    }
    if (userId != _observedUserId) {
      _observedUserId = userId;
      _lastInteraction = DateTime.now();
    }
    _scheduleIdleExpiry();
  }

  void _clearSessionData() {
    context.read<CustomerProvider>().clearSessionData();
    context.read<LoanProvider>().clearSessionData();
    context.read<PreGrtProvider>().clearSessionData();
    context.read<AttendanceProvider>().clearSessionData();
  }

  void _recordInteraction() {
    if (_auth?.currentUser == null) return;
    _lastInteraction = DateTime.now();
    _scheduleIdleExpiry();
  }

  void _scheduleIdleExpiry() {
    _idleTimer?.cancel();
    final lastInteraction = _lastInteraction;
    if (_auth?.currentUser == null || lastInteraction == null) return;
    final remaining = _idleTimeout - DateTime.now().difference(lastInteraction);
    _idleTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      _expireIfIdle,
    );
  }

  void _expireIfIdle() {
    final auth = _auth;
    final lastInteraction = _lastInteraction;
    if (!mounted || auth?.currentUser == null || lastInteraction == null) {
      return;
    }
    if (DateTime.now().difference(lastInteraction) < _idleTimeout) {
      _scheduleIdleExpiry();
      return;
    }
    auth!.logout();
    _rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();
      if (!_appObscured && mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _appObscured = true);
      }
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt != null &&
        DateTime.now().difference(backgroundedAt) >= _idleTimeout) {
      _expireIfIdle();
      if (mounted) setState(() => _appObscured = false);
    } else {
      if (_auth?.currentUser == null) {
        if (mounted) setState(() => _appObscured = false);
      } else {
        unawaited(_revalidateSessionOnResume());
      }
    }
  }

  Future<void> _revalidateSessionOnResume() async {
    final auth = _auth;
    if (auth?.currentUser == null) {
      if (mounted) setState(() => _appObscured = false);
      return;
    }
    final valid = await auth!.validateCurrentSession();
    if (!mounted) return;
    if (!valid) {
      _rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } else {
      _scheduleIdleExpiry();
    }
    setState(() => _appObscured = false);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _recordInteraction();
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordInteraction(),
      onPointerSignal: (_) => _recordInteraction(),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(
              absorbing: _appObscured,
              child: ExcludeSemantics(
                excluding: _appObscured,
                child: widget.child,
              ),
            ),
            if (_appObscured)
              Positioned.fill(
                child: ColoredBox(
                  color: Color(0xFF102A43),
                  child: Center(
                    child: Semantics(
                      label: 'App content protected while session is checked',
                      child: Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access unavailable')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 12),
              const Text('Your account does not have access to this page.'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
