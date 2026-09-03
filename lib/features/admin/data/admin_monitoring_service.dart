import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_service.dart';

class AdminMonitoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _practiceCollection =>
      _firestore.collection('practice_results');

  CollectionReference<Map<String, dynamic>> get _studyTasksCollection =>
      _firestore.collection('study_tasks');

  // ============================================================
  // RECENT PRACTICE ATTEMPTS
  // ============================================================

  Future<List<Map<String, dynamic>>> getRecentPracticeAttempts({int limit = 50}) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    final snapshot = await _practiceCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // ============================================================
  // PRACTICE AGGREGATES & METRICS
  // ============================================================

  Future<Map<String, dynamic>> getPracticeAggregates({int sampleLimit = 100}) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    final snapshot = await _practiceCollection
        .orderBy('createdAt', descending: true)
        .limit(sampleLimit)
        .get();

    if (snapshot.docs.isEmpty) {
      return {
        'totalSessions': 0,
        'averageScore': 0,
        'totalQuestionsAnswered': 0,
        'subjectAccuracy': <String, double>{},
      };
    }

    int totalSessions = snapshot.docs.length;
    double scoreSum = 0;
    int totalQuestions = 0;
    int totalCorrect = 0;

    final Map<String, List<int>> subjectScores = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final score = (data['score'] as num?)?.toDouble() ?? 0;
      final qCount = (data['totalQuestions'] as int?) ?? 0;
      final correct = (data['correctAnswers'] as int?) ?? 0;
      final subject = data['subject'] as String? ?? 'General';

      scoreSum += score;
      totalQuestions += qCount;
      totalCorrect += correct;

      subjectScores.putIfAbsent(subject, () => []);
      subjectScores[subject]!.add(score.round());
    }

    final Map<String, double> subjectAverages = {};
    for (final entry in subjectScores.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      subjectAverages[entry.key] = double.parse(avg.toStringAsFixed(1));
    }

    return {
      'totalSessions': totalSessions,
      'averageScore': (scoreSum / totalSessions).round(),
      'totalQuestionsAnswered': totalQuestions,
      'overallAccuracy': totalQuestions > 0 ? ((totalCorrect / totalQuestions) * 100).round() : 0,
      'subjectAccuracy': subjectAverages,
    };
  }

  // ============================================================
  // STUDY PLAN AGGREGATES
  // ============================================================

  Future<Map<String, dynamic>> getStudyPlanAggregates({int sampleLimit = 100}) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    final snapshot = await _studyTasksCollection
        .orderBy('createdAt', descending: true)
        .limit(sampleLimit)
        .get();

    final totalTasks = snapshot.docs.length;
    final completedTasks =
        snapshot.docs.where((d) => d.data()['isCompleted'] == true).length;

    final completionRate =
        totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'completionRate': completionRate,
    };
  }
}
