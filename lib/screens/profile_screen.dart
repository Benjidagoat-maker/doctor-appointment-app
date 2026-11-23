import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final name = user?.displayName?.trim();
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 42,
                backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.18),
                child: Text(
                  (name?.isNotEmpty == true
                          ? name![0]
                          : email.isNotEmpty
                          ? email[0]
                          : 'U')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name?.isNotEmpty == true ? name! : 'Your profile',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 32),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(email),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Account status'),
                      subtitle: Text(
                        user?.emailVerified == true
                            ? 'Email verified'
                            : 'Email not verified',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
