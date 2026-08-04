import 'package:firebase_auth/firebase_auth.dart';

import 'models/auth_result.dart';

class AuthService {
  final _firebaseAuth = FirebaseAuth.instance;

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
          return AuthResult.failure("Unable to create your account.");
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
