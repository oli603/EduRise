import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/offline/offline_storage_service.dart';
import '../../practice/data/local/question_store.dart';

class WeakArea {
  final String subject;
  final String grade;
  final int unitNumber;
  final String unitName;
  final String? stream;
  final int accuracy;
  final int totalQuestions;
  final int correctAnswers;

  const WeakArea({
    required this.subject,
    required this.grade,
    required this.unitNumber,
    required this.unitName,
    this.stream,
    required this.accuracy,
    required this.totalQuestions,
    required this.correctAnswers,
  });

  /// Formatted presentation: "Grade 11 • Unit 3 Cell Biology"
  String get formattedUnitInfo {
    final gradePart = grade.isNotEmpty ? (grade.startsWith('Grade') ? grade : 'Grade $grade') : '';
    final unitPart = unitNumber > 0 ? 'Unit $unitNumber' : '';
    final namePart = unitName.isNotEmpty ? unitName : '';

    final parts = <String>[];
    if (gradePart.isNotEmpty) parts.add(gradePart);
    if (unitPart.isNotEmpty && namePart.isNotEmpty) {
      parts.add('$unitPart $namePart');
    } else if (unitPart.isNotEmpty) {
      parts.add(unitPart);
    } else if (namePart.isNotEmpty) {
      parts.add(namePart);
    }

    return parts.join(' • ');
  }

  /// Full title presentation: "Biology Grade 11 • Unit 3 Cell Biology"
  String get displayTitle {
    final gradePart = grade.isNotEmpty ? (grade.startsWith('Grade') ? grade : 'Grade $grade') : '';
    final subjectGrade = gradePart.isNotEmpty ? '$subject $gradePart' : subject;
    final unitPart = unitNumber > 0 ? 'Unit $unitNumber' : '';
    final namePart = unitName.isNotEmpty ? unitName : '';

    final unitInfo = (unitPart.isNotEmpty && namePart.isNotEmpty)
        ? '$unitPart $namePart'
        : (unitPart.isNotEmpty ? unitPart : namePart);

    if (unitInfo.isNotEmpty) {
      return '$subjectGrade • $unitInfo';
    }
    return subjectGrade;
  }

  /// Backward-compatible getter for legacy callers
  String get topic => formattedUnitInfo;
}

