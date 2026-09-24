import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'challenge_model.dart';
import 'local/challenge_store.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChallengeStore _storage = ChallengeStore();

  CollectionReference<Map<String, dynamic>> get _challengesCollection =>
      _firestore.collection('challenges');

  /// Create a new challenge.
  Future<String> addChallenge(Challenge challenge) async {
    final docId = challenge.id.isNotEmpty
        ? challenge.id
        : _challengesCollection.doc().id;

    final challengeWithMetadata = challenge.copyWith(
      id: docId,
      createdAt: challenge.createdAt ?? DateTime.now(),
    );

    // Save locally
    await _storage.saveChallengeLocally(challengeWithMetadata);

    // Try remote Firestore write
    try {
      await _challengesCollection.doc(docId).set({
        ...challengeWithMetadata.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('ChallengeService: offline, queuing pending challenge op: $e');
      await _storage.queuePendingChallengeOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_create_$docId',
        'type': 'create',
        'challengeId': docId,
        'data': challengeWithMetadata.toMap(),
      });
    }

    return docId;
  }

  /// Get all challenges belonging to a specific user.
  Future<List<Challenge>> getUserChallenges({required String userId}) async {
    // Try remote fetch and cache locally
    try {
      final snapshot = await _challengesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('scheduledDate')
          .get()
          .timeout(const Duration(seconds: 4));

      final remoteList = snapshot.docs
          .map((doc) => Challenge.fromMap(doc.id, doc.data()))
          .toList();

      await _storage.syncChallengesFromRemote(remoteList);
    } catch (e) {
      debugPrint('ChallengeService getUserChallenges offline/remote error: $e');
    }

    return _storage.getLocalChallenges(userId: userId);
  }

  /// Get challenges scheduled for a specific day.
  Future<List<Challenge>> getChallengesForDate({
    required String userId,
    required DateTime date,
  }) async {
    final allChallenges = await getUserChallenges(userId: userId);

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return allChallenges.where((challenge) {
      final sDate = challenge.scheduledDate;
      return !sDate.isBefore(startOfDay) && sDate.isBefore(endOfDay);
    }).toList();
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

    // Update locally
    await _storage.markChallengeProgressLocally(
      challengeId,
      isCompleted: completed,
    );

    // Try remote update
    try {
      await _challengesCollection.doc(challengeId).update({
        'currentCount': currentCount,
        'isCompleted': completed,
      }).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('ChallengeService updateProgress offline error: $e');
      await _storage.queuePendingChallengeOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_update_progress_$challengeId',
        'type': 'update',
        'challengeId': challengeId,
        'data': {
          'currentCount': currentCount,
          'isCompleted': completed,
        },
      });
    }
  }

  /// Mark a challenge as completed or incomplete.
  Future<void> setChallengeCompleted({
    required String challengeId,
    required bool completed,
  }) async {
    await _storage.markChallengeProgressLocally(
      challengeId,
      isCompleted: completed,
    );

    try {
      await _challengesCollection.doc(challengeId).update({
        'isCompleted': completed,
      }).timeout(const Duration(seconds: 4));
    } catch (e) {
      await _storage.queuePendingChallengeOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_complete_$challengeId',
        'type': 'update',
        'challengeId': challengeId,
        'data': {'isCompleted': completed},
      });
    }
  }

  /// Delete a challenge.
  Future<void> deleteChallenge(String challengeId) async {
    await _storage.deleteChallengeLocally(challengeId);

    try {
      await _challengesCollection.doc(challengeId).delete().timeout(const Duration(seconds: 4));
    } catch (e) {
      await _storage.queuePendingChallengeOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_delete_$challengeId',
        'type': 'delete',
        'challengeId': challengeId,
      });
    }
  }

  /// Get one challenge by its ID.
  Future<Challenge?> getChallengeById(String challengeId) async {
    await _storage.init();
    // Look up directly in storage
    final allUserChallenges = await _storage.getLocalChallenges(userId: '');

    for (final c in allUserChallenges) {
      if (c.id == challengeId) return c;
    }

    try {
      final document = await _challengesCollection.doc(challengeId).get().timeout(const Duration(seconds: 3));
      if (document.exists) {
        final ch = Challenge.fromMap(document.id, document.data()!);
        await _storage.saveChallengeLocally(ch);
        return ch;
      }
    } catch (_) {}

    return null;
  }

  /// Update the target questions count of a challenge.
  Future<void> updateTargetCount({
    required String challengeId,
    required int targetCount,
  }) async {
    if (challengeId.isEmpty) return;

    final challenge = await getChallengeById(challengeId);
    if (challenge != null) {
      final updated = challenge.copyWith(targetCount: targetCount);
      await _storage.saveChallengeLocally(updated);
    }

    try {
      await _challengesCollection.doc(challengeId).update({
        'targetCount': targetCount,
      }).timeout(const Duration(seconds: 4));
    } catch (e) {
      await _storage.queuePendingChallengeOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_target_count_$challengeId',
        'type': 'update',
        'challengeId': challengeId,
        'data': {'targetCount': targetCount},
      });
    }
  }

  /// Increase today's practice challenge progress by [count].
  Future<void> incrementPracticeChallenge({
    required String userId,
    required String subject,
    String? grade,
    int? unitNumber,
    int count = 1,
  }) async {
    final today = DateTime.now();
    final todayChallenges = await getChallengesForDate(
      userId: userId,
      date: today,
    );

    final matchingChallenges = todayChallenges.where((challenge) {
      final isPracticeChallenge = challenge.challengeType == 'practice';
      final sameSubject = challenge.subject.toLowerCase() == subject.toLowerCase();
      final sameGrade = grade == null || grade.isEmpty || challenge.grade.toLowerCase() == grade.toLowerCase();
      final sameUnit = unitNumber == null || unitNumber == 0 || challenge.unitNumber == unitNumber;
      final isCompleted = challenge.isCompleted;

      return isPracticeChallenge && sameSubject && sameGrade && sameUnit && !isCompleted;
    }).toList();

    final candidateChallenges = matchingChallenges.isNotEmpty
        ? matchingChallenges
        : todayChallenges.where((challenge) {
            final isPracticeChallenge = challenge.challengeType == 'practice';
            final sameSubject = challenge.subject.toLowerCase() == subject.toLowerCase();
            final isCompleted = challenge.isCompleted;
            return isPracticeChallenge && sameSubject && !isCompleted;
          }).toList();

    if (candidateChallenges.isEmpty) {
      return;
    }

    final challenge = candidateChallenges.first;
    final currentCount = challenge.currentCount;
    final targetCount = challenge.targetCount;

    final rawNewCount = currentCount + count;
    final newCount = targetCount > 0
        ? (rawNewCount > targetCount ? targetCount : rawNewCount)
        : rawNewCount;

    final completed = targetCount > 0 && newCount >= targetCount;

    await _storage.markChallengeProgressLocally(
      challenge.id,
      isCompleted: completed,
    );
    final updated = challenge.copyWith(
      currentCount: newCount,
      isCompleted: completed,
    );
    await _storage.saveChallengeLocally(updated);

    try {
      await _challengesCollection.doc(challenge.id).update({
        'currentCount': newCount,
        'isCompleted': completed,
      }).timeout(const Duration(seconds: 4));
    } catch (e) {
      await _storage.queuePendingChallengeOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_increment_${challenge.id}',
        'type': 'update',
        'challengeId': challenge.id,
        'data': {
          'currentCount': newCount,
          'isCompleted': completed,
        },
      });
    }
  }
}
