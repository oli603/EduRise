import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../offline/offline_storage_service.dart';
import 'user_role.dart';

/// Status of the post-authentication route resolution
enum PostAuthRouteStatus {
  unauthenticated,
  authorizedAdmin,
  existingStudent,
  needsProfileSetup,
  offlineVerificationRequired,
}

/// Structured result of post-authentication route resolution
class PostAuthRouteResult {
  final PostAuthRouteStatus status;
  final String route;
  final String? message;

  const PostAuthRouteResult({
    required this.status,
    required this.route,
    this.message,
  });

  bool get isHome => status == PostAuthRouteStatus.existingStudent;
  bool get isAdmin => status == PostAuthRouteStatus.authorizedAdmin;
  bool get isProfileSetup => status == PostAuthRouteStatus.needsProfileSetup;
  bool get isOfflineVerificationRequired =>
      status == PostAuthRouteStatus.offlineVerificationRequired;

  @override
  String toString() =>
      'PostAuthRouteResult(status: $status, route: $route, message: $message)';
}

/// Single source of truth for user role resolution and role-based permissions in EduRise.
///
/// Multi-Tier Role Resolution:
/// - Tier 1: Firebase Auth Custom Claims (instant, 0 Firestore reads)
/// - Tier 2: admins/{uid} canonical document lookup
/// - Tier 3: Bootstrap authority (founderEmail & adminEmail)
/// - Tier 4: admins/{email} provisioning document & students/{uid}.role fallback
class RoleService {
  static const String founderEmail = 'olanamengistu2@gmail.com';
  static const String adminEmail = 'tamiratboja@gmail.com';

  static FirebaseAuth? _customAuth;
  static FirebaseFirestore? _customFirestore;
  static OfflineStorageService? _customStorage;

  static void setMockInstances({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    OfflineStorageService? storage,
    dynamic profileService, // Backward compatibility for tests passing profileService
  }) {
    _customAuth = auth;
    _customFirestore = firestore;
    _customStorage = storage;
  }

  static FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  static FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  static OfflineStorageService get _storage =>
      _customStorage ?? OfflineStorageService();

  static CollectionReference<Map<String, dynamic>> get _adminsCollection =>
      _firestore.collection('admins');

  // In-memory role cache to accelerate route-guards and UI checks
  static UserRole? _cachedRole;
  static String? _cachedUid;

  /// Clear in-memory role cache (used on sign-out / account switching)
  static void clearCache() {
    _cachedRole = null;
    _cachedUid = null;
  }

  /// Sets cached role directly for unit/widget testing
  @visibleForTesting
  static void setRoleForTesting(UserRole role) {
    _cachedRole = role;
  }

  /// Authoritative structured route resolution immediately following authentication
  /// or during application startup.
  ///
  /// Offline-First Principle:
  /// - Unauthenticated -> '/login'
  /// - Founder or Admin -> '/admin'
  /// - Student with valid local profile cache -> '/home' (0 network calls, works offline)
  /// - Student without local profile (online) -> fetches Firestore profile, caches it, and routes to '/home' or '/profile-setup'
  /// - Student without local profile (offline) -> returns 'offlineVerificationRequired' to prevent false onboarding loop
  static Future<PostAuthRouteResult> resolvePostAuthRouteResult({
    bool forceRefresh = false,
  }) async {
    User? user;
    try {
      user = _auth.currentUser;
    } catch (_) {
      user = null;
    }

    if (user == null) {
      clearCache();
      return const PostAuthRouteResult(
        status: PostAuthRouteStatus.unauthenticated,
        route: '/login',
      );
    }

    final email = user.email?.toLowerCase().trim() ?? '';

    // Fast check: If recognized founder or bootstrap admin email, or in-memory cached admin
    if (email == founderEmail || email == adminEmail) {
      _cachedRole = email == founderEmail ? UserRole.founder : UserRole.admin;
      _cachedUid = user.uid;
      return const PostAuthRouteResult(
        status: PostAuthRouteStatus.authorizedAdmin,
        route: '/admin',
      );
    }

    if (!forceRefresh && _cachedUid == user.uid && _cachedRole != null && _cachedRole!.isAuthorizedAdmin) {
      return const PostAuthRouteResult(
        status: PostAuthRouteStatus.authorizedAdmin,
        route: '/admin',
      );
    }

    // 1. FAST LOCAL CHECK FIRST: Inspect local student profile cache (0 network calls, true offline startup)
    if (!forceRefresh) {
      try {
        final cachedProfile = await _storage.getStudentProfile(user.uid);
        if (cachedProfile != null && cachedProfile.uid == user.uid) {
          if (cachedProfile.name.isNotEmpty &&
              cachedProfile.grade.isNotEmpty &&
              cachedProfile.stream.isNotEmpty) {
            _cachedRole = UserRole.student;
            _cachedUid = user.uid;
            return const PostAuthRouteResult(
              status: PostAuthRouteStatus.existingStudent,
              route: '/home',
            );
          }
        }
      } catch (e) {
        debugPrint('RoleService: Error reading cached profile: $e');
      }
    }

    // 2. REMOTE CHECK (Only if no valid local profile cache exists or forceRefresh is requested)
    // First check if user has custom claims or remote admin role with strict timeouts
    final role = await getCurrentRole(forceRefresh: forceRefresh);
    if (role.isAuthorizedAdmin) {
      return const PostAuthRouteResult(
        status: PostAuthRouteStatus.authorizedAdmin,
        route: '/admin',
      );
    }

    // Next check authoritative Firestore student document with bounded timeout
    try {
      final doc = await _firestore
          .collection('students')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 3));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final hasName = (data['name'] as String?)?.trim().isNotEmpty == true;
        final hasGrade = (data['grade'] as String?)?.trim().isNotEmpty == true;
        final hasStream = (data['stream'] as String?)?.trim().isNotEmpty == true;

