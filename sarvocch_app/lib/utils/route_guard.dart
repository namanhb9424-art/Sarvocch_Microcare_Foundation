import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../theme/app_theme.dart';

class RouteGuard {
  static const Map<String, String> _routePermissions = {
    '/dashboard': 'dashboard',
    '/portal': 'portal',
    '/crm': 'crm',
    '/kyc-form': 'kycform',
    '/kyc_form': 'kycform',
    '/kyc-verify': 'kyc',
    '/pregrt': 'pregrt',
    '/apply': 'apply',
    '/apply_loan': 'apply',
    '/applications': 'applications',
    '/approvals': 'approve',
    '/disbursements': 'disburse',
    '/loans': 'loans',
    '/payments': 'payments',
    '/calculator': 'calculator',
    '/products': 'products',
    '/field': 'field',
    '/attendance': 'attendance',
    '/branches': 'branches',
    '/hrm': 'hrm',
    '/grievances': 'grievances',
    '/whatsapp': 'whatsapp',
    '/sync': 'sync',
    '/reports': 'reports',
    '/profile': 'profile',
    '/holidays': 'holidays',
    '/settings': 'settings',
    '/users': 'users',
  };

  /// Routes must have an explicit module permission; unknown routes fail closed.
  /// Data providers still enforce record and branch scope for each operation.
  static bool hasAccess(String routeName, UserModel? currentUser) {
    if (currentUser == null) return false;
    final permission = _routePermissions[routeName];
    return permission != null && currentUser.can(permission);
  }

  /// Secure navigation wrapper that redirects or shows warning if unauthorized
  static void navigateGuarded(
    BuildContext context,
    String routeName,
    UserModel? currentUser, {
    Object? arguments,
  }) {
    if (currentUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (hasAccess(routeName, currentUser)) {
      Navigator.pushNamed(context, routeName, arguments: arguments);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Access Denied: Your role (${currentUser.role}) does not have permission for $routeName.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }
}
