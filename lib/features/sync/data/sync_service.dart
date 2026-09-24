import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/offline/offline_storage_service.dart';
import '../../challenges/data/challenge_model.dart';
import '../../challenges/data/local/challenge_store.dart';
import '../../study_plan/data/local/study_task_store.dart';
import '../../study_plan/data/study_task_model.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  OfflineStorageService get _storage => OfflineStorageService();
  StudyTaskStore get _taskStore => StudyTaskStore();
  ChallengeStore get _challengeStore => ChallengeStore();

  bool _isSyncing = false;
  bool _hasPendingSync = false;

  /// Synchronize all offline changes with Firebase Firestore.
  /// Safe to call on app start, resume, network reconnection, or after local actions.
  Future<void> syncAll() async {
    if (_isSyncing) {
      _hasPendingSync = true;
      return;
    }
    final user = _auth.currentUser;
    if (user == null) return;

    _isSyncing = true;
    _hasPendingSync = false;
    try {
      await _syncPracticeResults(user.uid);
      await _syncPastExamResults(user.uid);
      await _syncStudyTasks(user.uid);
      await _syncChallenges(user.uid);
    } catch (e) {
      debugPrint('SyncService syncAll error: $e');
    } finally {
      _isSyncing = false;
      if (_hasPendingSync) {
        _hasPendingSync = false;
        syncAll();
      }
    }
  }

  Map<String, dynamic> _prepareDataForFirestore(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    if (data['scheduledDate'] is String) {
      final parsed = DateTime.tryParse(data['scheduledDate'] as String);
      if (parsed != null) {
        data['scheduledDate'] = Timestamp.fromDate(parsed);
      }
    }
    if (data['createdAt'] is String) {
      final parsed = DateTime.tryParse(data['createdAt'] as String);
      if (parsed != null) {
        data['createdAt'] = Timestamp.fromDate(parsed);
      }
    }
    return data;
  }

  // ============================================================
  // SYNC PAST EXAM RESULTS
  // ============================================================

  Future<void> _syncPastExamResults(String userId) async {
    final unsynced = await _storage.getUnsyncedPastExamResults();
    if (unsynced.isEmpty) return;

    final resultsCollection = _firestore.collection('past_exam_results');

    for (final result in unsynced) {
      try {
        final localId = (result['localId'] ?? result['id'])?.toString() ?? '';
        if (localId.isEmpty) continue;
        final docRef = resultsCollection.doc(localId);

        // Check if already uploaded
        final doc = await docRef.get().timeout(const Duration(seconds: 4));
        if (!doc.exists) {
          final dataToUpload = Map<String, dynamic>.from(result);
          dataToUpload.remove('isSynced');
          dataToUpload.remove('syncStatus');
          dataToUpload.remove('localId');

          if (dataToUpload['completedAt'] == null || dataToUpload['completedAt'] is! Timestamp) {
            dataToUpload['createdAt'] = FieldValue.serverTimestamp();
          }

          await docRef.set(dataToUpload, SetOptions(merge: true));
        }

        await _storage.markPastExamResultSynced(localId, serverId: docRef.id);
      } catch (e) {
        debugPrint('Error syncing past exam result: $e');
      }
    }
  }

  // ============================================================
  // SYNC PRACTICE RESULTS
  // ============================================================

  Future<void> _syncPracticeResults(String userId) async {
    final unsynced = await _storage.getUnsyncedPracticeResults();
    if (unsynced.isEmpty) return;

    final resultsCollection = _firestore.collection('practice_results');

    for (final result in unsynced) {
      try {
        final localId = (result['localId'] ?? result['id'])?.toString() ?? '';
        if (localId.isEmpty) continue;
        final docRef = resultsCollection.doc(localId);

        // Check if already uploaded
        final doc = await docRef.get().timeout(const Duration(seconds: 4));
        if (!doc.exists) {
          final dataToUpload = Map<String, dynamic>.from(result);
          dataToUpload.remove('isSynced');
          dataToUpload.remove('localId');

          // Ensure timestamps are valid FieldValue or Timestamps
          if (dataToUpload['timestamp'] == null || dataToUpload['timestamp'] is! Timestamp) {
            dataToUpload['timestamp'] = FieldValue.serverTimestamp();
          }
          if (dataToUpload['createdAt'] == null || dataToUpload['createdAt'] is! Timestamp) {
            dataToUpload['createdAt'] = FieldValue.serverTimestamp();
          }

          await docRef.set(dataToUpload);
        }

        await _storage.markPracticeResultSynced(localId, serverId: docRef.id);
      } catch (e) {
        debugPrint('Error syncing practice result: $e');
      }
    }
  }

  // ============================================================
  // SYNC STUDY TASKS
  // ============================================================

  Future<void> _syncStudyTasks(String userId) async {
    try {
      final pendingOps = await _taskStore.getPendingStudyTaskOps();
      final tasksCollection = _firestore.collection('study_tasks');

      for (final op in pendingOps) {
        try {
          final opId = op['opId'] as String;
          final type = op['type'] as String;
          final taskId = op['taskId'] as String;

          if (type == 'create') {
            final rawData = Map<String, dynamic>.from(op['data'] as Map);
            final data = _prepareDataForFirestore(rawData);
            await tasksCollection.doc(taskId).set(data, SetOptions(merge: true));
          } else if (type == 'update' || type == 'complete') {
            final rawData = Map<String, dynamic>.from(op['data'] as Map);
            final data = _prepareDataForFirestore(rawData);
            await tasksCollection.doc(taskId).update(data);
          } else if (type == 'delete') {
            await tasksCollection.doc(taskId).delete();
          }

          await _taskStore.clearPendingStudyTaskOp(opId);
        } catch (e) {
          debugPrint('Error processing pending study task op: $e');
        }
      }

      // Fetch remote tasks and sync local storage
      final snapshot = await tasksCollection
          .where('userId', isEqualTo: userId)
          .orderBy('scheduledDate')
          .get()
          .timeout(const Duration(seconds: 5));

      final remoteTasks = snapshot.docs
          .map((doc) => StudyTask.fromMap(doc.id, doc.data()))
          .toList();

      await _taskStore.syncStudyTasksFromRemote(remoteTasks);
    } catch (e) {
      debugPrint('Error syncing study tasks: $e');
    }
  }

  // ============================================================
  // SYNC CHALLENGES
  // ============================================================

  Future<void> _syncChallenges(String userId) async {
    try {
      final pendingOps = await _challengeStore.getPendingChallengeOps();
      final challengesCollection = _firestore.collection('challenges');

      for (final op in pendingOps) {
        try {
          final opId = op['opId'] as String;
          final type = op['type'] as String;
          final challengeId = op['challengeId'] as String;

          if (type == 'create') {
            final rawData = Map<String, dynamic>.from(op['data'] as Map);
            final data = _prepareDataForFirestore(rawData);
            await challengesCollection.doc(challengeId).set(data, SetOptions(merge: true));
          } else if (type == 'update' || type == 'update_progress' || type == 'complete') {
            final rawData = Map<String, dynamic>.from(op['data'] as Map);
            final data = _prepareDataForFirestore(rawData);
            await challengesCollection.doc(challengeId).update(data);
          } else if (type == 'delete') {
            await challengesCollection.doc(challengeId).delete();
          }

          await _challengeStore.clearPendingChallengeOp(opId);
        } catch (e) {
          debugPrint('Error processing pending challenge op: $e');
        }
      }

      // Fetch remote challenges and sync local storage
      final snapshot = await challengesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('scheduledDate')
          .get()
          .timeout(const Duration(seconds: 5));

      final remoteChallenges = snapshot.docs
          .map((doc) => Challenge.fromMap(doc.id, doc.data()))
          .toList();

      await _challengeStore.syncChallengesFromRemote(remoteChallenges);
    } catch (e) {
      debugPrint('Error syncing challenges: $e');
    }
  }
}
