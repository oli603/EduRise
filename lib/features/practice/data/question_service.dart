import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'question_model.dart';

class QuestionService {
  final FirebaseFirestore? _customFirestore;

  QuestionService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _questionsCollection =>
      _firestore.collection('questions');

  // ============================================================
  // GET PUBLISHED QUESTIONS
  // ============================================================

  Future<List<Question>> getQuestions({
    required String grade,
    required String stream,
    required String subject,
    required int unitNumber,
    int? examYear,
  }) async {
    final effectiveStream = normalizeStream(stream, subject: subject);
    final normalizedGrade = _normalizeGrade(grade);
    final rawNum = _rawGradeNum(grade);
    final streamVariants = _streamCandidates(effectiveStream, subject: subject);

    QuerySnapshot<Map<String, dynamic>>? snapshot;

    // 1. Try normalized grade with stream variants
    for (final s in streamVariants) {
      try {
        Query<Map<String, dynamic>> query = _questionsCollection
            .where('grade', isEqualTo: normalizedGrade)
            .where('stream', isEqualTo: s)
            .where('subject', isEqualTo: subject)
            .where('status', isEqualTo: 'published');

        if (unitNumber > 0) {
          query = query.where('unitNumber', isEqualTo: unitNumber);
        }

        if (examYear != null && examYear > 0) {
          query = query.where('examYear', isEqualTo: examYear);
        }

        final snap = await query.get();
        if (snap.docs.isNotEmpty) {
          snapshot = snap;
          break;
        }
      } catch (e) {
        debugPrint('PRACTICE getQuestions query error for stream=$s: $e');
      }
    }

    // 2. Secondary fallback: if grade was saved as raw digit (e.g. '11' instead of 'Grade 11')
    if ((snapshot == null || snapshot.docs.isEmpty) && rawNum != normalizedGrade) {
      for (final s in streamVariants) {
        try {
          Query<Map<String, dynamic>> query = _questionsCollection
              .where('grade', isEqualTo: rawNum)
              .where('stream', isEqualTo: s)
              .where('subject', isEqualTo: subject)
              .where('status', isEqualTo: 'published');

          if (unitNumber > 0) {
            query = query.where('unitNumber', isEqualTo: unitNumber);
          }

          if (examYear != null && examYear > 0) {
            query = query.where('examYear', isEqualTo: examYear);
          }

          final snap = await query.get();
          if (snap.docs.isNotEmpty) {
            snapshot = snap;
            break;
          }
        } catch (e) {
          debugPrint('PRACTICE getQuestions raw digit query error for stream=$s: $e');
        }
      }
    }

    final seenIds = <String>{};
    final questions = (snapshot?.docs ?? [])
        .map((document) => Question.fromMap(document.id, document.data()))
        .where((q) {
          if (!seenIds.add(q.id)) return false;
          // Strict in-memory validation to guarantee 100% data integrity:
          if (_normalizeGrade(q.grade) != normalizedGrade) return false;
          if (q.subject.toLowerCase() != subject.toLowerCase()) return false;
          if (unitNumber > 0 && q.unitNumber != unitNumber) return false;
          if (examYear != null && examYear > 0 && q.examYear != examYear) return false;
          if (q.status.toLowerCase() != 'published') return false;
          return true;
        })
        .toList();

    questions.sort((a, b) => a.questionNumber.compareTo(b.questionNumber));

    // Structured retrieval logging
    // ignore: avoid_print
    print('''
PRACTICE QUESTIONS RETRIEVAL DEBUG
------------------------------
selectedStream: $effectiveStream
selectedGrade: $normalizedGrade
selectedSubject: $subject
selectedUnit: $unitNumber
selectedYear: $examYear

Question query executed
Returned questions: ${questions.length}
Returned questions count: ${questions.length}
''');

    return questions;
  }

  // ============================================================
  // GET AVAILABLE GRADES
  // ============================================================

