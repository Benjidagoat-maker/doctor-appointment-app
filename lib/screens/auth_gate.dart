import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin_dashboard.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Restores the previous session on app start instead of always showing the
/// login form: verified user -> Home (or Admin), otherwise -> Login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Widget> _destination = _resolve();

  Future<Widget> _resolve() async {
    try {
      // First event = persisted session restored (currentUser is not reliable
      // yet at cold start on web).
      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user == null || !user.emailVerified) return const LoginScreen();
      final profile = await AuthService().loadOrCreateProfile(user);
      return profile.role == 'admin'
          ? const AdminDashboard()
          : const HomeScreen();
    } catch (_) {
      // Can't load the profile (offline, rules...): fall back to a clean login.
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.data!;
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
