import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class CustomDrawer extends StatelessWidget {
  final String currentRoute;

  const CustomDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) return const SizedBox.shrink();

    // Matching NAV list from Flask app.py
    final allNavItems = [
      if (user.can('dashboard'))
        _NavItem(id: 'dashboard', label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
      if (user.can('portal'))
        _NavItem(id: 'portal', label: 'My Loans (Portal)', icon: Icons.account_balance_wallet_outlined, route: '/portal'),
      if (user.can('crm'))
        _NavItem(id: 'crm', label: 'CRM / Customers', icon: Icons.people_outline, route: '/crm'),
      if (user.can('kycform'))
        _NavItem(id: 'kycform', label: 'New Customer (KYC)', icon: Icons.badge_outlined, route: '/kyc-form'),
      if (user.can('pregrt'))
        _NavItem(id: 'pregrt', label: 'Pre-GRT (Group Form)', icon: Icons.groups_outlined, route: '/pregrt'),
      if (user.can('apply'))
        _NavItem(id: 'apply', label: 'New Loan Application', icon: Icons.note_add_outlined, route: '/apply'),
      if (user.can('applications'))
        _NavItem(id: 'applications', label: 'Applications', icon: Icons.folder_open_outlined, route: '/applications'),
      if (user.can('loans'))
        _NavItem(id: 'loans', label: 'Loans & EMI Repayments', icon: Icons.payments_outlined, route: '/loans'),
      if (user.can('kyc'))
        _NavItem(id: 'kyc', label: 'KYC Document Verify', icon: Icons.verified_user_outlined, route: '/kyc-verify'),
      if (user.can('calculator'))
        _NavItem(id: 'calculator', label: 'EMI Calculator', icon: Icons.calculate_outlined, route: '/calculator'),
      if (user.can('products'))
        _NavItem(id: 'products', label: 'Loan Products', icon: Icons.inventory_2_outlined, route: '/products'),
      if (user.can('field'))
        _NavItem(id: 'field', label: 'Field Operations & Sync', icon: Icons.explore_outlined, route: '/field'),
      if (user.can('attendance'))
        _NavItem(id: 'attendance', label: 'Attendance & Geofence', icon: Icons.access_time_outlined, route: '/attendance'),
      if (user.can('whatsapp'))
        _NavItem(id: 'whatsapp', label: 'WhatsApp Hub & OTP', icon: Icons.chat_outlined, route: '/whatsapp'),
      if (user.can('hrm') || user.can('employees'))
        _NavItem(id: 'hrm', label: 'HRM & Staff Management', icon: Icons.badge_outlined, route: '/hrm'),
      if (user.can('branches') || user.role == 'admin')
        _NavItem(id: 'branches', label: 'Branch Offices & Portfolio', icon: Icons.business_outlined, route: '/branches'),
      if (user.role == 'admin' || user.role == 'branch_manager')
        _NavItem(id: 'reports', label: 'Portfolio Reports & PAR', icon: Icons.analytics_outlined, route: '/reports'),
      _NavItem(id: 'cloud_quote', label: 'Cloud DB Quotations & Connect', icon: Icons.cloud_sync_outlined, route: '/cloud-quotes'),
      _NavItem(id: 'profile', label: 'My Profile & Security', icon: Icons.account_circle_outlined, route: '/profile'),
      if (user.role == 'admin')
        _NavItem(id: 'settings', label: 'Admin Settings & Policies', icon: Icons.settings_outlined, route: '/settings'),
    ];

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.tealPrimary,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0] : 'S',
                      style: const TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${user.roleDisplay} • ${user.branch}',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
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
                  final isActive = currentRoute == item.route;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.tealSurface : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isActive
                          ? const Border(
                              left: BorderSide(color: AppTheme.tealPrimary, width: 3.5),
                            )
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        item.icon,
                        size: 20,
                        color: isActive ? AppTheme.tealPrimary : AppTheme.textSecondary,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? AppTheme.tealPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        if (!isActive) {
                          // Home screens clear the stack; all others push so back works
                          if (item.route == '/dashboard' || item.route == '/portal') {
                            Navigator.pushReplacementNamed(context, item.route);
                          } else {
                            Navigator.pushNamed(context, item.route);
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
              leading: const Icon(Icons.logout, size: 20, color: AppTheme.danger),
              title: const Text(
                'Logout / Change Account',
                style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 13.5),
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

  _NavItem({required this.id, required this.label, required this.icon, required this.route});
}
