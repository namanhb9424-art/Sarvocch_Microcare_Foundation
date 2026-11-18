import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, Object?>> _accounts = [];
  List<Map<String, Object?>> _employees = [];
  List<Map<String, Object?>> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final actor = context.read<AuthProvider>().currentUser;
    if (actor == null || actor.role != 'admin') {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final accounts = await auth.listManagedAccounts(actor.id);
    final employees = await auth.listUnlinkedEmployees(actor.id);
    final customers = await auth.listCustomersWithoutAccounts(actor.id);
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _employees = employees;
      _customers = customers;
      _loading = false;
    });
  }

  Future<void> _createStaffAccount() async {
    if (_employees.isEmpty) {
      _message('Add an employee in HRM before creating a staff login.');
      return;
    }
    final actor = context.read<AuthProvider>().currentUser;
    if (actor == null) return;
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    var selectedEmployeeId = _employees.first['id'] as int;
    var selectedRole = 'field_agent';
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create staff login'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedEmployeeId,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: _employees
                      .map(
                        (employee) => DropdownMenuItem<int>(
                          value: employee['id'] as int,
                          child: Text(
                            '${employee['name']} • ${employee['branch']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedEmployeeId = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'manager',
                      child: Text('Branch Manager'),
                    ),
                    DropdownMenuItem(
                      value: 'underwriter',
                      child: Text('Underwriter'),
                    ),
                    DropdownMenuItem(
                      value: 'field_agent',
                      child: Text('Field Officer'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: usernameCtrl,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Username *',
                    helperText:
                        '3–64 letters, numbers, dots, dashes or underscores',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password *',
                    helperText: 'At least 12 characters; user must change it',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Give the temporary password directly to the employee. The app does not send it.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await context
                    .read<AuthProvider>()
                    .createStaffAccount(
                      actorUserId: actor.id,
                      employeeId: selectedEmployeeId,
                      username: usernameCtrl.text,
                      role: selectedRole,
                      initialPassword: passwordCtrl.text,
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
              },
              child: const Text('Create login'),
            ),
          ],
        ),
      ),
    );
    usernameCtrl.dispose();
    passwordCtrl.clear();
    passwordCtrl.dispose();
    if (created == true) {
      await _load();
      _message('Staff login created. The employee must change the password.');
    } else if (created == false && mounted) {
      _message(
        'Login was not created. Check the username and employee record.',
      );
    }
  }

  Future<void> _createCustomerAccount() async {
    if (_customers.isEmpty) {
      _message('No customers without portal accounts are available.');
      return;
    }
    final actor = context.read<AuthProvider>().currentUser;
    if (actor == null) return;
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    var selectedCustomerId = _customers.first['id'] as int;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create customer portal login'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedCustomerId,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: _customers
                      .map(
                        (customer) => DropdownMenuItem<int>(
                          value: customer['id'] as int,
                          child: Text(
                            '${customer['name']} • ${customer['phone']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCustomerId = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: usernameCtrl,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(labelText: 'Username *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password *',
                    helperText: 'At least 12 characters; user must change it',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await context
                    .read<AuthProvider>()
                    .createCustomerAccount(
                      actorUserId: actor.id,
                      customerId: selectedCustomerId,
                      username: usernameCtrl.text,
                      initialPassword: passwordCtrl.text,
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
              },
              child: const Text('Create portal login'),
            ),
          ],
        ),
      ),
    );
    usernameCtrl.dispose();
    passwordCtrl.clear();
    passwordCtrl.dispose();
    if (created == true) {
      await _load();
      _message('Customer portal login created. Password change is required.');
    } else if (created == false && mounted) {
      _message(
        'Portal login was not created. Check the username and customer.',
      );
    }
  }

  Future<void> _resetPassword(Map<String, Object?> account) async {
    final actor = context.read<AuthProvider>().currentUser;
    final targetUserId = account['id'] as int;
    if (actor == null || targetUserId == actor.id) return;
    final passwordCtrl = TextEditingController();
    final reset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reset password for ${account['name']}'),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Temporary password *',
            helperText: 'At least 12 characters; user must change it',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await context
                  .read<AuthProvider>()
                  .resetManagedAccountPassword(
                    actorUserId: actor.id,
                    targetUserId: targetUserId,
                    temporaryPassword: passwordCtrl.text,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
            },
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
    passwordCtrl.clear();
    passwordCtrl.dispose();
    if (reset == true) {
      await _load();
      _message('Password reset. The user must change it after signing in.');
    } else if (reset == false && mounted) {
      _message('Password was not reset. Check the password length.');
    }
  }

  Future<void> _setActive(Map<String, Object?> account, bool active) async {
    final actor = context.read<AuthProvider>().currentUser;
    final targetUserId = account['id'] as int;
    if (actor == null || targetUserId == actor.id) return;
    final changed = await context.read<AuthProvider>().setManagedAccountActive(
      actorUserId: actor.id,
      targetUserId: targetUserId,
      active: active,
    );
    if (changed) {
      await _load();
    } else {
      _message(
        'Account status was not changed. The last administrator stays active.',
      );
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<AuthProvider>().currentUser;
    if (actor == null || actor.role != 'admin') {
      return const Scaffold(
        appBar: CustomAppBar(title: 'User Accounts'),
        body: Center(child: Text('Administrator access is required.')),
      );
    }
    return Scaffold(
      appBar: const CustomAppBar(title: 'User Accounts & Access'),
      drawer: const CustomDrawer(currentRoute: '/users'),
      floatingActionButton: PopupMenuButton<String>(
        tooltip: 'Create account',
        icon: const Icon(Icons.person_add),
        onSelected: (value) {
          if (value == 'staff') _createStaffAccount();
          if (value == 'customer') _createCustomerAccount();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'staff', child: Text('Staff account')),
          PopupMenuItem(
            value: 'customer',
            child: Text('Customer portal account'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _accounts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 150),
                        Center(child: Text('No user accounts found.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _accounts.length,
                      itemBuilder: (context, index) =>
                          _accountCard(_accounts[index], actor),
                    ),
            ),
    );
  }

  Widget _accountCard(Map<String, Object?> account, UserModel actor) {
    final id = account['id'] as int;
    final role = account['role'] as String? ?? 'unknown';
    final status = account['auth_status'] as String? ?? 'unknown';
    final isSelf = id == actor.id;
    final isActive = status == 'active';
    final personType = account['customer_id'] != null
        ? 'Customer ${account['customer_id']}'
        : account['employee_id'] != null
        ? '${account['designation'] ?? 'Staff'} • EMP-${account['employee_id']}'
        : 'Administrator account';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? AppTheme.tealSurface : Colors.black12,
          child: Icon(
            role == 'customer' ? Icons.person_outline : Icons.badge_outlined,
            color: isActive ? AppTheme.tealPrimary : AppTheme.textSecondary,
          ),
        ),
        title: Text(account['name'] as String? ?? 'Unnamed account'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '@${account['username']} • ${role.replaceAll('_', ' ')}\n'
            '${account['branch'] ?? 'No branch'} • $personType\n'
            'Status: $status${(account['must_change'] as int? ?? 0) == 1 ? ' • Password change required' : ''}',
          ),
        ),
        isThreeLine: true,
        trailing: isSelf
            ? const Text('You', style: TextStyle(color: AppTheme.textSecondary))
            : PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'reset') _resetPassword(account);
                  if (action == 'activate') _setActive(account, true);
                  if (action == 'disable') _setActive(account, false);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Reset password'),
                  ),
                  PopupMenuItem(
                    value: isActive ? 'disable' : 'activate',
                    child: Text(
                      isActive ? 'Disable account' : 'Enable account',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
