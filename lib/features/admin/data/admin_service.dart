import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/auth/user_role.dart';
import '../../profile_setup/data/profile_service.dart';
import 'audit_service.dart';

class AdminService {
  static const String founderEmail = 'olanamengistu2@gmail.com';
  static const String adminEmail = 'tamiratboja@gmail.com';

  static FirebaseAuth? _customAuth;
  static FirebaseFirestore? _customFirestore;

  static void setMockInstances({FirebaseAuth? auth, FirebaseFirestore? firestore}) {
    _customAuth = auth;
    _customFirestore = firestore;
  }

  static FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  static FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

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

  /// Resolve destination route authoritatively immediately following authentication
  /// or during authenticated startup.
  ///
  /// Immediate Founder/Admin Recognition:
  /// - Founder or Admin -> routes directly to '/admin' without querying student profile.
  /// - Student -> checks if student profile exists; routes to '/home' or '/profile-setup'.
  static Future<String> resolvePostAuthRoute({bool forceRefresh = false}) async {
    User? user;
    try {
      user = _auth.currentUser;
    } catch (_) {
      user = null;
    }

    if (user == null) {
      clearCache();
      return '/login';
    }

    final role = await getCurrentRole(forceRefresh: forceRefresh);
    if (role.isAuthorizedAdmin) {
      return '/admin';
    }

    final profileService = ProfileService();
    try {
      final exists = await profileService.profileExists();
      if (exists) {
        return '/home';
      } else {
        return '/profile-setup';
      }
    } catch (_) {
      return '/profile-setup';
    }
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
    final email = currentUserEmail;
    if (email != null && email == founderEmail) return true;

    try {
      final user = _auth.currentUser;
      if (user != null && user.uid == _cachedUid && _cachedRole != null) {
        return _cachedRole!.isFounder;
      }
    } catch (_) {}
    return false;
  }

  static bool get isAdmin {
    final email = currentUserEmail;
    if (email != null && (email == adminEmail || email == founderEmail)) return true;

    try {
      final user = _auth.currentUser;
      if (user != null && user.uid == _cachedUid && _cachedRole != null) {
        return _cachedRole!.isAdmin;
      }
    } catch (_) {}
    return false;
  }

  static bool get isAuthorizedAdmin {
    try {
      final user = _auth.currentUser;
      if (user != null && user.uid == _cachedUid && _cachedRole != null) {
        return _cachedRole!.isAuthorizedAdmin;
      }
    } catch (_) {}
    return isFounder || isAdmin;
  }

