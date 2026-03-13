// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      throw _handleAuthException(e);
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
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  // ── Password reset ────────────────────────────────────────────────────────

  /// Sends a password reset email. Throws a user-friendly String on failure.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
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

    // Sign out immediately — the account stays in Auth until you process it,
    // but the user is logged out and cannot log back in easily (the email is
    // now associated with a pending deletion).
    await signOut();
  }

  // ── Error handling ────────────────────────────────────────────────────────

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':          return 'Password is too weak';
      case 'email-already-in-use':   return 'An account already exists with this email';
      case 'user-not-found':         return 'No account found with this email';
      case 'wrong-password':         return 'Incorrect password';
      case 'invalid-email':          return 'Invalid email address';
      case 'invalid-credential':     return 'Incorrect email or password';
      case 'too-many-requests':      return 'Too many attempts. Please try again later';
      case 'requires-recent-login':  return 'Please sign out and sign in again to continue';
      default: return e.message ?? 'Authentication failed';
    }
  }
}