        if (hasName && hasGrade && hasStream) {
          // Cache the remotely fetched profile for subsequent offline startups
          try {
            final record = StudentProfileRecord.fromFirestore(user.uid, data);
            await _storage.saveStudentProfile(record);
          } catch (e) {
            debugPrint('RoleService: Error caching fetched profile: $e');
          }

          _cachedRole = UserRole.student;
          _cachedUid = user.uid;
          return const PostAuthRouteResult(
            status: PostAuthRouteStatus.existingStudent,
            route: '/home',
          );
        } else {
          return const PostAuthRouteResult(
            status: PostAuthRouteStatus.needsProfileSetup,
            route: '/profile-setup',
          );
        }
      } else {
        return const PostAuthRouteResult(
          status: PostAuthRouteStatus.needsProfileSetup,
          route: '/profile-setup',
        );
      }
    } catch (e) {
      // If forceRefresh was true and remote check failed (offline/timeout), check if we have a valid local cache to fall back to
      if (forceRefresh) {
        try {
          final cachedProfile = await _storage.getStudentProfile(user.uid);
          if (cachedProfile != null &&
              cachedProfile.uid == user.uid &&
              cachedProfile.name.isNotEmpty &&
              cachedProfile.grade.isNotEmpty &&
              cachedProfile.stream.isNotEmpty) {
            _cachedRole = UserRole.student;
            _cachedUid = user.uid;
            return const PostAuthRouteResult(
              status: PostAuthRouteStatus.existingStudent,
              route: '/home',
            );
          }
        } catch (_) {}
      }

      // Network/Firestore unavailable and no local profile cache exists.
      // We must not guess /home or /profile-setup without evidence.
      // Route to dedicated offline verification screen so user stays authenticated.
      return const PostAuthRouteResult(
        status: PostAuthRouteStatus.offlineVerificationRequired,
        route: '/offline-verification',
        message:
            "You're signed in, but this device hasn't cached your student profile yet. Connect to the internet once to verify your profile and continue.",
      );
    }
  }

  /// Resolve destination route string authoritatively immediately following authentication
  /// or during authenticated startup.
  static Future<String> resolvePostAuthRoute({bool forceRefresh = false}) async {
    final result = await resolvePostAuthRouteResult(forceRefresh: forceRefresh);
    return result.route;
  }

  // ============================================================
  // SYNCHRONOUS / FAST GETTERS (BACKWARD COMPATIBLE & UI QUICK-CHECK)
  // ============================================================

  static String? get currentUserEmail {
    try {
      return _auth.currentUser?.email?.toLowerCase().trim();
    } catch (_) {
      return null;
    }
  }

  static String? get currentUserId {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static bool get isFounder {
    if (_cachedRole != null) return _cachedRole!.isFounder;
    final email = currentUserEmail;
    if (email != null && email == founderEmail) return true;
    return false;
  }

  static bool get isAdmin {
    if (_cachedRole != null) return _cachedRole!.isAdmin;
    final email = currentUserEmail;
    if (email != null && (email == adminEmail || email == founderEmail)) return true;
    return false;
  }

  static bool get isAuthorizedAdmin {
    if (_cachedRole != null) return _cachedRole!.isAuthorizedAdmin;
    return isFounder || isAdmin;
  }

  // ============================================================
  // TRUSTED ASYNC ROLE VERIFICATION
  // ============================================================

  static Future<UserRole> getCurrentRole({bool forceRefresh = false}) async {
    User? user;
    try {
      user = _auth.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) {
      _cachedRole = UserRole.student;
      _cachedUid = null;
      return UserRole.student;
    }

    if (!forceRefresh && user.uid == _cachedUid && _cachedRole != null) {
      return _cachedRole!;
    }

    final email = user.email?.toLowerCase().trim() ?? '';

    // Tier 1: Custom Claims (Instant, 0 Firestore reads)
    try {
      final tokenResult = await user
          .getIdTokenResult(forceRefresh)
          .timeout(const Duration(seconds: 2));
      final claimRole = tokenResult.claims?['role'] as String?;
      if (claimRole != null && claimRole.isNotEmpty) {
        final parsed = UserRole.fromString(claimRole);
        if (parsed.isAuthorizedAdmin) {
          _cachedRole = parsed;
          _cachedUid = user.uid;
          return parsed;
        }
      }
    } catch (_) {}

    // Tier 3 Root Check: Founder bootstrap authority
    if (email == founderEmail) {
      _cachedRole = UserRole.founder;
      _cachedUid = user.uid;
      return UserRole.founder;
    }

    try {
      // Tier 2: Check canonical admins/{uid} document
      final docByUid = await _adminsCollection
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 2));
      if (docByUid.exists) {
        final data = docByUid.data();
        final isActive = data?['isActive'] as bool? ?? true;
        if (isActive) {
          final roleString = data?['role'] as String?;
          final resolvedRole = UserRole.fromString(roleString);
          _cachedRole = resolvedRole;
          _cachedUid = user.uid;
          return resolvedRole;
        } else {
          _cachedRole = UserRole.student;
          _cachedUid = user.uid;
          return UserRole.student;
        }
      }

      // Tier 4 Fallback A: Check provisioned admins/{email} document
      if (email.isNotEmpty) {
        final docByEmail = await _adminsCollection
            .doc(email)
            .get()
            .timeout(const Duration(seconds: 2));
        if (docByEmail.exists) {
          final data = docByEmail.data()!;
          final isActive = data['isActive'] as bool? ?? true;
          if (isActive) {
            final roleString = data['role'] as String?;
            final resolvedRole = UserRole.fromString(roleString);

            // Auto-promote to canonical UID document for subsequent O(1) resolution
            unawaited(_adminsCollection.doc(user.uid).set({
              ...data,
              'uid': user.uid,
              'email': email,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 2)).catchError((_) {}));

            _cachedRole = resolvedRole;
            _cachedUid = user.uid;
            return resolvedRole;
          }
        }

        // Tier 4 Fallback B: Check provisioned admins query by email
        final queryByEmail = await _adminsCollection
            .where('email', isEqualTo: email)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 2));

        if (queryByEmail.docs.isNotEmpty) {
          final doc = queryByEmail.docs.first;
          final data = doc.data();
          final isActive = data['isActive'] as bool? ?? true;
          if (isActive) {
            final roleString = data['role'] as String?;
            final resolvedRole = UserRole.fromString(roleString);

            // Mirror to canonical UID document
            unawaited(_adminsCollection.doc(user.uid).set({
              ...data,
              'uid': user.uid,
              'email': email,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 2)).catchError((_) {}));

            _cachedRole = resolvedRole;
            _cachedUid = user.uid;
            return resolvedRole;
          }
        }
      }

      // Tier 3 Root Check: Operational admin bootstrap authority
      if (email == adminEmail) {
        _cachedRole = UserRole.admin;
        _cachedUid = user.uid;
        return UserRole.admin;
      }

      // Tier 4 Fallback C: Legacy student doc role check (backward-compatible)
      final studentDoc = await _firestore
          .collection('students')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 2));
      if (studentDoc.exists) {
        final roleString = studentDoc.data()?['role'] as String?;
        if (roleString != null && roleString.isNotEmpty) {
          final resolvedRole = UserRole.fromString(roleString);
          if (resolvedRole.isAuthorizedAdmin) {
            _cachedRole = resolvedRole;
            _cachedUid = user.uid;
            return resolvedRole;
          }
        }
      }
    } catch (_) {
      // Offline fallback to bootstrap emails
      if (email == founderEmail) return UserRole.founder;
      if (email == adminEmail) return UserRole.admin;
    }

    _cachedRole = UserRole.student;
    _cachedUid = user.uid;
    return UserRole.student;
  }

  static Future<bool> isCurrentAuthorizedAdmin() async {
    final role = await getCurrentRole();
    return role.isAuthorizedAdmin;
  }

  static Future<bool> isCurrentFounder() async {
    final role = await getCurrentRole();
    return role.isFounder;
  }
}
