import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final oldPass = _oldPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields')),
      );
      return;
    }

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters')),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      final db = await DatabaseHelper.instance.database;

      // Verify old password
      final userRow = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [currentUser.id],
      );

      if (userRow.isEmpty || userRow.first['password_hash'] != oldPass) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current password is incorrect'), backgroundColor: AppTheme.danger),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Update password
      await db.update(
        'users',
        {'password_hash': newPass},
        where: 'id = ?',
        whereArgs: [currentUser.id],
      );

      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error changing password: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'My Profile'),
        body: Center(child: Text('No active session')),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'User Profile & Security'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.tealPrimary,
                      child: Text(
                        user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.tealSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.tealPrimary.withOpacity(0.3)),
                      ),
                      child: Text(
                        user.role.toUpperCase().replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.tealDark),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 10),
                    _profileRow(Icons.account_circle_outlined, 'Username', user.username),
                    _profileRow(Icons.badge_outlined, 'Employee ID / CIF', 'EMP-${user.id.toString().padLeft(3, '0')}'),
                    _profileRow(Icons.business_outlined, 'Assigned Branch', user.branch.isNotEmpty ? user.branch : 'Headquarters'),
                    _profileRow(Icons.verified_user_outlined, 'Status', user.role.isNotEmpty ? 'Active & Authorized' : 'Suspended'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Change Password Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_reset, color: AppTheme.tealPrimary),
                        SizedBox(width: 8),
                        Text('Change Account Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _oldPassCtrl,
                      obscureText: _obscureOld,
                      decoration: InputDecoration(
                        labelText: 'Current Password *',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureOld = !_obscureOld),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPassCtrl,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password (min 6 chars) *',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassCtrl,
                      obscureText: _obscureNew,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password *',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Update Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppTheme.danger),
                label: const Text('Sign Out from Device', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
                onPressed: () {
                  auth.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

