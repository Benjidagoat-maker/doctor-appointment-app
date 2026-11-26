import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  /// True only when the signed-in user has verified their email.
  bool get isEmailVerified {
    final user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }

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
  }

  /// Logs in and requires email verification for every account.
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
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.emailVerified;
  }

  /// Reads the profile. Retries once on `unavailable`.
  Future<UserModel?> getUserData(String uid) async {
    final ref = _db.collection('users').doc(uid);
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await ref.get();
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      await Future<void>.delayed(const Duration(seconds: 1));
      doc = await ref.get();
    } catch (e) {
      return null;
    }
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return UserModel.fromMap(data, doc.id);
  }

  /// Creates a roleless profile; only trusted backend code assigns role claims.
  Future<UserModel> createProfile(User user, {String? name}) async {
    final email = user.email ?? '';
    final tokenResult = await user.getIdTokenResult(true);
    final role = UserModel.normalizeRole(tokenResult.claims?['role']);

    final profile = UserModel(
      uid: user.uid,
      name: name ?? user.displayName ?? email.split('@').first,
      email: email,
      role: role,
      isOnline: true,
      lastLogin: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await _db.collection('users').doc(user.uid).set(
          profile.toMap(),
          SetOptions(merge: true),
        );
    return profile;
  }

  /// Loads profile or creates one, maintaining admin state and online presence without throwing.
  Future<UserModel> loadOrCreateProfile(User user) async {
    final email = user.email ?? '';
    UserModel? profile;
    try {
      profile = await getUserData(user.uid);
    } catch (e) {
      debugPrint('getUserData non-fatal error: $e');
    }

    if (profile == null) {
      try {
        profile = await createProfile(user);
      } catch (e) {
        debugPrint('createProfile non-fatal error: $e');
        profile = UserModel(
          uid: user.uid,
          name: user.displayName ?? email.split('@').first,
          email: email,
          role: 'user',
          isOnline: true,
          lastLogin: DateTime.now(),
          createdAt: DateTime.now(),
        );
      }
    }

    final tokenResult = await user.getIdTokenResult(true);
    final role = UserModel.normalizeRole(tokenResult.claims?['role']);
    try {
      final profileUpdates = <String, Object>{
        'is_online': true,
        'last_login': FieldValue.serverTimestamp(),
      };
      if (profile.name.isEmpty && (user.displayName?.isNotEmpty ?? false)) {
        profileUpdates['name'] = user.displayName!;
      }
      await _db.collection('users').doc(user.uid).update(profileUpdates);
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
    }

    return UserModel(
      uid: profile.uid,
      name: profile.name,
      email: profile.email,
      role: role,
      isOnline: true,
      lastLogin: DateTime.now(),
      createdAt: profile.createdAt,
    );
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