  Future<List<String>> getAvailableGrades({required String stream}) async {
    return const ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];
  }

  // ============================================================
  // GET AVAILABLE UNITS
  // ============================================================

  Future<List<Map<String, dynamic>>> getAvailableUnits({
    required String grade,
    required String stream,
    required String subject,
  }) async {
    final effectiveStream = normalizeStream(stream, subject: subject);
    final normalizedGrade = _normalizeGrade(grade);
    final rawNum = _rawGradeNum(grade);
    final streamVariants = _streamCandidates(effectiveStream, subject: subject);

    QuerySnapshot<Map<String, dynamic>>? snapshot;

    // Try primary combinations: normalized grade with stream variants
    for (final s in streamVariants) {
      try {
        final snap = await _questionsCollection
            .where('grade', isEqualTo: normalizedGrade)
            .where('stream', isEqualTo: s)
            .where('subject', isEqualTo: subject)
            .where('status', isEqualTo: 'published')
            .get();

        if (snap.docs.isNotEmpty) {
          snapshot = snap;
          break;
        }
      } catch (e) {
        debugPrint('PRACTICE getAvailableUnits query error for stream=$s: $e');
      }
    }

    // If still empty and rawNum != normalizedGrade, try numeric grade
    if ((snapshot == null || snapshot.docs.isEmpty) && rawNum != normalizedGrade) {
      for (final s in streamVariants) {
        try {
          final snap = await _questionsCollection
              .where('grade', isEqualTo: rawNum)
              .where('stream', isEqualTo: s)
              .where('subject', isEqualTo: subject)
              .where('status', isEqualTo: 'published')
              .get();

          if (snap.docs.isNotEmpty) {
            snapshot = snap;
            break;
          }
        } catch (e) {
          debugPrint('PRACTICE getAvailableUnits raw digit query error for stream=$s: $e');
        }
      }
    }

    final Map<int, String> units = {};

    if (snapshot != null) {
      for (final document in snapshot.docs) {
        final data = document.data();

        final unitNumber = (data['unitNumber'] as num?)?.toInt() ??
            int.tryParse(data['unitNumber']?.toString() ?? '') ??
            (data['unit_number'] as num?)?.toInt() ??
            int.tryParse(data['unit_number']?.toString() ?? '') ??
            0;
        final unitName = (data['unitName'] as String?) ??
            (data['unit_name'] as String?) ??
            '';

        if (unitNumber > 0) {
          if (!units.containsKey(unitNumber) ||
              (units[unitNumber]!.isEmpty && unitName.isNotEmpty)) {
            units[unitNumber] = unitName;
          }
        }
      }
    }

    final result = units.entries.map((entry) {
      return {'number': entry.key, 'name': entry.value};
    }).toList();

    result.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));

    // Structured debug print matching exact specification in Section 4
    final buffer = StringBuffer();
    buffer.writeln('PRACTICE DEBUG');
    buffer.writeln('------------------------------');
    buffer.writeln('selectedStream: $effectiveStream');
    buffer.writeln('selectedGrade: $normalizedGrade');
    buffer.writeln('selectedSubject: $subject');
    buffer.writeln('');
    buffer.writeln('Query collection: questions');
    buffer.writeln('');
    buffer.writeln('Returned documents: ${snapshot?.docs.length ?? 0}');

    if (snapshot != null && snapshot.docs.isNotEmpty) {
      for (final document in snapshot.docs) {
        final d = document.data();
        buffer.writeln('');
        buffer.writeln('Question:');
        buffer.writeln('grade = ${d['grade']}');
        buffer.writeln('subject = ${d['subject']}');
        buffer.writeln('stream = ${d['stream']}');
        buffer.writeln('unitNumber = ${d['unitNumber'] ?? d['unit_number']}');
        buffer.writeln('unitName = ${d['unitName'] ?? d['unit_name']}');
        buffer.writeln('status = ${d['status']}');
        buffer.writeln('examYear = ${d['examYear'] ?? d['year']}');
      }
    }

    buffer.writeln('');
    buffer.writeln('Available units:');
    if (result.isEmpty) {
      buffer.writeln('None');
    } else {
      for (final u in result) {
        buffer.writeln('${u['number']} - ${u['name']}');
      }
    }

    // ignore: avoid_print
    print(buffer.toString());

    return result;
  }

  static String _normalizeGrade(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return clean;
    final num = int.tryParse(clean.replaceAll(RegExp(r'[^0-9]'), ''));
    if (num != null && num >= 9 && num <= 12) {
      return 'Grade $num';
    }
    return clean;
  }

  static String _rawGradeNum(String input) {
    final num = int.tryParse(input.replaceAll(RegExp(r'[^0-9]'), ''));
    return num != null ? '$num' : input;
  }

  /// Canonical EduRise stream normalizer:
  /// Always returns either 'natural' or 'social'.
  static String normalizeStream(String? rawStream, {String? subject}) {
    final s = (rawStream ?? '').trim().toLowerCase();
    if (s.contains('social')) return 'social';
    if (s.contains('natural')) return 'natural';

    if (subject != null) {
      final sub = subject.trim().toLowerCase();
      if (sub == 'economics' || sub == 'geography' || sub == 'history') {
        return 'social';
      }
    }
    return 'natural';
  }

  static List<String> _streamCandidates(String stream, {String? subject}) {
    final canonical = normalizeStream(stream, subject: subject);
    if (canonical == 'natural') {
      return ['natural', 'Natural Science', 'Natural', 'natural science'];
    } else {
      return ['social', 'Social Science', 'Social', 'social science'];
    }
  }



  // ============================================================
  // ADD ONE QUESTION
  // ============================================================

  Future<String> addQuestion(Question question) async {
    final document = _questionsCollection.doc();

    await document.set({
      ...question.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  // ============================================================
  // ADD MULTIPLE QUESTIONS
  //
  // Kept for future use.
  // Our new admin workflow will normally save one question
  // when the admin presses "Add Question".
  // ============================================================

  Future<void> addQuestions(List<Question> questions) async {
    final batch = _firestore.batch();

    for (final question in questions) {
      final document = _questionsCollection.doc();

      batch.set(document, {
        ...question.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ============================================================
  // GET QUESTION BY ID
  // ============================================================

  Future<Question?> getQuestionById(String questionId) async {
    final document = await _questionsCollection.doc(questionId).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return Question.fromMap(document.id, data);
  }
}
