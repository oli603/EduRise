import 'package:cloud_firestore/cloud_firestore.dart';

import 'question_model.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  }) async {
    final snapshot = await _questionsCollection
        .where('grade', isEqualTo: grade)
        .where('stream', isEqualTo: stream)
        .where('subject', isEqualTo: subject)
        .where('unitNumber', isEqualTo: unitNumber)
        .where('status', isEqualTo: 'published')
        .orderBy('questionNumber')
        .get();

    return snapshot.docs
        .map((document) => Question.fromMap(document.id, document.data()))
        .toList();
  }

  // ============================================================
  // GET AVAILABLE GRADES
  // ============================================================

  Future<List<String>> getAvailableGrades({required String stream}) async {
    final snapshot = await _questionsCollection
        .where('stream', isEqualTo: stream)
        .where('status', isEqualTo: 'published')
        .get();

    final grades = <String>{};
    for (final document in snapshot.docs) {
      final grade = document.data()['grade'] as String?;
      if (grade != null && grade.isNotEmpty) {
        grades.add(grade);
      }
    }

    final result = grades.toList()..sort();
    return result;
  }

  // ============================================================
  // GET AVAILABLE UNITS
  // ============================================================

  Future<List<Map<String, dynamic>>> getAvailableUnits({
    required String grade,
    required String stream,
    required String subject,
  }) async {
    final snapshot = await _questionsCollection
        .where('grade', isEqualTo: grade)
        .where('stream', isEqualTo: stream)
        .where('subject', isEqualTo: subject)
        .where('status', isEqualTo: 'published')
        .get();

    final Map<int, String> units = {};

    for (final document in snapshot.docs) {
      final data = document.data();

      final unitNumber = data['unitNumber'] as int? ?? 0;
      final unitName = data['unitName'] as String? ?? '';

      if (unitNumber > 0 && unitName.isNotEmpty) {
        units[unitNumber] = unitName;
      }
    }

    final result = units.entries.map((entry) {
      return {'number': entry.key, 'name': entry.value};
    }).toList();

    result.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));

    return result;
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
