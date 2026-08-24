import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    final resultsSnapshot = await _firestore
        .collection('practice_results')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    if (resultsSnapshot.docs.isEmpty) {
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

    if (groupedResults.isEmpty) {
      return null;
    }

    // ------------------------------------------------------------
    // 3. FIND WEAKEST UNIT
    // ------------------------------------------------------------

    String? weakestKey;
    double weakestAccuracy = 1.0;

    for (final entry in groupedResults.entries) {
      final results = entry.value;

      // We need at least 3 questions before deciding
      // that this is a weak area.
      if (results.length < 3) {
        continue;
      }

      final correctCount = results.where((result) {
        return result['isCorrect'] == true;
      }).length;

      final accuracy = correctCount / results.length;

      if (accuracy < weakestAccuracy) {
        weakestAccuracy = accuracy;
        weakestKey = entry.key;
      }
    }

    // We couldn't find enough data to determine
    // a weak unit.
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

      targetCount: 10,

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
