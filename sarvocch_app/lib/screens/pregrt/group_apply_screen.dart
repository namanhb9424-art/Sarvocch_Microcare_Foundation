import 'package:flutter/material.dart';
import '../../models/pregrt_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class GroupApplyScreen extends StatelessWidget {
  final PreGrtModel group;

  const GroupApplyScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Group ${group.centerNo} / ${group.groupNo}',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Batch origination is unavailable until the organization configures per-member income and expense capture, approved loan terms, and group disclosure text. Submit each member through the individual loan application so those checks and approvals are recorded.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final member in group.members)
            Card(
              child: ListTile(
                title: Text(member.name),
                subtitle: Text(
                  member.customerId == null
                      ? 'No linked customer record'
                      : 'Customer #${member.customerId}',
                ),
                trailing: member.customerId == null
                    ? null
                    : const Icon(Icons.chevron_right,
                        color: AppTheme.tealPrimary),
                enabled: member.customerId != null,
                onTap: member.customerId == null
                    ? null
                    : () => Navigator.pushNamed(
                          context,
                          '/apply',
                          arguments: member.customerId,
                        ),
              ),
            ),
        ],
      ),
    );
  }
}
