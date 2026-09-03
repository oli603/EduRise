import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/auth/user_role.dart';

class AdminService {
  static const String founderEmail = 'olanamengistu2@gmail.com';
  static const String adminEmail = 'tamiratboja@gmail.com';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _adminsCollection =>
      _firestore.collection('admins');

  // ============================================================
  // SYNCHRONOUS / FAST GETTERS (BACKWARD COMPATIBLE & UI QUICK-CHECK)
  // ============================================================

  static String? get currentUserEmail {
    return _auth.currentUser?.email?.toLowerCase().trim();
  }

  static String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  static bool get isFounder {
    final email = currentUserEmail;
    return email != null && email == founderEmail;
  }

  static bool get isAdmin {
    final email = currentUserEmail;
    return email != null && (email == adminEmail || email == founderEmail);
  }

  static bool get isAuthorizedAdmin {
    return isFounder || isAdmin;
  }

  // ============================================================
  // TRUSTED ASYNC ROLE VERIFICATION
  // Uses Firebase Auth UID as primary identity, with Firestore verification.
  // ============================================================

  static Future<UserRole> getCurrentRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      return UserRole.student;
    }

    final email = user.email?.toLowerCase().trim() ?? '';

    // Primary founder check (bootstrap / root authority)
    if (email == founderEmail) {
      return UserRole.founder;
    }

    try {
      // 1. Check admins collection by UID
      final docByUid = await _adminsCollection.doc(user.uid).get();
      if (docByUid.exists) {
        final data = docByUid.data();
        final isActive = data?['isActive'] as bool? ?? true;
        if (isActive) {
          final roleString = data?['role'] as String?;
          return UserRole.fromString(roleString);
        } else {
          return UserRole.student;
        }
      }

      // 2. Check admins collection by Email query (for provisioned admins before first login)
      if (email.isNotEmpty) {
        final queryByEmail = await _adminsCollection
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (queryByEmail.docs.isNotEmpty) {
          final doc = queryByEmail.docs.first;
          final data = doc.data();
          final isActive = data['isActive'] as bool? ?? true;
          if (isActive) {
            // Auto-link UID if not yet set
            if (doc.id != user.uid && data['uid'] == null) {
              await doc.reference.update({'uid': user.uid});
            }
            final roleString = data['role'] as String?;
            return UserRole.fromString(roleString);
          } else {
            return UserRole.student;
          }
        }
      }

      // 3. Fallback to bootstrap default admin email
      if (email == adminEmail) {
        return UserRole.admin;
      }
    } catch (_) {
      // If offline or permission denied, fall back to email-based check for known emails
      if (email == founderEmail) return UserRole.founder;
      if (email == adminEmail) return UserRole.admin;
    }

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

    // Check if admin already exists
    final existing = await _adminsCollection
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('An administrator with this email already exists.');
    }

    await _adminsCollection.add({
      'email': cleanEmail,
      'name': name.trim(),
      'role': role == 'founder' ? 'founder' : 'admin',
      'isActive': true,
      'createdBy': currentUser?.uid,
      'creatorEmail': currentUser?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

    await _adminsCollection.doc(adminDocId).delete();
  }
}
