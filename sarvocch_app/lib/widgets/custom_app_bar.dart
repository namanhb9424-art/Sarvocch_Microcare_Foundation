import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'quick_role_switch_sheet.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showRoleSwitcher;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showRoleSwitcher = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      actions: [
        // Online Badge matching web '#netpill'
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          margin: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.success,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 3, backgroundColor: Colors.white),
              SizedBox(width: 5),
              Text(
                'Online',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        if (showRoleSwitcher && user != null)
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const QuickRoleSwitchSheet(),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    user.role.toUpperCase().replaceAll('_', ' '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (actions != null) ...actions!,
        const SizedBox(width: 8),
      ],
    );
  }
}
