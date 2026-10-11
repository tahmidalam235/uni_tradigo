import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth so screens don't import firebase_auth
/// directly. All methods are async and throw [AuthException] on failure
/// with a user-friendly message — callers don't have to know about
/// Firebase's own exception types.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The currently signed-in Firebase user, or null if nobody is signed in.
  User? get currentUser => _auth.currentUser;

  /// Stream that fires whenever the user signs in or out. Used by the app
  /// to decide whether to show the Login screen or the Home screen.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs a user in with email/password. Throws [AuthException] on failure.
  ///
  /// After a successful sign-in we reload the user so any custom claims
  /// (e.g. admin role) and the email-verification flag are fresh.
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Force a token refresh so custom claims (admin etc.) are available
      // immediately on this device.
      await cred.user?.getIdToken(true);
      await cred.user?.reload();
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyLoginMessage(e));
    } catch (_) {
      throw AuthException(
        'Please check your internet connection.',
      );
    }
  }

  /// Creates a new Firebase Auth account. Throws [AuthException] on failure.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.getIdToken(true);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyRegisterMessage(e));
    } catch (_) {
      throw AuthException(
        'Please check your internet connection.',
      );
    }
  }

  /// Signs the current user out.
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Returns true if the current user is verified (custom claim `admin`).
  /// We read this from the ID token so it can be checked in security rules.
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final token = await user.getIdTokenResult(true);
      final claims = token.claims ?? const <String, dynamic>{};
      return claims['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Sends an email verification link to the currently signed-in user.
  /// Best-effort: failures are silently ignored so the caller can proceed.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // ignore — non-critical
    }
  }

  // ---- helpers -----------------------------------------------------------

  String _friendlyLoginMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password.';
      case 'user-not-found':
        return 'No account found. Please register first.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return 'Invalid email or password.';
    }
  }

  String _friendlyRegisterMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return 'Could not create account. Please try again.';
    }
  }
}

/// A simple exception with a message safe to show directly in the UI.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
