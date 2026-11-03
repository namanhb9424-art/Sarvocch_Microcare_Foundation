import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class QuickRoleSwitchSheet extends StatelessWidget {
  const QuickRoleSwitchSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final users = auth.demoUsers;
    final current = auth.currentUser;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.tealSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.switch_account, color: AppTheme.tealPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demo Role Switcher',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Instant trial switch between portal roles & permissions',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final u = users[index];
                final isSelected = current?.username == u.username;

                Color badgeColor;
                IconData roleIcon;
                switch (u.role) {
                  case 'admin':
                    badgeColor = Colors.purple;
                    roleIcon = Icons.admin_panel_settings;
                    break;
                  case 'manager':
                    badgeColor = Colors.indigo;
                    roleIcon = Icons.business_center;
                    break;
                  case 'underwriter':
                    badgeColor = Colors.teal;
                    roleIcon = Icons.fact_check;
                    break;
                  case 'field_agent':
                    badgeColor = Colors.orange.shade800;
                    roleIcon = Icons.directions_walk;
                    break;
                  case 'customer':
                    badgeColor = Colors.green.shade700;
                    roleIcon = Icons.person;
                    break;
                  default:
                    badgeColor = Colors.grey;
                    roleIcon = Icons.account_circle;
                }

                return InkWell(
                  onTap: () {
                    auth.switchDemoRole(u.username);
                    Navigator.pop(context); // Close bottom sheet
                    // Navigate to role's home screen, clearing the stack
                    if (u.role == 'customer') {
                      Navigator.pushNamedAndRemoveUntil(context, '/portal', (route) => false);
                    } else {
                      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to ${u.name} (${u.roleDisplay})'),
                        backgroundColor: const Color(0xFF0F766E),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.tealSurface : AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.tealPrimary : AppTheme.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected ? AppTheme.tealPrimary : Colors.white,
                          child: Icon(
                            roleIcon,
                            size: 18,
                            color: isSelected ? Colors.white : AppTheme.tealPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    u.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      u.roleDisplay,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Username: ${u.username} • Branch: ${u.branch}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppTheme.tealPrimary, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
