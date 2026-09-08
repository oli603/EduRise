import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../practice/data/question_service.dart';
import 'challenge_model.dart';
import 'challenge_service.dart';

class ChallengeGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ChallengeService _challengeService = ChallengeService();

  /// Generates one challenge based on the student's
  /// weakest recent unit.
  Future<Challenge?> generateChallenge() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final userId = user.uid;

    // ------------------------------------------------------------
    // 1. GET RECENT PRACTICE RESULTS
    // ------------------------------------------------------------

    QuerySnapshot<Map<String, dynamic>> resultsSnapshot;
    try {
      resultsSnapshot = await _firestore
          .collection('practice_results')
          .where('userId', isEqualTo: userId)
          .get();
    } catch (e) {
      return null;
    }

    // ------------------------------------------------------------
    // 2. GROUP RESULTS BY GRADE + SUBJECT + UNIT
    // ------------------------------------------------------------

    final Map<String, List<Map<String, dynamic>>> groupedResults = {};

    for (final document in resultsSnapshot.docs) {
      final data = document.data();

      final grade = data['grade'] as String? ?? '';
      final subject = data['subject'] as String? ?? '';
      final unitNumber = (data['unitNumber'] as num?)?.toInt() ?? 0;
      final unitName = data['unitName'] as String? ?? '';

      if (grade.isEmpty ||
          subject.isEmpty ||
          unitNumber <= 0 ||
          unitName.isEmpty) {
        continue;
      }

      final key = '$grade|$subject|$unitNumber|$unitName';

      groupedResults.putIfAbsent(key, () => []);
      groupedResults[key]!.add(data);
    }

    // ------------------------------------------------------------
    // 3. FIND WEAKEST UNIT
    // ------------------------------------------------------------

    String? weakestKey;
    double weakestAccuracy = 1.0;

    for (final entry in groupedResults.entries) {
      final results = entry.value;

      int totalQ = 0;
      int correctA = 0;
      for (final r in results) {
        totalQ += (r['totalQuestions'] as num?)?.toInt() ?? 0;
        correctA += (r['correctAnswers'] as num?)?.toInt() ?? 0;
      }
      if (totalQ == 0) continue;

      final accuracy = correctA / totalQ;

      if (accuracy < weakestAccuracy) {
        weakestAccuracy = accuracy;
        weakestKey = entry.key;
      }
    }

    // If student has no weak unit history, find first available published question
    if (weakestKey == null) {
      try {
        final qSnap = await _firestore
            .collection('questions')
            .where('status', isEqualTo: 'published')
            .limit(1)
            .get();

        if (qSnap.docs.isNotEmpty) {
          final qData = qSnap.docs.first.data();
          final g = qData['grade'] as String? ?? 'Grade 11';
          final s = qData['subject'] as String? ?? 'Biology';
          final uNum = (qData['unitNumber'] as num?)?.toInt() ?? 1;
          final uName = (qData['unitName'] as String?)?.isNotEmpty == true
              ? qData['unitName'] as String
              : 'Unit $uNum';
          weakestKey = '$g|$s|$uNum|$uName';
        }
      } catch (_) {}
    }

    if (weakestKey == null) {
      return null;
    }

    // ------------------------------------------------------------
    // 4. READ WEAK UNIT INFORMATION
    // ------------------------------------------------------------

    final parts = weakestKey.split('|');

    final grade = parts[0];
    final subject = parts[1];
    final unitNumber = int.parse(parts[2]);
    final unitName = parts[3];

    // ------------------------------------------------------------
    // 5. DON'T CREATE DUPLICATE ACTIVE CHALLENGES
    // ------------------------------------------------------------

    final today = DateTime.now();

    final todayChallenges = await _challengeService.getChallengesForDate(
      userId: userId,
      date: today,
    );

    for (final challenge in todayChallenges) {
      if (!challenge.isCompleted &&
          challenge.grade == grade &&
          challenge.subject == subject &&
          challenge.unitNumber == unitNumber &&
          challenge.unitName == unitName) {
        // The student already has a challenge
        // for this exact unit today.
        return challenge;
      }
    }

    // ------------------------------------------------------------
    // 6. CREATE NEW CHALLENGE
    // ------------------------------------------------------------

    final questionService = QuestionService();
    final stream = QuestionService.normalizeStream(null, subject: subject);
    int availableQuestions = 0;
    try {
      final questions = await questionService.getQuestions(
        grade: grade,
        stream: stream,
        subject: subject,
        unitNumber: unitNumber,
      );
      availableQuestions = questions.length;
    } catch (e) {
      debugPrint('Error counting published questions for challenge: $e');
    }

    final targetCount = availableQuestions > 0
        ? (availableQuestions > 10 ? 10 : availableQuestions)
        : 1;

    debugPrint('Challenge available questions: $availableQuestions');
    debugPrint('Challenge questions loaded: $targetCount');
    debugPrint('Current index: 0');
    debugPrint('Total questions: $targetCount');

    final challenge = Challenge(
      id: '',
      userId: userId,

      title: 'Master Unit $unitNumber: $unitName',

      description:
          'Practice $unitName questions and improve your $subject performance.',

      challengeType: 'practice',

      grade: grade,

      subject: subject,

      unitNumber: unitNumber,

      unitName: unitName,

      targetCount: targetCount,

      currentCount: 0,

      scheduledDate: DateTime(today.year, today.month, today.day),

      isCompleted: false,

      rewardXp: 100,

      createdAt: null,
    );

    // ------------------------------------------------------------
    // 7. SAVE CHALLENGE
    // ------------------------------------------------------------

    final challengeId = await _challengeService.addChallenge(challenge);

    return challenge.copyWith(id: challengeId);
  }
}
