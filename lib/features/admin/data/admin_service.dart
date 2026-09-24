import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/auth/role_service.dart';
import '../../../core/auth/user_role.dart';
import 'audit_service.dart';

/// Administrative management service for founder-only roster administration
/// and administrative actions.
///
/// Role resolution is delegated to [RoleService] in core.
class AdminService {
  static const String founderEmail = RoleService.founderEmail;
  static const String adminEmail = RoleService.adminEmail;

  static void setMockInstances({FirebaseAuth? auth, FirebaseFirestore? firestore}) {
    RoleService.setMockInstances(auth: auth, firestore: firestore);
  }

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _adminsCollection =>
      _firestore.collection('admins');

  /// Clear in-memory role cache (used on sign-out / account switching)
  static void clearCache() => RoleService.clearCache();

  /// Resolve destination route authoritatively immediately following authentication
  /// or during authenticated startup.
  static Future<String> resolvePostAuthRoute({bool forceRefresh = false}) =>
      RoleService.resolvePostAuthRoute(forceRefresh: forceRefresh);

  // ============================================================
  // SYNCHRONOUS / FAST GETTERS (DELEGATED TO ROLESERVICE)
  // ============================================================

  static String? get currentUserEmail => RoleService.currentUserEmail;
  static String? get currentUserId => RoleService.currentUserId;
  static bool get isFounder => RoleService.isFounder;
  static bool get isAdmin => RoleService.isAdmin;
  static bool get isAuthorizedAdmin => RoleService.isAuthorizedAdmin;

  // ============================================================
  // TRUSTED ASYNC ROLE VERIFICATION (DELEGATED TO ROLESERVICE)
  // ============================================================

  static Future<UserRole> getCurrentRole({bool forceRefresh = false}) =>
      RoleService.getCurrentRole(forceRefresh: forceRefresh);

  static Future<bool> isCurrentAuthorizedAdmin() =>
      RoleService.isCurrentAuthorizedAdmin();

  static Future<bool> isCurrentFounder() =>
      RoleService.isCurrentFounder();

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
