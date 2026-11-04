import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// True only when the user is logged in AND has verified their email.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Registers a new user, saves their profile in Firestore,
  /// then sends a Gmail verification email.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String role = 'user',
  }) async {
    final res = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update display name in Firebase Auth
    await res.user!.updateDisplayName(name);

    // Save user document to Firestore
    final newUser = UserModel(
      uid: res.user!.uid,
      name: name,
      email: email,
      role: role,
    );
    await _db.collection('users').doc(res.user!.uid).set(newUser.toMap());

    // Send Gmail verification email
    await res.user!.sendEmailVerification();
  }

  /// Logs in. If email is not verified, signs back out and throws an error.
  Future<UserCredential> login(String email, String password) async {
    final creds = await _auth.signInWithEmailAndPassword(
      email: email,
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

  /// Resend a verification email to the currently signed-in (but unverified) user.
  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Reload the user object so emailVerified reflects the latest status.
  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<UserModel?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<void> signOut() => _auth.signOut();
}
