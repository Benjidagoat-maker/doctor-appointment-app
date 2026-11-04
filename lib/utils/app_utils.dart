import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;

/// An error whose [message] is already safe and friendly to show to the user.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

/// Turns any error into a short, user-friendly sentence.
/// Never leaks stack traces or raw exception dumps into the UI.
String describeError(Object error) {
  if (error is AppException) return error.message;

  // FirebaseAuthException extends FirebaseException, so check it first.
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      default:
        return error.message ?? 'Authentication failed (${error.code}).';
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
        return 'Cannot reach the database. Check your connection, disable '
            'ad-blockers/VPN for this site, and make sure Cloud Firestore is '
            'enabled for this Firebase project.';
      case 'permission-denied':
        return 'Access denied by the security rules (or App Check). '
            'Please sign in again or contact support.';
      default:
        return error.message ?? 'Request failed (${error.code}).';
    }
  }

  return 'Something went wrong. Please try again.';
}
