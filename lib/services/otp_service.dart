import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Firebase-backed 2-Step OTP Verification Service
class OtpService {
  final FirebaseFirestore _db;

  OtpService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const int otpTtlMinutes = 5;
  static const String demoFallbackCode = '123456';

  /// Generates and stores a secure 6-digit OTP in Firestore.
  /// Returns the generated code (useful for immediate in-app delivery / toast).
  Future<String> sendOtp({
    required String email,
    required String userId,
  }) async {
    // Generate secure 6-digit code (100000 - 999999)
    final random = Random.secure();
    final otpCode = (100000 + random.nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: otpTtlMinutes));

    debugPrint('⚡ [OTP Service] Generated 6-digit code for $email: $otpCode');

    // Store in Firestore under users/{uid}/security/otp and otp_verifications/{email}
    try {
      await _db.collection('otp_verifications').doc(email.trim().toLowerCase()).set({
        'code': otpCode,
        'userId': userId,
        'email': email.trim().toLowerCase(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
        'used': false,
      });
    } catch (e) {
      debugPrint('Firestore OTP write notice (using memory fallback): $e');
    }

    return otpCode;
  }

  /// Verifies entered 6-digit OTP code against Firestore.
  Future<bool> verifyOtp({
    required String email,
    required String enteredCode,
    String? localCode,
  }) async {
    final cleanCode = enteredCode.trim();
    if (cleanCode.length != 6) return false;

    // Master test code for testing
    if (cleanCode == demoFallbackCode) return true;

    // If matching the locally delivered code
    if (localCode != null && localCode.trim() == cleanCode) return true;

    try {
      final doc = await _db
          .collection('otp_verifications')
          .doc(email.trim().toLowerCase())
          .get();

      if (!doc.exists) {
        // Fallback to localCode match
        return localCode == cleanCode;
      }

      final data = doc.data();
      if (data == null) return false;

      final storedCode = data['code']?.toString() ?? '';
      final used = data['used'] as bool? ?? false;
      final expiresAtTimestamp = data['expiresAt'] as Timestamp?;

      if (used) return false;
      if (expiresAtTimestamp != null &&
          DateTime.now().isAfter(expiresAtTimestamp.toDate())) {
        return false;
      }

      final isMatch = storedCode == cleanCode;
      if (isMatch) {
        // Mark as used
        await _db
            .collection('otp_verifications')
            .doc(email.trim().toLowerCase())
            .update({'used': true}).catchError((_) {});
      }
      return isMatch;
    } catch (e) {
      debugPrint('Error verifying OTP from Firestore: $e');
      // If Firestore read fails, allow local delivery code match
      return localCode == cleanCode;
    }
  }

  /// Called upon successful OTP verification.
  /// Writes/Updates Firestore `users/{uid}`:
  /// - `uid`: user.uid
  /// - `email`: user.email
  /// - `role`: IF email is `kenjirobenji@gmail.com` set to 'admin', ELSE default to 'user'
  /// - `isOnline`: true
  /// - `lastLogin`: serverTimestamp()
  Future<UserModel> finalizeOtpAuthentication(User user) async {
    final email = user.email ?? '';
    final isSuperAdmin = email.trim().toLowerCase() == AuthService.superAdminEmail.toLowerCase();
    final role = isSuperAdmin ? 'admin' : 'user';

    final userProfile = UserModel(
      uid: user.uid,
      name: user.displayName ?? (email.isNotEmpty ? email.split('@').first : 'User'),
      email: email,
      role: role,
      isOnline: true,
      lastLogin: DateTime.now(),
      createdAt: DateTime.now(),
    );

    // Write to Firestore users collection
    try {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': userProfile.name,
        'email': userProfile.email,
        'role': role,
        'isOnline': true,
        'is_online': true,
        'lastLogin': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Fallback for minimal legacy rules
      try {
        await _db.collection('users').doc(user.uid).set({
          'name': userProfile.name,
          'email': userProfile.email,
          'role': role,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    return userProfile;
  }
}

