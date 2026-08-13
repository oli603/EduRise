import 'package:firebase_auth/firebase_auth.dart';

import 'models/auth_result.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _firebaseAuth = FirebaseAuth.instance;
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;

      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult.failure("Unable to get Google authentication token.");
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      await _firebaseAuth.signInWithCredential(credential);

      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'account-exists-with-different-credential':
          return AuthResult.failure(
            "An account already exists with this email. "
            "Please sign in with email first.",
          );

        case 'network-request-failed':
          return AuthResult.failure(
            "Network error. Please check your internet connection.",
          );

        case 'operation-not-allowed':
          return AuthResult.failure(
            "Google Sign-In is not enabled in Firebase.",
          );

        default:
          return AuthResult.failure("Google Sign-In failed. Please try again.");
      }
    } catch (e) {
      return AuthResult.failure(
        "Unable to sign in with Google. Please try again.",
      );
    }
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return AuthResult.failure("No account found with this email.");

        case 'wrong-password':
          return AuthResult.failure("Incorrect password.");

        case 'invalid-email':
          return AuthResult.failure("Please enter a valid email address.");

        case 'invalid-credential':
          return AuthResult.failure("Email or password is incorrect.");

        case 'too-many-requests':
          return AuthResult.failure(
            "Too many attempts. Please try again later.",
          );

        default:
          return AuthResult.failure("Something went wrong. Please try again.");
      }
    } catch (_) {
      return AuthResult.failure("Unexpected error. Please try again.");
    }
  }

  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.sendEmailVerification();

      return AuthResult.success("Verification email sent.");
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return AuthResult.failure("This email is already registered.");

        case 'weak-password':
          return AuthResult.failure("Please choose a stronger password.");

        case 'invalid-email':
          return AuthResult.failure("Please enter a valid email.");

        default:
          return AuthResult.failure("Firebase error: ${e.code} - ${e.message}");
      }
    } catch (_) {
      return AuthResult.failure("Unexpected error. Please try again.");
    }
  }

  Future<AuthResult> sendVerificationEmail() async {
    try {
      await _firebaseAuth.currentUser?.sendEmailVerification();

      return AuthResult.success("Verification email sent.");
    } catch (_) {
      return AuthResult.failure("Unable to send verification email.");
    }
  }

  Future<void> reloadUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  bool isEmailVerified() {
    return _firebaseAuth.currentUser?.emailVerified ??
        false; //  current is user null false
  }
}
