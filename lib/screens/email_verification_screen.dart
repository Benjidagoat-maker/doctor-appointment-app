import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Screen shown after sign-up. Waits for the user to verify their Gmail address.
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _auth = AuthService();
  Timer? _pollTimer;
  bool _isResending = false;
  bool _verified = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Poll Firebase every 4 seconds to detect when the user clicks the email link
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final verified = await _auth.checkEmailVerified();
      if (verified && mounted) {
        _pollTimer?.cancel();
        setState(() => _verified = true);
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        // Sign out so user logs in freshly (triggers the new login guard)
        await _auth.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _resendEmail() async {
    if (_resendCooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await _auth.resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email re-sent! Check your inbox.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      // Start 60-second cooldown before resend is allowed again
      setState(() => _resendCooldown = 60);
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) t.cancel();
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not resend: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _cancelAndGoBack() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _verified
                        ? const Icon(Icons.verified_rounded, size: 80, color: AppTheme.successGreen, key: ValueKey('verified'))
                        : const Icon(Icons.mark_email_unread_outlined, size: 80, color: AppTheme.primaryBlue, key: ValueKey('pending')),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _verified ? 'Email Verified!' : 'Check Your Gmail',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _verified
                        ? 'Your account is now active. Redirecting to login…'
                        : 'We sent a verification link to:\n${widget.email}\n\nClick the link in that email to activate your account.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted, height: 1.6),
                  ),
                  const SizedBox(height: 32),

                  if (!_verified) ...[
                    // Animated waiting indicator
                    const SizedBox(
                      height: 36,
                      width: 36,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Waiting for verification…',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    // Resend button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_isResending || _resendCooldown > 0) ? null : _resendEmail,
                        icon: _isResending
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _resendCooldown > 0
                              ? 'Resend in ${_resendCooldown}s'
                              : 'Resend Verification Email',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _cancelAndGoBack,
                      child: const Text(
                        'Use a different account',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

