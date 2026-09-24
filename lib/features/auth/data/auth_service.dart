import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/role_service.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/offline/download_manager.dart';
import '../../../core/offline/offline_storage_service.dart';
import '../../books/data/book_download_service.dart';
import '../../challenges/data/local/challenge_store.dart';
import '../../past_entrance_exams/data/past_exam_download_service.dart';
import '../../study_plan/data/local/study_task_store.dart';
import '../../admin/data/admin_service.dart';
import '../../notifications/data/notification_service.dart';
import 'models/auth_result.dart';

class AuthService {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;
  final NotificationService? _customNotificationService;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _customAuth = auth,
        _customFirestore = firestore,
        _customNotificationService = notificationService;

  FirebaseAuth get _firebaseAuth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  NotificationService get _notificationService =>
      _customNotificationService ?? NotificationService();

  static const String _deviceIdPrefKey = 'edurise_device_id';

  // ============================================================
  // DEVICE / SESSION IDENTIFIER MANAGEMENT
  // ============================================================

  /// Returns a persistent, locally-generated unique device installation ID.
  /// Does NOT access restricted hardware identifiers (IMEI, MAC, etc.).
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdPrefKey);
    if (deviceId == null || deviceId.isEmpty) {
      final rand = Random.secure();
      final values = List<int>.generate(16, (i) => rand.nextInt(256));
      final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_$hex';
      await prefs.setString(_deviceIdPrefKey, deviceId);
    }
    return deviceId;
  }

  /// Validates and records active device session in Firestore.
  /// Rejects concurrent active logins from other devices.
  Future<AuthResult> _validateAndRegisterDeviceSession(User user) async {
    try {
      // 1. Admins and Founders have multi-device preview privileges
      final isAdmin = await AdminService.isCurrentAuthorizedAdmin();
      if (isAdmin) {
        return AuthResult.success();
      }

      final currentDeviceId = await getDeviceId();
      final docRef = _firestore.collection('students').doc(user.uid);
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data();
        final activeDeviceId = data?['activeDeviceId'] as String?;

        // If another device is registered as active, reject concurrent login
        if (activeDeviceId != null &&
            activeDeviceId.isNotEmpty &&
            activeDeviceId != currentDeviceId) {
          // Sign out immediately to prevent unauthorized access
          await _firebaseAuth.signOut();
          return AuthResult.failure(
            "This student account is already active on another device. "
            "Please sign out from that device first or contact support.",
          );
        }
      }

      // Record current device as the active authorized session
      await docRef.set({
        'activeDeviceId': currentDeviceId,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return AuthResult.success();
    } catch (e) {
      // If offline, allow existing legitimate login to continue without blocking
      return AuthResult.success();
    }
  }

  /// Releases the active device session upon user logout.
  Future<void> releaseDeviceSession() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore.collection('students').doc(user.uid).update({
          'activeDeviceId': null,
          'sessionReleasedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
    } catch (_) {}
  }

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult.failure("Unable to get Google authentication token.");
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        SessionManager.startSession(user.uid);
        // Enforce single-device restriction
        final sessionResult = await _validateAndRegisterDeviceSession(user);
        if (!sessionResult.isSuccess) {
          return sessionResult;
        }

        // Sync FCM Token
        await _notificationService.syncUserToken();
      }

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
          return AuthResult.failure("Google Sign-In failed (${e.code}). Please try again.");
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('canceled') || errStr.contains('cancelled')) {
        return AuthResult.failure("Google Sign-In was cancelled.");
      }
      return AuthResult.failure(
        "Unable to sign in with Google. Please check your internet connection and try again.",
      );
    }
  }

  // ============================================================
  // EMAIL / PASSWORD AUTHENTICATION
  // ============================================================

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        SessionManager.startSession(user.uid);
        // Enforce single-device restriction
        final sessionResult = await _validateAndRegisterDeviceSession(user);
        if (!sessionResult.isSuccess) {
          return sessionResult;
        }

        // Sync FCM Token
        await _notificationService.syncUserToken();
      }

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

        case 'network-request-failed':
          return AuthResult.failure(
            "Network error. Please check your internet connection.",
          );

        case 'too-many-requests':
          return AuthResult.failure(
            "Too many attempts. Please try again later.",
          );

        case 'user-disabled':
          return AuthResult.failure("This account has been disabled.");

        default:
          return AuthResult.failure("Unable to sign in. Please try again.");
      }
    } catch (_) {
      return AuthResult.failure("Unexpected error. Please check your internet connection.");
    }
  }

  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        if (name != null && name.trim().isNotEmpty) {
          try {
            await user.updateDisplayName(name.trim());
          } catch (_) {}
        }

        // Enforce single-device restriction
        await _validateAndRegisterDeviceSession(user);

        // Send idempotent admin notification on successful registration
        await _notificationService.sendAdminNotificationOnce(
          idempotencyKey: 'new_student_${user.uid}',
          title: 'New Student Registration',
          body: 'A new student account has registered: ${user.email ?? user.uid}',
          type: 'new_student',
          metadata: {'studentId': user.uid, 'email': user.email},
        );

        // Sync token
        await _notificationService.syncUserToken();
      }

      await user?.sendEmailVerification();
      return AuthResult.success("Verification email sent.");
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return AuthResult.failure("This email is already registered.");

        case 'weak-password':
          return AuthResult.failure("Please choose a stronger password (at least 6 characters).");

        case 'invalid-email':
          return AuthResult.failure("Please enter a valid email address.");

        case 'network-request-failed':
          return AuthResult.failure(
            "Network error. Please check your internet connection.",
          );

        case 'too-many-requests':
          return AuthResult.failure(
            "Too many attempts. Please try again later.",
          );

        default:
          return AuthResult.failure("Registration failed. Please try again.");
      }
    } catch (_) {
      return AuthResult.failure("Unexpected error. Please check your internet connection.");
    }
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<AuthResult> sendPasswordResetEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      return AuthResult.failure("Please enter your email address.");
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalized);
      return AuthResult.success(
        "If an account exists for this email, a password reset link has been sent.",
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          return AuthResult.failure("Please enter a valid email address.");

        case 'user-not-found':
          // Standard security practice to prevent email enumeration
          return AuthResult.success(
            "If an account exists for this email, a password reset link has been sent.",
          );

        case 'network-request-failed':
          return AuthResult.failure(
            "Network error. Please check your internet connection.",
          );

        case 'too-many-requests':
          return AuthResult.failure(
            "Too many reset requests. Please wait a while before trying again.",
          );

        default:
          return AuthResult.failure("Unable to send reset email. Please try again.");
      }
    } catch (_) {
      return AuthResult.failure("Unexpected error. Please check your internet connection.");
    }
  }

  // ============================================================
  // LOGOUT & SESSION INVALIDATION
  // ============================================================

  Future<void> signOut() async {
    SessionManager.resetSession();
    RoleService.clearCache();
    AdminService.clearCache();
    OfflineStorageService.instance.clearMemoryCache();
    DownloadManager().clearMemoryCache();
    BookDownloadService().clearMemoryCache();
    PastExamDownloadService().clearMemoryCache();
    ChallengeStore().clearMemoryCache();
    StudyTaskStore().clearMemoryCache();
    _notificationService.resetSessionState();

    await releaseDeviceSession();
    await _notificationService.clearUserToken();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _firebaseAuth.signOut();
  }

  Future<AuthResult> sendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return AuthResult.failure("No authenticated account found.");
      }
      await user.sendEmailVerification();
      return AuthResult.success("Verification email sent.");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        return AuthResult.failure("Too many requests. Please wait before requesting again.");
      }
      return AuthResult.failure("Unable to send verification email. Please try again.");
    } catch (_) {
      return AuthResult.failure("Unable to send verification email.");
    }
  }

  Future<void> reloadUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  bool isEmailVerified() {
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }
}
