import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:doctor_appointment_app/utils/app_utils.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidEmail', () {
    test('accepts normal addresses (and trims)', () {
      expect(isValidEmail('user@example.com'), isTrue);
      expect(isValidEmail('  first.last+tag@sub.example.org '), isTrue);
    });
    test('rejects malformed addresses', () {
      for (final bad in ['', 'plain', 'a@b', '@example.com', 'a b@c.com']) {
        expect(isValidEmail(bad), isFalse, reason: bad);
      }
    });
  });

  group('describeError', () {
    test('maps credential errors to one non-revealing message', () {
      for (final code in ['wrong-password', 'user-not-found', 'invalid-credential']) {
        expect(describeError(FirebaseAuthException(code: code)),
            'Incorrect email or password.');
      }
    });

    test('Firestore unavailable gives actionable guidance', () {
      final msg = describeError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
      expect(msg, contains('Cannot reach the database'));
      expect(msg, contains('Firestore'));
    });

    test('permission-denied is explained', () {
      expect(
        describeError(FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied')),
        contains('Access denied'),
      );
    });

    test('AppException message passes through unchanged', () {
      expect(describeError(const AppException('Nope')), 'Nope');
    });

    test('unknown errors never leak raw exception text', () {
      expect(describeError(StateError('secret internals')),
          'Something went wrong. Please try again.');
    });
  });
}
