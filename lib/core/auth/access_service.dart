import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../offline/connectivity_service.dart';
import '../offline/offline_storage_service.dart';
import 'role_service.dart';

class AccessService {
  static FirebaseAuth? _customAuth;
  static FirebaseFirestore? _customFirestore;
  static OfflineStorageService? _customStorage;
  static ConnectivityService? _customConnectivity;
  static String? _testRole;

  static void setMockInstances({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    OfflineStorageService? storage,
    ConnectivityService? connectivity,
  }) {
    _customAuth = auth;
    _customFirestore = firestore;
    _customStorage = storage;
    _customConnectivity = connectivity;
  }

  static void setTestRole(String? role) {
    _testRole = role;
  }

  static FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  static FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  static OfflineStorageService get _storage =>
      _customStorage ?? OfflineStorageService.instance;
  static ConnectivityService get _connectivity =>
      _customConnectivity ?? ConnectivityService();

  // ============================================================
  // CHECK IF USER HAS PAID ACCESS (OFFLINE-FIRST)
  // ============================================================

  static Future<bool> hasPaidAccess() async {
    if (_testRole != null) {
      return _testRole == 'paid' || _testRole == 'admin';
    }

    User? user;
    try {
      user = _auth.currentUser;
    } catch (_) {
      user = null;
    }

    if (user == null) {
      return false;
    }

    // Admins and founders always have full access to educational content
    final isAuthorizedAdmin = await RoleService.isCurrentAuthorizedAdmin();
    if (isAuthorizedAdmin) {
      return true;
    }

    // Fast path: If device is known to be offline, read local profile cache immediately
    if (_connectivity.isOffline) {
      return await _checkLocalCachedPaidAccess(user.uid);
    }

    // Online path: Read authoritative Firestore with timeout
    try {
      final doc = await _firestore
          .collection('students')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 4));

      if (!doc.exists || doc.data() == null) {
        return false;
      }

      final data = doc.data()!;
      final isPaid = data['isPaid'] as bool? ?? false;
      final accessStatus = data['accessStatus'] as String? ?? 'locked';
      final active = isPaid && accessStatus == 'active';

      // Keep local StudentProfileRecord in sync with authoritative server state
      try {
        final record = StudentProfileRecord.fromFirestore(user.uid, data);
        await _storage.saveStudentProfile(record);
      } catch (e) {
        debugPrint('AccessService: Error updating local profile cache: $e');
      }

      return active;
    } catch (_) {
      // Network error, socket failure, or timeout -> Fallback to local profile cache
      return await _checkLocalCachedPaidAccess(user.uid);
    }
  }

  static Future<bool> _checkLocalCachedPaidAccess(String currentUid) async {
    try {
      final cached = await _storage.getStudentProfile(currentUid);
      if (cached == null) {
        return false;
      }

      // Security check: strictly require UID match to prevent cross-account leaks
      if (cached.uid != currentUid) {
        return false;
      }

      return cached.isPaid && cached.accessStatus == 'active';
    } catch (e) {
      debugPrint('AccessService: Error reading cached profile: $e');
      return false;
    }
  }

  // ============================================================
  // FREE ACCESS POLICY EVALUATION
  // Allowed free test: Grade 12 + Unit 1 + 2017 EC + applicable subjects
  // All other units, grades, and entrance years require paid access.
  // ============================================================

  static bool isFreeAllowedPractice({
    required String grade,
    required int examYear,
    int? unitNumber,
  }) {
    final cleanGrade = grade.trim();
    final isGrade12 = cleanGrade == 'Grade 12' || cleanGrade == '12';
    final isYear2017 = examYear == 2017;
    final isUnit1 = unitNumber == 1;

    return isGrade12 && isYear2017 && isUnit1;
  }

  static Future<bool> canAccessPractice({
    required String grade,
    required int examYear,
    int? unitNumber,
  }) async {
    // Free students may test platform strictly with Grade 12, Unit 1, 2017 EC content
    if (isFreeAllowedPractice(
      grade: grade,
      examYear: examYear,
      unitNumber: unitNumber,
    )) {
      return true;
    }

    // Otherwise requires paid access
    return await hasPaidAccess();
  }

  static Future<bool> canAccessPastExams() async {
    // Past Entrance Exams are strictly locked for free students
    return await hasPaidAccess();
  }

  static Future<bool> canAccessChallenges() async {
    // Challenges require paid access
    return await hasPaidAccess();
  }

  // ============================================================
  // COACH ACCESS POLICY
  // Paid students have full access to EduRise Coach.
  // Free students have access to trial questions (Grade 12, Unit 1, 2017 EC).
  // ============================================================

  static Future<bool> canAccessCoach({
    String? grade,
    int? examYear,
    int? unitNumber,
  }) async {
    // Paid students have unrestricted Coach access
    if (await hasPaidAccess()) {
      return true;
    }

    // Free students can test Coach with allowed trial content
    if (grade != null && examYear != null) {
      return isFreeAllowedPractice(
        grade: grade,
        examYear: examYear,
        unitNumber: unitNumber,
      );
    }

    // Default: free tier users receive daily trial quotas handled by backend
    return false;
  }

  // ============================================================
  // STREAM CURRENT USER ACCESS STATUS
  // ============================================================

  static Stream<bool> streamAccess() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    if (RoleService.isAuthorizedAdmin) {
      return Stream.value(true);
    }

    return _firestore
        .collection('students')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return false;
      final data = snapshot.data()!;
      final isPaid = data['isPaid'] as bool? ?? false;
      final accessStatus = data['accessStatus'] as String? ?? 'locked';
      final active = isPaid && accessStatus == 'active';

      try {
        final record = StudentProfileRecord.fromFirestore(user.uid, data);
        _storage.saveStudentProfile(record);
      } catch (e) {
        debugPrint('AccessService: Error updating cached profile from stream: $e');
      }

      return active;
    });
  }
}
