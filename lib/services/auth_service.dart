import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  /// Firebase instances are resolved lazily so the service (and the screens
  /// that own one) can be constructed in tests without Firebase initialised.
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _authOverride = auth,
        _dbOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// True only when the user is logged in AND has verified their email.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Registers a new user and sends the verification email.
  /// The email is sent BEFORE the Firestore write so a database problem can
  /// never leave an account that can't be verified; a missing profile is
  /// recreated on first login by [loadOrCreateProfile].
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = res.user!;
    await user.updateDisplayName(name);
    await user.sendEmailVerification();
    try {
      await createProfile(user, name: name);
    } catch (_) {
      // Non-fatal, see doc comment above.
    }
  }

  /// Logs in. If email is not verified, signs back out and throws an error.
  Future<UserCredential> login(String email, String password) async {
    final creds = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (!creds.user!.emailVerified) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message:
            'Please check your inbox and verify your email before logging in.',
      );
    }
    return creds;
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Resend a verification email to the currently signed-in (but unverified) user.
  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Reload the user object so emailVerified reflects the latest status.
  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Reads the profile. Retries once on `unavailable` (a transient "client is
  /// offline" is common right after sign-in on web while the connection opens).
  Future<UserModel?> getUserData(String uid) async {
    final ref = _db.collection('users').doc(uid);
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await ref.get();
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      await Future<void>.delayed(const Duration(seconds: 2));
      doc = await ref.get();
    }
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return UserModel.fromMap(data, doc.id);
  }

  /// Creates the default (non-admin) profile. Security rules only allow
  /// role == 'user' here; admins are promoted manually in the console.
  Future<UserModel> createProfile(User user, {String? name}) async {
    final email = user.email ?? '';
    final profile = UserModel(
      uid: user.uid,
      name: name ?? user.displayName ?? email.split('@').first,
      email: email,
      role: 'user',
    );
    await _db.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  Future<UserModel> loadOrCreateProfile(User user) async =>
      await getUserData(user.uid) ?? await createProfile(user);

  Future<void> signOut() => _auth.signOut();
}
