import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/constants/app_grades.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/offline/offline_storage_service.dart';

/// Single source of truth for student profile data operations in EduRise.
///
/// Responsibilities:
/// - Profile creation (onboarding)
/// - Profile reads (unified offline-aware boundary)
/// - Profile updates (name, grade)
/// - Stream immutability enforcement
/// - Local profile cache synchronization
///
/// Does NOT own:
/// - Role resolution (owned by RoleService)
/// - Access entitlement decisions (owned by AccessService)
/// - Payment processing / approvals (owned by PaymentService / PaymentAdminService)
/// - Identity & device session management (owned by AuthService)
/// - FCM token lifecycle (owned by NotificationService)
class ProfileService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final OfflineStorageService? _customStorage;

  ProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    OfflineStorageService? storage,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _customStorage = storage;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  OfflineStorageService get _storage => _customStorage ?? OfflineStorageService();
  OfflineStorageService get storage => _storage;

  // ============================================================
  // UNIFIED OFFLINE-AWARE PROFILE RETRIEVAL BOUNDARY
  // ============================================================

  /// Retrieves the student's profile using an offline-aware policy.
  ///
  /// - When [forceRefresh] is false (default):
  ///   Immediately returns the valid local cached profile if present (0 network calls).
  ///   If no valid local cache exists, attempts remote Firestore fetch, caches result, and returns it.
  /// - When [forceRefresh] is true:
  ///   Fetches from Firestore first, updates the local cache, and returns the latest record.
  ///   Falls back to local cache if network/Firestore is unavailable.
  Future<StudentProfileRecord?> getProfile({
    String? uid,
    bool forceRefresh = false,
  }) async {
    String? targetUid = uid;
    if (targetUid == null || targetUid.isEmpty) {
      try {
        targetUid = _auth.currentUser?.uid;
      } catch (_) {
        targetUid = null;
      }
    }
    if (targetUid == null || targetUid.isEmpty) {
      targetUid = SessionManager.currentUid;
    }
    if (targetUid == null || targetUid.isEmpty) {
      return null;
    }

    SessionManager.startSession(targetUid);
    final capturedEpoch = SessionManager.sessionEpoch;

    // 1. Fast offline-first check from local cache
    if (!forceRefresh) {
      try {
        final cached = await _storage.getStudentProfile(targetUid);
        if (cached != null &&
            cached.uid == targetUid &&
            cached.name.isNotEmpty &&
            cached.grade.isNotEmpty &&
            cached.stream.isNotEmpty) {
          if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch)) {
            return null;
          }
          return cached;
        }
      } catch (e) {
        debugPrint('ProfileService: Error reading local profile cache: $e');
      }
    }

    // 2. Remote fetch attempt
    try {
      final doc = await _firestore
          .collection('students')
          .doc(targetUid)
          .get()
          .timeout(const Duration(seconds: 4));

      if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch)) {
        return null;
      }

      if (doc.exists && doc.data() != null) {
        final record = StudentProfileRecord.fromFirestore(targetUid, doc.data()!);
        try {
          await _storage.saveStudentProfile(record);
        } catch (e) {
          debugPrint('ProfileService: Error updating profile cache: $e');
        }
        return record;
      }
      return null;
    } catch (e) {
      debugPrint('ProfileService: Remote profile fetch failed: $e. Falling back to cache.');
      if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch)) {
        return null;
      }
      // Offline fallback
      try {
        final cached = await _storage.getStudentProfile(targetUid);
        if (cached != null && cached.uid == targetUid) {
          return cached;
        }
        return null;
      } catch (_) {
        return null;
      }
    }
  }

  /// Retrieves the cached profile record directly from local storage.
  ///
  /// Fast synchronous-like local read without any network/Firestore calls.
  Future<StudentProfileRecord?> getCachedProfile({String? uid}) async {
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) return null;
    final cached = await _storage.getStudentProfile(targetUid);
    if (cached != null && cached.uid == targetUid) {
      return cached;
    }
    return null;
  }

  // ============================================================
  // CHECK IF PROFILE EXISTS
  // ============================================================

  Future<bool> profileExists({String? uid}) async {
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) {
      return false;
    }

    // 1. Fast local cache check
    try {
      final cached = await _storage.getStudentProfile(targetUid);
      if (cached != null &&
          cached.name.isNotEmpty &&
          cached.grade.isNotEmpty &&
          cached.stream.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    // 2. Authoritative remote check
    try {
      final document = await _firestore
          .collection('students')
          .doc(targetUid)
          .get()
          .timeout(const Duration(seconds: 4));

      if (document.exists && document.data() != null) {
        try {
          final record = StudentProfileRecord.fromFirestore(targetUid, document.data()!);
          await _storage.saveStudentProfile(record);
        } catch (e) {
          debugPrint('ProfileService: Error caching profile in profileExists: $e');
        }
      }

      return document.exists;
    } catch (_) {
      // If remote check fails (offline), rely on local cache
      final cached = await _storage.getStudentProfile(targetUid);
      return cached != null && cached.name.isNotEmpty;
    }
  }

  // ============================================================
  // STREAM CURRENT STUDENT PROFILE (TYPED)
  // ============================================================

  /// Returns a real-time stream of the student's profile as a typed [StudentProfileRecord].
  ///
  /// Synchronizes every received snapshot into the local offline storage cache.
  Stream<StudentProfileRecord?>? getProfileStream({String? uid}) {
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) return null;

    return _firestore
        .collection('students')
        .doc(targetUid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        try {
          final record = StudentProfileRecord.fromFirestore(targetUid, snapshot.data()!);
          _storage.saveStudentProfile(record);
          return record;
        } catch (e) {
          debugPrint('ProfileService: Error caching student profile from stream: $e');
          return null;
        }
      }
      return null;
    });
  }

  // ============================================================
  // GET PROFILE DATA (BACKWARD COMPATIBLE)
  // ============================================================

  Future<Map<String, dynamic>?> getProfileData({String? uid}) async {
    final profile = await getProfile(uid: uid);
    return profile?.toMap();
  }

  // ============================================================
  // SAVE PROFILE (ONBOARDING)
  // ============================================================

  Future<void> saveProfile({
    required String name,
    required String grade,
    required String stream,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final canonicalStream = EduRiseSubjects.canonicalizeStream(stream);
    final canonicalGrade = EduRiseGrades.canonicalize(grade);

    // Verify if profile already has an immutable stream registered
    final docRef = _firestore.collection('students').doc(user.uid);
    try {
      final existingDoc = await docRef.get().timeout(const Duration(seconds: 4));
      if (existingDoc.exists) {
        final existingData = existingDoc.data();
        final existingStream = existingData?['stream'] as String?;
        if (existingStream != null && existingStream.isNotEmpty) {
          final existingCanonical = EduRiseSubjects.canonicalizeStream(existingStream);
          if (existingCanonical != canonicalStream) {
            final displayStreamName = EduRiseSubjects.displayStream(existingCanonical);
            throw Exception(
              'Your account is registered for $displayStreamName. You cannot change your stream.',
            );
          }
        }
      }
    } catch (e) {
      // If network error, rethrow any stream mismatch if found in cache
      final cached = await _storage.getStudentProfile(user.uid);
      if (cached != null && cached.stream.isNotEmpty) {
        final cachedCanonical = EduRiseSubjects.canonicalizeStream(cached.stream);
        if (cachedCanonical != canonicalStream) {
          final displayStreamName = EduRiseSubjects.displayStream(cachedCanonical);
          throw Exception(
            'Your account is registered for $displayStreamName. You cannot change your stream.',
          );
        }
      }
    }

    await docRef.set({
      'name': name.trim(),
      'email': user.email,
      'grade': canonicalGrade,
      'stream': canonicalStream,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Cache updated profile locally after successful write
    try {
      final updatedDoc = await docRef.get().timeout(const Duration(seconds: 4));
      if (updatedDoc.exists && updatedDoc.data() != null) {
        final record = StudentProfileRecord.fromFirestore(user.uid, updatedDoc.data()!);
        await _storage.saveStudentProfile(record);
      } else {
        final record = StudentProfileRecord(
          uid: user.uid,
          name: name.trim(),
          email: user.email,
          grade: canonicalGrade,
          stream: canonicalStream,
          isPaid: false,
          accessStatus: 'locked',
          createdAt: DateTime.now(),
          cachedAt: DateTime.now(),
        );
        await _storage.saveStudentProfile(record);
      }
    } catch (e) {
      final record = StudentProfileRecord(
        uid: user.uid,
        name: name.trim(),
        email: user.email,
        grade: canonicalGrade,
        stream: canonicalStream,
        isPaid: false,
        accessStatus: 'locked',
        createdAt: DateTime.now(),
        cachedAt: DateTime.now(),
      );
      await _storage.saveStudentProfile(record);
    }
  }

  // ============================================================
  // UPDATE PERSONAL INFORMATION
  // ============================================================

  Future<void> updatePersonalInfo({
    required String name,
    String? stream,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    // Stream is locked after onboarding and must not be modified by normal updates.
    await _firestore.collection('students').doc(user.uid).update({
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      final cached = await _storage.getStudentProfile(user.uid);
      if (cached != null) {
        final updated = cached.copyWith(
          name: name.trim(),
          updatedAt: DateTime.now(),
          cachedAt: DateTime.now(),
        );
        await _storage.saveStudentProfile(updated);
      }
    } catch (e) {
      debugPrint('ProfileService: Error updating cached profile in updatePersonalInfo: $e');
    }
  }

  // ============================================================
  // UPDATE GRADE
  // ============================================================

  Future<void> updateGrade({required String grade}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    final canonicalGrade = EduRiseGrades.canonicalize(grade);

    await _firestore.collection('students').doc(user.uid).update({
      'grade': canonicalGrade,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      final cached = await _storage.getStudentProfile(user.uid);
      if (cached != null) {
        final updated = cached.copyWith(
          grade: canonicalGrade,
          updatedAt: DateTime.now(),
          cachedAt: DateTime.now(),
        );
        await _storage.saveStudentProfile(updated);
      }
    } catch (e) {
      debugPrint('ProfileService: Error updating cached profile in updateGrade: $e');
    }
  }
}