class WeakAreasService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final OfflineStorageService _storage = OfflineStorageService();

  WeakAreasService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  Future<List<WeakArea>> getWeakAreas() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final userId = user.uid;

    // 1. Fetch remote results if online, cache them locally
    try {
      final snapshot = await _firestore
          .collection('practice_results')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 4));

      final remoteResults = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      await _storage.cacheRemotePracticeResults(remoteResults);
    } catch (e) {
      debugPrint('WeakAreasService: offline or remote fetch error: $e');
    }

    // 2. Load all local practice results for user
    final localResults = await _storage.getLocalPracticeResults(userId: userId);

    // 3. Deduplicate results by localId / id
    final Map<String, Map<String, dynamic>> dedupedMap = {};
    for (final r in localResults) {
      final key = (r['localId'] ?? r['id'] ?? '') as String;
      if (key.isNotEmpty) {
        dedupedMap[key] = r;
      }
    }
    final allResults = dedupedMap.values.toList();

    // 4. Group strictly by grade + subject + unitNumber + unitName
    final Map<String, List<Map<String, dynamic>>> groupedResults = {};

    for (final data in allResults) {
      final subject = data['subject'] as String? ?? 'Unknown';
      final grade = data['grade'] as String? ?? '';
      final unitNumber = (data['unitNumber'] as num?)?.toInt() ??
          int.tryParse(data['unitNumber']?.toString() ?? '') ??
          0;
      final unitName = (data['unitName'] as String?) ??
          (data['topic'] as String?) ??
          '';

      if (subject.isEmpty || unitNumber <= 0) continue;

      final key = '$grade|$subject|$unitNumber|$unitName';
      groupedResults.putIfAbsent(key, () => []);
      groupedResults[key]!.add(data);
    }

    final List<WeakArea> weakAreas = [];

    for (final entry in groupedResults.entries) {
      final results = entry.value;

      // Sort chronological from oldest to newest
      results.sort((a, b) {
        final tA = a['timestamp'];
        final tB = b['timestamp'];
        DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
        if (tA is Timestamp) dateA = tA.toDate();
        if (tB is Timestamp) dateB = tB.toDate();
        if (tA is String) dateA = DateTime.tryParse(tA) ?? dateA;
        if (tB is String) dateB = DateTime.tryParse(tB) ?? dateB;
        return dateA.compareTo(dateB);
      });

      final firstData = results.first;

      final subject = firstData['subject'] as String? ?? 'Unknown';
      final grade = firstData['grade'] as String? ?? '';
      final unitNumber = (firstData['unitNumber'] as num?)?.toInt() ??
          int.tryParse(firstData['unitNumber']?.toString() ?? '') ??
          0;
      final unitName = (firstData['unitName'] as String?) ??
          (firstData['topic'] as String?) ??
          '';
      final stream = firstData['stream'] as String?;

      final List<String> allAttemptedIds = [];
      final Map<String, bool> uniqueQuestions = {};

      for (final data in results) {
        if (data['questionResults'] is Map) {
          final qr = data['questionResults'] as Map;
          qr.forEach((key, val) {
            final qId = key.toString();
            allAttemptedIds.add(qId);
            uniqueQuestions[qId] = val == true;
          });
        } else if (data['questionIds'] is List) {
          final qIds = (data['questionIds'] as List).map((e) => e.toString()).toList();
          final correctQIds = (data['correctQuestionIds'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              {};
          for (final qId in qIds) {
            allAttemptedIds.add(qId);
            uniqueQuestions[qId] = correctQIds.contains(qId);
          }
        } else if (data['questionId'] != null) {
          final qId = data['questionId'].toString();
          allAttemptedIds.add(qId);
          uniqueQuestions[qId] = data['isCorrect'] == true;
        }
      }

      int totalUnique = 0;
      int correctUnique = 0;
      int uniqueCount = 0;

      if (uniqueQuestions.isNotEmpty) {
        uniqueCount = uniqueQuestions.length;
        totalUnique = uniqueQuestions.length;
        correctUnique = uniqueQuestions.values.where((isCorrect) => isCorrect).length;
      } else {
        // Fallback: check offline questions stored locally first, then remote
        int knownQuestions = 0;
        try {
          final offlineQs = await QuestionStore().getOfflineQuestions(
            grade: grade,
            stream: stream ?? '',
            subject: subject,
            unitNumber: unitNumber,
          );
          knownQuestions = offlineQs.length;
        } catch (_) {}

        if (knownQuestions == 0) {
          try {
            var query = _firestore
                .collection('questions')
                .where('subject', isEqualTo: subject)
                .where('unitNumber', isEqualTo: unitNumber)
                .where('status', isEqualTo: 'published');
            if (grade.isNotEmpty) {
              query = query.where('grade', isEqualTo: grade);
            }
            final qSnap = await query.get().timeout(const Duration(seconds: 2));
            knownQuestions = qSnap.docs.length;
          } catch (_) {
            knownQuestions = 0;
          }
        }

        if (knownQuestions > 0) {
          totalUnique = knownQuestions;
          uniqueCount = knownQuestions;
          final lastData = results.last;
          final lastTotal = (lastData['totalQuestions'] as num?)?.toInt() ?? 1;
          final lastCorrect = (lastData['correctAnswers'] as num?)?.toInt() ??
              (lastData['isCorrect'] == true ? 1 : 0);
          if (knownQuestions == 1) {
            correctUnique = lastCorrect > 0 ? 1 : 0;
          } else {
            correctUnique = lastTotal > 0
                ? ((lastCorrect / lastTotal) * totalUnique).round()
                : 0;
          }
          if (correctUnique > totalUnique) correctUnique = totalUnique;
        } else {
          int maxSessionQ = 0;
          for (final data in results) {
            final tQ = (data['totalQuestions'] as num?)?.toInt() ?? 1;
            if (tQ > maxSessionQ) maxSessionQ = tQ;
          }
          totalUnique = maxSessionQ > 0 ? maxSessionQ : 1;
          uniqueCount = totalUnique;
          final lastData = results.last;
          final lastTotal = (lastData['totalQuestions'] as num?)?.toInt() ?? totalUnique;
          final lastCorrect = (lastData['correctAnswers'] as num?)?.toInt() ??
              (lastData['isCorrect'] == true ? 1 : 0);
          correctUnique = lastTotal > 0
              ? ((lastCorrect / lastTotal) * totalUnique).round()
              : 0;
          if (correctUnique > totalUnique) correctUnique = totalUnique;
        }
      }

      if (totalUnique == 0) continue;

      final accuracy = ((correctUnique / totalUnique) * 100).round();

      // Debug logs required by Part 9
      debugPrint('=== WEAK AREAS CALCULATION ===');
      debugPrint('Content group: $grade | $subject | Unit $unitNumber');
      debugPrint('Question IDs attempted: $allAttemptedIds');
      debugPrint('Unique questions attempted: $uniqueCount');
      debugPrint('Total unique questions: $totalUnique');
      debugPrint('Correct unique questions: $correctUnique');
      debugPrint('Accuracy: $accuracy%');
      debugPrint('==============================');


      weakAreas.add(
        WeakArea(
          subject: subject,
          grade: grade,
          unitNumber: unitNumber,
          unitName: unitName,
          stream: stream,
          accuracy: accuracy,
          totalQuestions: totalUnique,
          correctAnswers: correctUnique,
        ),
      );
    }

    // Sort with lowest accuracy first (weakest areas at the top)
    weakAreas.sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return weakAreas;
  }
}
