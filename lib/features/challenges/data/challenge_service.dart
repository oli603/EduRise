import 'package:cloud_firestore/cloud_firestore.dart';

import 'challenge_model.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _challengesCollection =>
      _firestore.collection('challenges');

  /// Create a new challenge.
  Future<String> addChallenge(Challenge challenge) async {
    final document = _challengesCollection.doc();

    final challengeWithMetadata = challenge.copyWith(
      id: document.id,
      createdAt: DateTime.now(),
    );

    await document.set({
      ...challengeWithMetadata.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  /// Get all challenges belonging to a specific user.
  Future<List<Challenge>> getUserChallenges({required String userId}) async {
    final snapshot = await _challengesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledDate')
        .get();

    return snapshot.docs
        .map((document) => Challenge.fromMap(document.id, document.data()))
        .toList();
  }

  /// Get challenges scheduled for a specific day.
  Future<List<Challenge>> getChallengesForDate({
    required String userId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);

    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _challengesCollection
        .where('userId', isEqualTo: userId)
        .where(
          'scheduledDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('scheduledDate')
        .get();

    return snapshot.docs
        .map((document) => Challenge.fromMap(document.id, document.data()))
        .toList();
  }

  /// Update the current progress of a challenge.
  Future<void> updateProgress({
    required String challengeId,
    required int currentCount,
  }) async {
    final challenge = await getChallengeById(challengeId);

    if (challenge == null) {
      throw Exception('Challenge not found.');
    }

    final completed = currentCount >= challenge.targetCount;

    await _challengesCollection.doc(challengeId).update({
      'currentCount': currentCount,
      'isCompleted': completed,
    });
  }

  /// Mark a challenge as completed or incomplete.
  Future<void> setChallengeCompleted({
    required String challengeId,
    required bool completed,
  }) async {
    await _challengesCollection.doc(challengeId).update({
      'isCompleted': completed,
    });
  }

  /// Delete a challenge.
  Future<void> deleteChallenge(String challengeId) async {
    await _challengesCollection.doc(challengeId).delete();
  }

  /// Get one challenge by its ID.
  Future<Challenge?> getChallengeById(String challengeId) async {
    final document = await _challengesCollection.doc(challengeId).get();

    if (!document.exists) {
      return null;
    }

    return Challenge.fromMap(document.id, document.data()!);
  }

  /// Increase today's practice challenge progress by 1.
  Future<void> incrementPracticeChallenge({
    required String userId,
    required String subject,
  }) async {
    final today = DateTime.now();

    final startOfDay = DateTime(today.year, today.month, today.day);

    final endOfDay = startOfDay.add(const Duration(days: 1));

    // We only use userId in the Firestore query.
    // The remaining filtering happens in Dart.
    // This helps us avoid creating another composite index.
    final snapshot = await _challengesCollection
        .where('userId', isEqualTo: userId)
        .get();

    final matchingChallenges = snapshot.docs.where((document) {
      final data = document.data();

      final challengeSubject = data['subject'] as String? ?? '';

      final challengeType = data['challengeType'] as String? ?? '';

      final scheduledDate = Challenge.fromMap(document.id, data).scheduledDate;

      final isToday =
          !scheduledDate.isBefore(startOfDay) &&
          scheduledDate.isBefore(endOfDay);

      final isPracticeChallenge = challengeType == 'practice';

      final sameSubject = challengeSubject == subject;

      final isCompleted = data['isCompleted'] as bool? ?? false;

      return isToday && isPracticeChallenge && sameSubject && !isCompleted;
    }).toList();

    if (matchingChallenges.isEmpty) {
      return;
    }

    // For now, update the first matching challenge.
    final document = matchingChallenges.first;

    final data = document.data();

    final currentCount = data['currentCount'] as int? ?? 0;

    final targetCount = data['targetCount'] as int? ?? 0;

    final newCount = currentCount + 1;

    final completed = targetCount > 0 && newCount >= targetCount;

    await document.reference.update({
      'currentCount': newCount,
      'isCompleted': completed,
    });
  }
}
