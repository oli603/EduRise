import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/offline/offline_storage_service.dart';

class ProgressService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final OfflineStorageService _storage = OfflineStorageService();

  ProgressService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _resultsCollection =>
      _firestore.collection('practice_results');

  CollectionReference<Map<String, dynamic>> get _pastExamResultsCollection =>
      _firestore.collection('past_exam_results');

  /// Stream practice and past exam results for the current user in real-time.
  Stream<List<Map<String, dynamic>>> getUserResultsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    // 1. Emit local results immediately
    Future<void> emitLocal() async {
      try {
        final localResults = await _getAggregatedLocalResults(user.uid);
        if (!controller.isClosed) {
          controller.add(localResults);
        }
      } catch (e) {
        debugPrint('ProgressService emitLocal error: $e');
      }
    }

    emitLocal();

    // 2. Listen to Firestore practice results if possible
    StreamSubscription? practiceSub;
    StreamSubscription? examSub;

    try {
      practiceSub = _resultsCollection
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) async {
        final remotePractice = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        await _storage.cacheRemotePracticeResults(remotePractice);
        final aggregated = await _getAggregatedLocalResults(user.uid);
        if (!controller.isClosed) {
          controller.add(aggregated);
        }
      }, onError: (e) {
        debugPrint('ProgressService practice snapshot error: $e');
      });

      examSub = _pastExamResultsCollection
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) async {
        final remoteExams = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        await _storage.cacheRemotePastExamResults(remoteExams);
        final aggregated = await _getAggregatedLocalResults(user.uid);
        if (!controller.isClosed) {
          controller.add(aggregated);
        }
      }, onError: (e) {
        debugPrint('ProgressService exam snapshot error: $e');
      });
    } catch (e) {
      debugPrint('ProgressService Firestore listener setup error: $e');
    }

    controller.onCancel = () {
      practiceSub?.cancel();
      examSub?.cancel();
    };

    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> _getAggregatedLocalResults(String userId) async {
    final localPractice = await _storage.getLocalPracticeResults(userId: userId);
    final localExams = await _storage.getLocalPastExamResults(userId: userId);

    final Map<String, Map<String, dynamic>> deduped = {};

    for (final p in localPractice) {
      final key = (p['localId'] ?? p['id'] ?? '') as String;
      if (key.isNotEmpty) {
        deduped[key] = p;
      }
    }

    for (final e in localExams) {
      final key = (e['localId'] ?? e['id'] ?? '') as String;
      if (key.isNotEmpty) {
        deduped[key] = e;
      }
    }

    final list = deduped.values.toList();
    list.sort((a, b) {
      final tA = a['timestamp'] ?? a['completedAt'] ?? a['createdAt'];
      final tB = b['timestamp'] ?? b['completedAt'] ?? b['createdAt'];
      DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
      if (tA is Timestamp) dateA = tA.toDate();
      if (tB is Timestamp) dateB = tB.toDate();
      if (tA is String) dateA = DateTime.tryParse(tA) ?? dateA;
      if (tB is String) dateB = DateTime.tryParse(tB) ?? dateB;
      return dateB.compareTo(dateA); // descending
    });

    return list;
  }

  /// Get all practice and past exam results belonging to the current user.
  Future<List<Map<String, dynamic>>> getUserResults() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final userId = user.uid;

    // Fetch remote results if available
    try {
      final practiceSnap = await _resultsCollection
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 4));
      final remotePractice = practiceSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      await _storage.cacheRemotePracticeResults(remotePractice);
    } catch (_) {}

    try {
      final examSnap = await _pastExamResultsCollection
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 4));
      final remoteExams = examSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      await _storage.cacheRemotePastExamResults(remoteExams);
    } catch (_) {}

    return _getAggregatedLocalResults(userId);
  }

  /// Get total number of questions answered across all sessions.
  Future<int> getTotalQuestions() async {
    final results = await getUserResults();
    int total = 0;
    for (final r in results) {
      total += (r['totalQuestions'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  /// Get number of correctly answered questions across all sessions.
  Future<int> getCorrectAnswers() async {
    final results = await getUserResults();
    int correct = 0;
    for (final r in results) {
      correct += (r['correctAnswers'] as num?)?.toInt() ?? 0;
    }
    return correct;
  }

  /// Get number of incorrectly answered questions across all sessions.
  Future<int> getIncorrectAnswers() async {
    final results = await getUserResults();
    int incorrect = 0;
    for (final r in results) {
      final wrong = (r['wrongAnswers'] as num?)?.toInt();
      if (wrong != null) {
        incorrect += wrong;
      } else {
        final total = (r['totalQuestions'] as num?)?.toInt() ?? 0;
        final corr = (r['correctAnswers'] as num?)?.toInt() ?? 0;
        incorrect += (total - corr).clamp(0, total);
      }
    }
    return incorrect;
  }

  /// Calculate overall accuracy percentage.
  Future<int> getAccuracy() async {
    final total = await getTotalQuestions();
    if (total == 0) return 0;
    final correct = await getCorrectAnswers();
    return ((correct / total) * 100).round();
  }
}
