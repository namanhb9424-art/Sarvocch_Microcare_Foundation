import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

class RouteGuard {
  static final Map<String, List<String>> _routePermissions = {
    '/dashboard': ['admin', 'branch_manager', 'credit_officer', 'field_agent'],
    '/customer_portal': ['customer', 'admin'],
    '/kyc_form': ['admin', 'branch_manager', 'field_agent'],
    '/kyc_verify': ['admin', 'branch_manager', 'credit_officer', 'field_agent'],
    '/apply_loan': ['admin', 'branch_manager', 'field_agent'],
    '/group_apply': ['admin', 'branch_manager', 'field_agent'],
    '/attendance': ['admin', 'branch_manager', 'credit_officer', 'field_agent'],
    '/field_tasks': ['admin', 'branch_manager', 'field_agent'],
    '/pregrt': ['admin', 'branch_manager', 'credit_officer', 'field_agent'],
    '/loans': ['admin', 'branch_manager', 'credit_officer', 'field_agent'],
    '/crm': ['admin', 'branch_manager', 'credit_officer', 'field_agent'],
    '/reports': ['admin', 'branch_manager'],
    '/profile': ['admin', 'branch_manager', 'credit_officer', 'field_agent', 'customer'],
  };

  /// Check if role has access to the given route
  static bool hasAccess(String routeName, String? role) {
    if (role == null) return false;
    if (role == 'admin') return true; // Super admin has universal access

    final allowed = _routePermissions[routeName];
    if (allowed == null) return true; // Unrestricted route
    return allowed.contains(role);
  }

  /// Secure navigation wrapper that redirects or shows warning if unauthorized
  static void navigateGuarded(BuildContext context, String routeName, UserModel? currentUser, {Object? arguments}) {
    if (currentUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (hasAccess(routeName, currentUser.role)) {
      Navigator.pushNamed(context, routeName, arguments: arguments);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access Denied: Your role (${currentUser.role}) does not have permission for $routeName.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }
}

