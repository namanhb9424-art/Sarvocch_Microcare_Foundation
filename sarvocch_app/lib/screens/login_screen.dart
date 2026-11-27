import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    final auth = context.read<AuthProvider>();
    final username = _usernameCtrl.text;
    final password = _passwordCtrl.text;
    final success = await auth.login(username, password);

    if (!mounted) return;
    _passwordCtrl.clear();

    if (success) {
      if (auth.currentUser?.role == 'customer') {
        Navigator.pushReplacementNamed(context, '/portal');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else {
      setState(() {
        _errorMessage =
            auth.lastLoginError ??
            'Sign-in failed. Check your credentials or contact your administrator.';
      });
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.clear();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icon/app_logo.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sarvoocch Saathi',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'SARVOOCCH Microcare Foundation • Microfinance',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Login Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sign In to Portal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Enter your account credentials to continue',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.dangerLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.danger.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppTheme.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppTheme.danger,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Username
                          const Text(
                            'Username',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _usernameCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Enter username',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              hintText: 'Enter password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed:
                                  auth.isLoading || auth.needsAccountRecovery
                                  ? null
                                  : _handleLogin,
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(fontSize: 15),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Role Switcher / Credentials Helper (All 5 Roles)
                  Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.verified_user_outlined, color: AppTheme.tealPrimary, size: 20),
                      title: const Text(
                        'Role Credentials (Cloud & Offline)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Tap any role to fill working login details',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cred in const [
                              ['Admin', 'admin', 'admin123'],
                              ['Branch Manager', 'manager1', 'manager123'],
                              ['Underwriter', 'uw1', 'uw123'],
                              ['Field Officer (Indore)', 'agent1', 'agent123'],
                              ['Field Officer (Palasia)', 'agent2', 'agent123'],
                              ['Field Officer (Bhopal)', 'agent3', 'agent123'],
                              ['Customer Portal', 'cust1', 'cust123'],
                            ])
                              ActionChip(
                                avatar: const Icon(Icons.person, size: 15, color: AppTheme.tealPrimary),
                                label: Text('${cred[0]} (${cred[1]})', style: const TextStyle(fontSize: 11.5)),
                                onPressed: () {
                                  _usernameCtrl.text = cred[1];
                                  _passwordCtrl.text = cred[2];
                                  setState(() => _errorMessage = null);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.help_outline, size: 17, color: AppTheme.tealPrimary),
                      label: const Text(
                        'Need an account? View Provisioning Policy',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.tealPrimary, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Account Provisioning Policy'),
                            content: const Text(
                              'Self-registration is intentionally disabled for regulatory & data security.\n\n'
                              '• Staff & Field Officer accounts are provisioned by your Branch Administrator under User Accounts & Access.\n'
                              '• Borrower Portal accounts are provisioned once KYC is verified by Branch Staff.\n\n'
                              'Please contact your Branch Manager or Head Office to receive your login credentials.',
                              style: TextStyle(fontSize: 13.5, height: 1.4),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Understood'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (auth.needsAccountRecovery)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No active administrator is available. Contact your organization support team to restore access.',
                          style: TextStyle(color: AppTheme.danger),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Sarvoocch Saathi · v2.1.0+4',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
