// auth/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '102278939910-rm39u1tfacnhldlrqld6ci77okjurdr4.apps.googleusercontent.com',
  );

  /// Stream that emits user state changes (login/logout)
  static Stream<User?> get userStream => _auth.authStateChanges();

  /// Current signed-in user (null if logged out)
  static User? get currentUser => _auth.currentUser;

  // ─── Email & Password ──────────────────────────────────────────────────────

  static Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw _authError(e.code);
    }
  }

  static Future<UserCredential?> registerWithEmail(
      String email, String password, String username) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);

      // ── Keep existing behavior: set display name ───────────────────────────
      await cred.user?.updateDisplayName(username);

      // ── ADD: create Firestore user document so the user appears in messages
      // Without this, the user exists in Firebase Auth but NOT in
      // Firestore "users" collection, so they won't appear in UsersListScreen.
      if (cred.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'name': username,
          'email': email.trim(),
        });
      }

      return cred;
    } on FirebaseAuthException catch (e) {
      throw _authError(e.code);
    }
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _authError(e.code);
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Helper ────────────────────────────────────────────────────────────────

  static String _authError(String code) {
    switch (code) {
      case 'user-not-found':       return 'No account found with this email.';
      case 'wrong-password':       return 'Incorrect password. Try again.';
      case 'email-already-in-use': return 'This email is already registered.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      case 'invalid-email':        return 'Please enter a valid email address.';
      case 'network-request-failed': return 'No internet connection.';
      default:                     return 'Something went wrong. Please try again.';
    }
  }
}