  // ============================================================
  // TRUSTED ASYNC ROLE VERIFICATION
  // Multi-tier hierarchy:
  // Tier 1: Firebase Auth Custom Claims (forward-compatible)
  // Tier 2: admins/{uid} canonical document lookup
  // Tier 3: Bootstrap authority (founderEmail & adminEmail)
  // Tier 4: admins/{email} provisioning document & students/{uid}.role
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
      final tokenResult = await user.getIdTokenResult(forceRefresh);
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
      final docByUid = await _adminsCollection.doc(user.uid).get();
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
        final docByEmail = await _adminsCollection.doc(email).get();
        if (docByEmail.exists) {
          final data = docByEmail.data()!;
          final isActive = data['isActive'] as bool? ?? true;
          if (isActive) {
            final roleString = data['role'] as String?;
            final resolvedRole = UserRole.fromString(roleString);

            // Auto-promote to canonical UID document for subsequent O(1) resolution
            await _adminsCollection.doc(user.uid).set({
              ...data,
              'uid': user.uid,
              'email': email,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            _cachedRole = resolvedRole;
            _cachedUid = user.uid;
            return resolvedRole;
          }
        }

        // Tier 4 Fallback B: Check provisioned admins query by email
        final queryByEmail = await _adminsCollection
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (queryByEmail.docs.isNotEmpty) {
          final doc = queryByEmail.docs.first;
          final data = doc.data();
          final isActive = data['isActive'] as bool? ?? true;
          if (isActive) {
            final roleString = data['role'] as String?;
            final resolvedRole = UserRole.fromString(roleString);

            // Mirror to canonical UID document
            await _adminsCollection.doc(user.uid).set({
              ...data,
              'uid': user.uid,
              'email': email,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

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
      final studentDoc = await _firestore.collection('students').doc(user.uid).get();
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

  // ============================================================
  // FOUNDER-ONLY ADMIN MANAGEMENT
  // ============================================================

  static Future<List<Map<String, dynamic>>> getAdmins() async {
    final snapshot = await _adminsCollection.orderBy('createdAt', descending: true).get();

    final list = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    // Ensure founder and default admin always appear if collection is new
    final hasFounder = list.any((a) => (a['email'] as String?)?.toLowerCase() == founderEmail);
    if (!hasFounder) {
      list.insert(0, {
        'id': 'bootstrap_founder',
        'email': founderEmail,
        'name': 'Primary Founder',
        'role': 'founder',
        'isActive': true,
        'isPermanent': true,
      });
    }

    final hasDefaultAdmin = list.any((a) => (a['email'] as String?)?.toLowerCase() == adminEmail);
    if (!hasDefaultAdmin) {
      list.add({
        'id': 'bootstrap_admin',
        'email': adminEmail,
        'name': 'Operational Admin',
        'role': 'admin',
        'isActive': true,
        'isPermanent': false,
      });
    }

    return list;
  }

  static Future<void> addAdmin({
    required String email,
    required String name,
    String role = 'admin',
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }

    final currentUser = _auth.currentUser;
    final currentRole = await getCurrentRole();
    if (!currentRole.isFounder) {
      throw Exception('Unauthorized: Only the Founder can add new administrators.');
    }

    // Check if admin already exists by email
    final existingQuery = await _adminsCollection
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw Exception('An administrator with this email already exists.');
    }

    // Attempt to resolve existing student UID if user is already registered
    String? targetUid;
    try {
      final studentLookup = await _firestore
          .collection('students')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (studentLookup.docs.isNotEmpty) {
        targetUid = studentLookup.docs.first.id;
      }
    } catch (_) {}

    final adminPayload = {
      'uid': targetUid,
      'email': cleanEmail,
      'name': name.trim(),
      'role': role == 'founder' ? 'founder' : 'admin',
      'isActive': true,
      'status': 'active',
      'createdBy': currentUser?.uid,
      'creatorEmail': currentUser?.email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Canonical UID document if UID known, otherwise deterministic email document
    if (targetUid != null && targetUid.isNotEmpty) {
      await _adminsCollection.doc(targetUid).set(adminPayload);
    } else {
      await _adminsCollection.doc(cleanEmail).set(adminPayload);
    }

    // Audit log
    await AuditService.logAction(
      action: 'admin_added',
      targetType: 'admin',
      targetId: targetUid ?? cleanEmail,
      metadata: {
        'email': cleanEmail,
        'role': role,
        'name': name.trim(),
      },
    );
  }

  static Future<void> setAdminActive(String adminDocId, bool isActive) async {
    final currentRole = await getCurrentRole();
    if (!currentRole.isFounder) {
      throw Exception('Unauthorized: Only the Founder can toggle administrator status.');
    }

    final doc = await _adminsCollection.doc(adminDocId).get();
    if (!doc.exists) {
      throw Exception('Admin document not found.');
    }

    final data = doc.data();
    final targetEmail = (data?['email'] as String?)?.toLowerCase();
    if (targetEmail == founderEmail) {
      throw Exception('Cannot deactivate the primary founder.');
    }

    await _adminsCollection.doc(adminDocId).update({
      'isActive': isActive,
      'status': isActive ? 'active' : 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Also synchronize canonical UID doc if adminDocId was email
    final targetUid = data?['uid'] as String?;
    if (targetUid != null && targetUid.isNotEmpty && targetUid != adminDocId) {
      try {
        await _adminsCollection.doc(targetUid).update({
          'isActive': isActive,
          'status': isActive ? 'active' : 'suspended',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    await AuditService.logAction(
      action: isActive ? 'admin_activated' : 'admin_deactivated',
      targetType: 'admin',
      targetId: adminDocId,
      metadata: {'targetEmail': targetEmail, 'isActive': isActive},
    );
  }

  static Future<void> removeAdmin(String adminDocId) async {
    final currentRole = await getCurrentRole();
    if (!currentRole.isFounder) {
      throw Exception('Unauthorized: Only the Founder can remove administrators.');
    }

    final doc = await _adminsCollection.doc(adminDocId).get();
    if (!doc.exists) {
      throw Exception('Admin document not found.');
    }

    final data = doc.data();
    final targetEmail = (data?['email'] as String?)?.toLowerCase();
    if (targetEmail == founderEmail) {
      throw Exception('Cannot delete the primary founder.');
    }

    final targetUid = data?['uid'] as String?;

    await _adminsCollection.doc(adminDocId).delete();

    // If there was also a linked UID doc, delete it
    if (targetUid != null && targetUid.isNotEmpty && targetUid != adminDocId) {
      try {
        await _adminsCollection.doc(targetUid).delete();
      } catch (_) {}
    }

    await AuditService.logAction(
      action: 'admin_removed',
      targetType: 'admin',
      targetId: adminDocId,
      metadata: {'targetEmail': targetEmail},
    );
  }
}
