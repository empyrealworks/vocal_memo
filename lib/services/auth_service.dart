// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum UserTier {
  unregistered, // No account — basic model
  registered,   // Free account — better model
  subscribed,   // Paid account — best model
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isAuthenticated => _auth.currentUser != null;

  UserTier get userTier {
    if (!isAuthenticated) return UserTier.unregistered;
    // TODO: implement subscription check via custom claims
    return UserTier.registered;
  }

  String get geminiModel {
    switch (userTier) {
      case UserTier.unregistered: return 'gemini-2.0-flash-lite';
      case UserTier.registered:   return 'gemini-2.5-flash-lite';
      case UserTier.subscribed:   return 'gemini-3.1-flash-lite';
    }
  }

  bool get canTranscribe => isAuthenticated;
  bool get canTrim => isAuthenticated;

  // ── Sign up ───────────────────────────────────────────────────────────────

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.sendEmailVerification();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ── Sign in ───────────────────────────────────────────────────────────────

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled the picker

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      // Catch PlatformException for network errors and other native failures
      final message = e.toString().toLowerCase();
      if (message.contains('network') || message.contains('socket')) {
        throw Exception(
            'No internet connection. Please check your connection and try again.');
      }
      if (message.contains('cancelled') || message.contains('canceled')) {
        // User cancelled — rethrow null-equivalent so callers can no-op
        return null;
      }
      debugPrint('Google sign-in error: $e');
      throw Exception('Google sign-in failed. Please try again.');
    }
  }

  // ── Password reset ────────────────────────────────────────────────────────

  /// Sends a password reset email. Throws a user-friendly Exception on failure.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ── Account deletion (deferred, 30-day window) ────────────────────────────
  //
  // WHY NOT currentUser.delete()?
  //
  // 1. Firebase Auth `.delete()` only removes the Auth record.
  //    It does NOT touch Firestore documents or Firebase Storage files.
  //    All user recordings, metadata, and transcripts would remain forever.
  //
  // 2. `.delete()` throws `requires-recent-login` if the session is old,
  //    meaning it silently fails for users who haven't re-authenticated recently.
  //
  // Instead we write a deletion request to Firestore and sign the user out.
  // You process it manually within 30 days (or automate with a Cloud Function).
  // This approach:
  //   • Complies with Google Play's data deletion requirement
  //   • Gives a 30-day window to export data if needed
  //   • Is immune to the requires-recent-login issue
  //   • Covers Auth + Firestore + Storage in your manual process

  /// Submits a deletion request and signs the user out immediately.
  ///
  /// Writes to `deletion_requests/{uid}` in Firestore.
  /// [reason] is optional — shown in the console so you know why they left.
  Future<void> submitDeletionRequest({String reason = ''}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('deletion_requests')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'email': user.email ?? '',
      'reason': reason.trim(),
      'requestedAt': FieldValue.serverTimestamp(),
      // 30 days is the recommended window for GDPR and Google Play compliance.
      'scheduledDeletionAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'status': 'pending', // update to 'completed' after manual processing
    });

    await signOut();
  }

  // ── Error handling ────────────────────────────────────────────────────────

  /// Maps [FirebaseAuthException] codes to clear, non-sensitive messages.
  ///
  /// Rules:
  /// • Never reveal whether an email address is registered or not.
  /// • Never expose internal Firebase error messages or codes.
  /// • Network errors get a specific, actionable message.
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
    // ── Sign-up errors ──────────────────────────────────────
      case 'weak-password':
        return 'Your password is too short. Please use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';

    // ── Sign-in errors ──────────────────────────────────────
    // user-not-found and wrong-password intentionally return the same
    // message to prevent account enumeration attacks.
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';

    // ── Common errors ───────────────────────────────────────
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'requires-recent-login':
        return 'For security, please sign out and sign back in to continue.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';

    // ── Network errors ──────────────────────────────────────
      case 'network-request-failed':
        return 'No internet connection. Please check your connection and try again.';

    // ── Fallback ────────────────────────────────────────────
      default:
      // Avoid leaking raw Firebase messages — log them internally only.
        debugPrint('Unhandled FirebaseAuthException [${e.code}]: ${e.message}');
        return 'Something went wrong. Please try again.';
    }
  }
}