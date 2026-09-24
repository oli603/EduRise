import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_subjects.dart';
import '../../../core/offline/offline_storage_service.dart';
import '../../practice/data/local/question_store.dart';
import '../../practice/data/question_service.dart';
import '../../profile/data/profile_service.dart';
import 'challenge_model.dart';
import 'challenge_service.dart';

class ChallengeGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OfflineStorageService _storage = OfflineStorageService();
  final ProfileService _profileService;

  ChallengeGenerator({
    ProfileService? profileService,
  }) : _profileService = profileService ?? ProfileService();

  final ChallengeService _challengeService = ChallengeService();

  /// Generates one challenge based on the student's
  /// weakest recent unit or stream activity.
  Future<Challenge?> generateChallenge() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final userId = user.uid;

    // ------------------------------------------------------------
    // 0. GET STUDENT STREAM
    // ------------------------------------------------------------

    String studentStream = 'natural';
    try {
      final profile = await _profileService.getProfile(uid: userId);
      if (profile != null && profile.stream.isNotEmpty) {
        studentStream = EduRiseSubjects.isSocialStream(profile.stream) ? 'social' : 'natural';
      }
    } catch (e) {
      debugPrint('Error fetching student stream for challenge: $e');
    }

    final eligibleSubjects = EduRiseSubjects.getChallengeSubjects(stream: studentStream);

    // ------------------------------------------------------------
    // 1. GET RECENT PRACTICE RESULTS (REMOTE + LOCAL DEDUPED)
    // ------------------------------------------------------------

    try {
      final snapshot = await _firestore
          .collection('practice_results')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 4));
      final remoteResults = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      await _storage.cacheRemotePracticeResults(remoteResults);
    } catch (_) {}

    final localResults = await _storage.getLocalPracticeResults(userId: userId);

    final Map<String, Map<String, dynamic>> deduped = {};
    for (final r in localResults) {
      final key = (r['localId'] ?? r['id'] ?? '') as String;
      if (key.isNotEmpty) {
        deduped[key] = r;
      }
    }
    final allResults = deduped.values.toList();

    // ------------------------------------------------------------
    // 2. GROUP RESULTS BY GRADE + SUBJECT + UNIT (STREAM-FILTERED)
    // ------------------------------------------------------------

    final Map<String, List<Map<String, dynamic>>> groupedResults = {};

    for (final data in allResults) {
      final grade = data['grade'] as String? ?? '';
      final subject = data['subject'] as String? ?? '';
      final unitNumber = (data['unitNumber'] as num?)?.toInt() ?? 0;
      final unitName = data['unitName'] as String? ?? '';

      if (grade.isEmpty ||
          subject.isEmpty ||
          unitNumber <= 0 ||
          unitName.isEmpty ||
          !eligibleSubjects.contains(subject)) {
        continue;
      }

      final key = '$grade|$subject|$unitNumber|$unitName';

      groupedResults.putIfAbsent(key, () => []);
      groupedResults[key]!.add(data);
    }

    // ------------------------------------------------------------
    // 3. FIND TARGET UNIT:
    //    Tier 1: Weak units (accuracy < 70%, lowest first)
    //    Tier 2: Less-touched / untouched stream subjects
    //    Tier 3: Remaining practiced units or default subject
    // ------------------------------------------------------------

    String? selectedKey;

    // A. Check for critical weak units (accuracy < 70%)
    double weakestAccuracy = 0.70;
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
        selectedKey = entry.key;
      }
    }

    // B. If no critical weak unit, check for less-touched or untouched stream subjects
    if (selectedKey == null) {
      final Map<String, int> subjectActivity = {for (var s in eligibleSubjects) s: 0};
      for (final data in allResults) {
        final s = data['subject'] as String? ?? '';
        if (subjectActivity.containsKey(s)) {
          final qCount = (data['totalQuestions'] as num?)?.toInt() ?? 1;
          subjectActivity[s] = subjectActivity[s]! + qCount;
        }
      }

      // Sort subjects by least activity (0 questions first)
      final sortedSubjects = eligibleSubjects.toList()
        ..sort((a, b) => (subjectActivity[a] ?? 0).compareTo(subjectActivity[b] ?? 0));

      final leastTouchedSubject = sortedSubjects.first;

      // Check if we have local downloaded packages for this subject
      try {
        final practicePackages = await _storage.getPackagesByType('practice');
        for (final pkg in practicePackages) {
          if (pkg.subject.toLowerCase() == leastTouchedSubject.toLowerCase()) {
            final g = pkg.grade ?? 'Grade 12';
            final uNum = pkg.unitNumber ?? 1;
            final uName = (pkg.unitName != null && pkg.unitName!.isNotEmpty)
                ? pkg.unitName!
                : 'Unit $uNum';
            selectedKey = '$g|${pkg.subject}|$uNum|$uName';
            break;
          }
        }
      } catch (e) {
        debugPrint('Fallback local package check error: $e');
      }

      // If no package for least touched, check any other eligible downloaded package
      if (selectedKey == null) {
        try {
          final practicePackages = await _storage.getPackagesByType('practice');
          for (final pkg in practicePackages) {
            if (eligibleSubjects.contains(pkg.subject)) {
              final g = pkg.grade ?? 'Grade 12';
              final uNum = pkg.unitNumber ?? 1;
              final uName = (pkg.unitName != null && pkg.unitName!.isNotEmpty)
                  ? pkg.unitName!
                  : 'Unit $uNum';
              selectedKey = '$g|${pkg.subject}|$uNum|$uName';
              break;
            }
          }
        } catch (_) {}
      }

      // If still null, query remote published questions for this stream
      if (selectedKey == null) {
        try {
          final streamCandidates = studentStream == 'social'
              ? ['social', 'Social Science', 'Social', 'social science']
              : ['natural', 'Natural Science', 'Natural', 'natural science'];

          final qSnap = await _firestore
              .collection('questions')
              .where('status', isEqualTo: 'published')
              .where('stream', whereIn: streamCandidates)
              .limit(20)
              .get()
              .timeout(const Duration(seconds: 3));

          for (final doc in qSnap.docs) {
            final qData = doc.data();
            final s = qData['subject'] as String? ?? '';
            if (eligibleSubjects.contains(s)) {
              final g = qData['grade'] as String? ?? 'Grade 12';
              final uNum = (qData['unitNumber'] as num?)?.toInt() ?? 1;
              final uName = (qData['unitName'] as String?)?.isNotEmpty == true
                  ? qData['unitName'] as String
                  : 'Unit $uNum';
              selectedKey = '$g|$s|$uNum|$uName';
              break;
            }
          }
        } catch (e) {
          debugPrint('Fallback challenge question query error: $e');
        }
      }

      selectedKey ??= 'Grade 12|$leastTouchedSubject|1|Unit 1';
    }


    // ------------------------------------------------------------
    // 4. READ SELECTED UNIT INFORMATION
    // ------------------------------------------------------------

    final parts = selectedKey.split('|');
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
        return challenge;
      }
    }

    // ------------------------------------------------------------
    // 6. CREATE NEW CHALLENGE
    // ------------------------------------------------------------

    final questionService = QuestionService();
    final stream = studentStream;
    int availableQuestions = 0;

    // Check offline questions first
    try {
      final offlineQs = await QuestionStore().getOfflineQuestions(
        grade: grade,
        stream: stream,
        subject: subject,
        unitNumber: unitNumber,
      );
      availableQuestions = offlineQs.length;
    } catch (_) {}

    if (availableQuestions == 0) {
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
    }

    final targetCount = availableQuestions > 0
        ? (availableQuestions > 10 ? 10 : availableQuestions)
        : 10;

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
