import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class CustomDrawer extends StatelessWidget {
  final String currentRoute;

  const CustomDrawer({super.key, required this.currentRoute});

  String _normalizeRoute(String route) {
    switch (route) {
      case '/kyc_form':
        return '/kyc-form';
      case '/apply_loan':
        return '/apply';
      case '/kyc':
        return '/kyc-verify';
      default:
        return route;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final modalRouteName = ModalRoute.of(context)?.settings.name;
    final effectiveRoute = _normalizeRoute(
      (modalRouteName != null && modalRouteName.isNotEmpty)
          ? modalRouteName
          : currentRoute,
    );

    if (user == null) return const SizedBox.shrink();

    // Matching NAV list from Flask app.py
    final allNavItems = [
      if (user.can('dashboard'))
        _NavItem(
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          route: '/dashboard',
        ),
      if (user.can('portal'))
        _NavItem(
          id: 'portal',
          label: 'My Loans (Portal)',
          icon: Icons.account_balance_wallet_outlined,
          route: '/portal',
        ),
      if (user.can('crm'))
        _NavItem(
          id: 'crm',
          label: 'CRM / Customers',
          icon: Icons.people_outline,
          route: '/crm',
        ),
      if (user.can('kycform'))
        _NavItem(
          id: 'kycform',
          label: 'New Customer (KYC)',
          icon: Icons.badge_outlined,
          route: '/kyc-form',
        ),
      if (user.can('pregrt'))
        _NavItem(
          id: 'pregrt',
          label: 'Pre-GRT (Group Form)',
          icon: Icons.groups_outlined,
          route: '/pregrt',
        ),
      if (user.can('apply'))
        _NavItem(
          id: 'apply',
          label: 'New Loan Application',
          icon: Icons.note_add_outlined,
          route: '/apply',
        ),
      if (user.can('applications'))
        _NavItem(
          id: 'applications',
          label: 'Applications',
          icon: Icons.folder_open_outlined,
          route: '/applications',
        ),
      if (user.can('approve'))
        _NavItem(
          id: 'approve',
          label: 'Approvals Queue',
          icon: Icons.check_circle_outline,
          route: '/approvals',
        ),
      if (user.can('disburse'))
        _NavItem(
          id: 'disburse',
          label: 'Disbursements Queue',
          icon: Icons.account_balance_outlined,
          route: '/disbursements',
        ),
      if (user.can('loans'))
        _NavItem(
          id: 'loans',
          label: 'Loan Accounts',
          icon: Icons.savings_outlined,
          route: '/loans',
        ),
      if (user.can('payments'))
        _NavItem(
          id: 'payments',
          label: user.role == 'customer' ? 'Pay EMI' : 'Collect Repayment',
          icon: Icons.payments_outlined,
          route: '/payments',
        ),
      if (user.can('kyc'))
        _NavItem(
          id: 'kyc',
          label: 'KYC Document Verify',
          icon: Icons.verified_user_outlined,
          route: '/kyc-verify',
        ),
      if (user.can('calculator'))
        _NavItem(
          id: 'calculator',
          label: 'EMI Calculator',
          icon: Icons.calculate_outlined,
          route: '/calculator',
        ),
      if (user.can('products'))
        _NavItem(
          id: 'products',
          label: 'Loan Products',
          icon: Icons.inventory_2_outlined,
          route: '/products',
        ),
      if (user.can('field'))
        _NavItem(
          id: 'field',
          label: 'Field Operations & Sync',
          icon: Icons.explore_outlined,
          route: '/field',
        ),
      if (user.can('attendance'))
        _NavItem(
          id: 'attendance',
          label: 'Attendance & Geofence',
          icon: Icons.access_time_outlined,
          route: '/attendance',
        ),
      if (user.can('whatsapp'))
        _NavItem(
          id: 'whatsapp',
          label: 'WhatsApp Hub & OTP',
          icon: Icons.chat_outlined,
          route: '/whatsapp',
        ),
      if (user.can('hrm') || user.can('employees'))
        _NavItem(
          id: 'hrm',
          label: 'HRM & Staff Management',
          icon: Icons.badge_outlined,
          route: '/hrm',
        ),
      if (user.can('branches') || user.role == 'admin')
        _NavItem(
          id: 'branches',
          label: 'Branch Offices & Portfolio',
          icon: Icons.business_outlined,
          route: '/branches',
        ),
      if (user.can('reports'))
        _NavItem(
          id: 'reports',
          label: 'Portfolio Reports & PAR',
          icon: Icons.analytics_outlined,
          route: '/reports',
        ),
      if (user.can('grievances'))
        _NavItem(
          id: 'grievances',
          label: 'Grievance Redressal',
          icon: Icons.support_agent_outlined,
          route: '/grievances',
        ),
      if (user.can('sync'))
        _NavItem(
          id: 'sync',
          label: 'Cloud Sync & Logs',
          icon: Icons.cloud_sync_outlined,
          route: '/sync',
        ),
      if (user.role == 'admin')
        _NavItem(
          id: 'holidays',
          label: 'Holiday Calendar',
          icon: Icons.calendar_month_outlined,
          route: '/holidays',
        ),
      _NavItem(
        id: 'profile',
        label: 'My Profile & Security',
        icon: Icons.account_circle_outlined,
        route: '/profile',
      ),
      if (user.role == 'admin')
        _NavItem(
          id: 'settings',
          label: 'Admin Settings & Policies',
          icon: Icons.settings_outlined,
          route: '/settings',
        ),
      if (user.role == 'admin')
        _NavItem(
          id: 'users',
          label: 'User Accounts & Access',
          icon: Icons.manage_accounts_outlined,
          route: '/users',
        ),
    ];

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(color: AppTheme.tealPrimary),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0] : 'S',
                      style: const TextStyle(
                        color: AppTheme.tealPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${user.roleDisplay} • ${user.branch}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: allNavItems.length,
                itemBuilder: (context, index) {
                  final item = allNavItems[index];
                  final isActive = effectiveRoute == item.route;
                  final homeRoute =
                      user.role == 'customer' ? '/portal' : '/dashboard';

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.tealSurface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isActive
                          ? const Border(
                              left: BorderSide(
                                color: AppTheme.tealPrimary,
                                width: 4,
                              ),
                            )
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      selected: isActive,
                      selectedTileColor: AppTheme.tealSurface,
                      leading: Icon(
                        item.icon,
                        size: 20,
                        color: isActive
                            ? AppTheme.tealPrimary
                            : AppTheme.textSecondary,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? AppTheme.tealDark
                              : AppTheme.textPrimary,
                        ),
                      ),
                      trailing: isActive
                          ? const Icon(
                              Icons.circle,
                              size: 8,
                              color: AppTheme.tealPrimary,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        if (!isActive) {
                          // Home screens clear the stack cleanly; top-level drawer
                          // modules keep only the home route underneath so Back
                          // always returns directly to Dashboard/Portal (BS-011).
                          if (item.route == '/dashboard' ||
                              item.route == '/portal') {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              item.route,
                              (_) => false,
                            );
                          } else {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              item.route,
                              (route) => route.settings.name == homeRoute,
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            const Divider(color: AppTheme.border, height: 1),

            // Logout Tile
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.logout,
                size: 20,
                color: AppTheme.danger,
              ),
              title: const Text(
                'Logout / Change Account',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              onTap: () {
                auth.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String id;
  final String label;
  final IconData icon;
  final String route;

  _NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });
}
