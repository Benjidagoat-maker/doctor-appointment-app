import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/otp_service.dart';
import '../theme/app_theme.dart';
import 'admin_dashboard.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// 2-Step OTP Verification Screen (Dashboard V22 Glassmorphic Dark Theme)
class OtpVerificationScreen extends StatefulWidget {
  final User user;
  final String? initialOtpCode;

  const OtpVerificationScreen({
    super.key,
    required this.user,
    this.initialOtpCode,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final OtpService _otpService = OtpService();

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  String? _currentOtpCode;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _currentOtpCode = widget.initialOtpCode;
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());

    _startCountdown();

    // Auto-focus first digit on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _countdownTimer?.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    // Handle full paste into a single box (e.g. 6 digits pasted)
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 6) {
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = digits[i];
        }
        _focusNodes[5].requestFocus();
        _verifyOtp();
        return;
      }
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = widget.user.email ?? '';
      final newCode = await _otpService.sendOtp(
        email: email,
        userId: widget.user.uid,
      );

      if (mounted) {
        setState(() {
          _currentOtpCode = newCode;
          _isLoading = false;
        });
        _startCountdown();
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mark_email_read, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'New 6-digit verification code sent to ${widget.user.email}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.v22ElectricBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to resend code. Please try again.';
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _enteredCode;
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = widget.user.email ?? '';
    final isValid = await _otpService.verifyOtp(
      email: email,
      enteredCode: code,
      localCode: _currentOtpCode,
    );

    if (!isValid) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid or expired OTP code. Please check and try again.';
        });
      }
      return;
    }

    // OTP Verified! Write/Update Firestore and redirect based on role
    try {
      final profile = await _otpService.finalizeOtpAuthentication(widget.user);
      if (!mounted) return;

      final isSuperAdmin = email.trim().toLowerCase() ==
          AuthService.superAdminEmail.toLowerCase();
      final destination = (profile.isAdmin || isSuperAdmin)
          ? const AdminDashboard()
          : const HomeScreen();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBackground = Color(0xFF0B0F19);
    final email = widget.user.email ?? 'your email';

    return Scaffold(
      backgroundColor: darkBackground,
      body: Stack(
        children: [
          // Background Glowing Electric Radial Accents
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.v22ElectricBlue.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.v22ElectricCyan.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Logo & Badge
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.v22ElectricGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.v22ElectricBlue.withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Two-Step Verification',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Enter the 6-digit code sent to\n$email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),

                    if (_currentOtpCode != null) ...[
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () {
                          // Tap to auto-fill for frictionless testing
                          final code = _currentOtpCode!;
                          for (int i = 0; i < 6 && i < code.length; i++) {
                            _controllers[i].text = code[i];
                          }
                          _verifyOtp();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.v22ElectricBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.v22ElectricBlue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.key, color: AppTheme.v22ElectricCyan, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Demo OTP Code: $_currentOtpCode (Tap to fill)',
                                style: const TextStyle(
                                  color: AppTheme.v22ElectricCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Frosted Glassmorphism Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131B2E).withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.v22ElectricBlue.withValues(alpha: 0.18),
                                blurRadius: 36,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 6 Glassmorphic OTP Boxes
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (i) => _buildOtpBox(i)),
                              ),

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerRed.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.dangerRed.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppTheme.dangerRed, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: Color(0xFFFF8B8B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 28),

                              // Verify Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: _isLoading ? null : _verifyOtp,
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.v22ElectricGradient,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.v22ElectricBlue.withValues(alpha: 0.45),
                                          blurRadius: 18,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.4,
                                              ),
                                            )
                                          : const Text(
                                              'Verify & Sign In',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Resend Code Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _canResend
                                        ? "Didn't receive the code? "
                                        : 'Resend code in ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  if (!_canResend)
                                    Text(
                                      '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.v22ElectricCyan,
                                      ),
                                    )
                                  else
                                    TextButton(
                                      onPressed: _isLoading ? null : _resendCode,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Resend Code',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.v22ElectricCyan,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Back to Login link
                    TextButton.icon(
                      onPressed: () {
                        AuthService().signOut();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      icon: Icon(Icons.arrow_back,
                          size: 16, color: Colors.white.withValues(alpha: 0.6)),
                      label: Text(
                        'Back to Sign In',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return AnimatedBuilder(
      animation: Listenable.merge([_focusNodes[index], _controllers[index]]),
      builder: (context, _) {
        final isFocused = _focusNodes[index].hasFocus;
        final hasValue = _controllers[index].text.isNotEmpty;
        final isError = _errorMessage != null;

        return Focus(
          onKeyEvent: (node, event) {
            // Handle backspace navigation when current box is empty
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace) {
              if (_controllers[index].text.isEmpty && index > 0) {
                _controllers[index - 1].clear();
                _focusNodes[index - 1].requestFocus();
              }
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color: isFocused
                  ? AppTheme.v22ElectricBlue.withValues(alpha: 0.20)
                  : const Color(0xFF1E293B).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isError
                    ? AppTheme.dangerRed
                    : isFocused
                        ? AppTheme.v22ElectricCyan
                        : hasValue
                            ? AppTheme.v22ElectricBlue.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.15),
                width: isFocused ? 2.0 : 1.2,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: AppTheme.v22ElectricCyan.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6), // Allow paste
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) => _onDigitChanged(index, val),
              ),
            ),
          ),
        );
      },
    );
  }
}

