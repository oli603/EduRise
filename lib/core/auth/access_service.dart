import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/admin/data/admin_service.dart';

class AccessService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // CHECK IF USER HAS PAID ACCESS
  // ============================================================

  static Future<bool> hasPaidAccess() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    // Admins and founders always have full access to educational content
    final isAuthorizedAdmin = await AdminService.isCurrentAuthorizedAdmin();
    if (isAuthorizedAdmin) {
      return true;
    }

    try {
      final doc = await _firestore.collection('students').doc(user.uid).get();
      if (!doc.exists) {
        return false;
      }

      final data = doc.data();
      final isPaid = data?['isPaid'] as bool? ?? false;
      final accessStatus = data?['accessStatus'] as String? ?? 'locked';

      return isPaid || accessStatus == 'active';
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // FREE ACCESS POLICY EVALUATION
  // Allowed free test: Grade 12 + 2017 EC + all applicable subjects
  // All other grades and entrance years require paid access.
  // ============================================================

  static bool isFreeAllowedPractice({
    required String grade,
    required int examYear,
  }) {
    final cleanGrade = grade.trim();
    return cleanGrade == 'Grade 12' && examYear == 2017;
  }

  static Future<bool> canAccessPractice({
    required String grade,
    required int examYear,
  }) async {
    // Free students may test platform with Grade 12, 2017 EC content
    if (isFreeAllowedPractice(grade: grade, examYear: examYear)) {
      return true;
    }

    // Otherwise requires paid access
    return await hasPaidAccess();
  }

  static Future<bool> canAccessChallenges() async {
    // Challenges require paid access
    return await hasPaidAccess();
  }

  // ============================================================
  // STREAM CURRENT USER ACCESS STATUS
  // ============================================================

  static Stream<bool> streamAccess() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    if (AdminService.isAuthorizedAdmin) {
      return Stream.value(true);
    }

    return _firestore
        .collection('students')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data();
      final isPaid = data?['isPaid'] as bool? ?? false;
      final accessStatus = data?['accessStatus'] as String? ?? 'locked';
      return isPaid || accessStatus == 'active';
    });
  }
}
