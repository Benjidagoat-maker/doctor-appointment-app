import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/otp_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import 'email_verification_screen.dart';
import 'otp_verification_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message, {Color color = AppTheme.dangerRed}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    // Passwords are never trimmed: spaces can be part of a valid password.
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in both email and password.');
      return;
    }
    if (!isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isSuperAdmin =
          email.trim().toLowerCase() == AuthService.superAdminEmail.toLowerCase();

      UserCredential creds;
      try {
        creds = await _auth.login(email, password);
      } on FirebaseAuthException catch (e) {
        // If super admin account does not exist in Firebase Auth yet, auto-create it!
        if (isSuperAdmin &&
            (e.code == 'user-not-found' ||
                e.code == 'invalid-credential' ||
                e.code == 'wrong-password')) {
          try {
            await _auth.signUp(
              name: 'Super Admin Kenji',
              email: email,
              password: password,
            );
            creds = await _auth.login(email, password);
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // Step 2: Trigger Firebase 2-Step OTP Verification
      final otpCode = await OtpService().sendOtp(
        email: email,
        userId: creds.user!.uid,
      );

      if (!mounted) return;
      // Step 3: Present sleek 6-digit Glassmorphic OTP Input screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            user: creds.user!,
            initialOtpCode: otpCode,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-not-verified') {
        _showEmailNotVerified(email, password);
      } else {
        _showError(describeError(e));
      }
    } catch (e) {
      if (!mounted) return;
      _showError(describeError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmailNotVerified(String email, String password) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Email not verified. Check your inbox or tap to resend.'),
        backgroundColor: Colors.orange.shade700,
        action: SnackBarAction(
          label: 'Resend',
          textColor: Colors.white,
          onPressed: () async {
            // Temporarily sign in to resend the email, then sign out again.
            try {
              await FirebaseAuth.instance
                  .signInWithEmailAndPassword(email: email, password: password);
              await _auth.resendVerificationEmail();
              await _auth.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => EmailVerificationScreen(email: email)),
              );
            } catch (e) {
              if (mounted) _showError(describeError(e));
            }
          },
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!isValidEmail(email)) {
      _showError('Enter your email above first, then tap "Forgot password?".');
      return;
    }
    try {
      await _auth.resetPassword(email);
      if (!mounted) return;
      _showError('If an account exists for $email, a reset link was sent.',
          color: AppTheme.successGreen);
    } catch (e) {
      if (mounted) _showError(describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        size: 48,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to book doctor appointments and view your records',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 36),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _isLoading ? null : _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _forgotPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        ),
                        child: const Text(
                          'Register now',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
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
