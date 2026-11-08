import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  /// Special Bootstrap Super Admin Email
  static const String superAdminEmail = 'kenjirobenji@gmail.com';

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
      // Non-fatal: missing profile will be recreated on first login
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

  /// Reads the profile. Retries once on `unavailable`.
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

  /// Creates user profile. Automatically grants 'admin' role if matching superAdminEmail.
  Future<UserModel> createProfile(User user, {String? name}) async {
    final email = user.email ?? '';
    final isSuperAdmin = email.trim().toLowerCase() == superAdminEmail.toLowerCase();
    final role = isSuperAdmin ? 'admin' : 'user';

    final profile = UserModel(
      uid: user.uid,
      name: name ?? user.displayName ?? email.split('@').first,
      email: email,
      role: role,
      isOnline: true,
      lastLogin: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(user.uid).set(profile.toMap(), SetOptions(merge: true));
    return profile;
  }

  /// Loads profile or creates one, maintaining admin state and online presence
  Future<UserModel> loadOrCreateProfile(User user) async {
    var profile = await getUserData(user.uid);
    final email = user.email ?? '';
    final isSuperAdmin = email.trim().toLowerCase() == superAdminEmail.toLowerCase();

    if (profile == null) {
      profile = await createProfile(user);
    } else {
      // If super admin email, guarantee admin role in Firestore
      if (isSuperAdmin && profile.role.toLowerCase() != 'admin') {
        profile = UserModel(
          uid: profile.uid,
          name: profile.name,
          email: profile.email,
          role: 'admin',
          isOnline: true,
          lastLogin: DateTime.now(),
          createdAt: profile.createdAt,
        );
        await _db.collection('users').doc(user.uid).set(profile.toMap(), SetOptions(merge: true));
      } else {
        // Update presence
        try {
          await _db.collection('users').doc(user.uid).update({
            'is_online': true,
            'last_login': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    }
    return profile;
  }

  Future<void> signOut() async {
    final user = currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).update({'is_online': false});
      } catch (_) {}
    }
    await _auth.signOut();
  }
}
