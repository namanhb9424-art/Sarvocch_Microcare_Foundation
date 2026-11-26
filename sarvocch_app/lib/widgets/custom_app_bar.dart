import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const CustomAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final userId = context.read<AuthProvider>().currentUser?.id;

    final Color pillColor = sync.isSyncing
        ? AppTheme.warning
        : sync.isCloudOnline
            ? AppTheme.success
            : Colors.blueGrey.shade700;
    final String pillLabel = sync.isSyncing
        ? 'Syncing...'
        : sync.isCloudOnline
            ? (sync.pendingCount > 0 ? 'Sync (${sync.pendingCount})' : 'Cloud Live')
            : (sync.pendingCount > 0 ? 'Offline (${sync.pendingCount})' : 'Offline');

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
        InkWell(
          onTap: sync.isSyncing
              ? null
              : () async {
                  await sync.triggerFullSync(userId: userId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(sync.lastSyncStatus),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sync.isSyncing)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                  )
                else
                  Icon(
                    sync.isCloudOnline ? Icons.cloud_done : Icons.sync,
                    size: 12,
                    color: Colors.white,
                  ),
                const SizedBox(width: 5),
                Text(
                  pillLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        ...?actions,
        const SizedBox(width: 6),
      ],
    );
  }
}
