import 'package:cloud_firestore/cloud_firestore.dart';

import 'question_model.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _questionsCollection =>
      _firestore.collection('questions');

  Future<List<Question>> getQuestions({
    required String grade,
    required String subject,
    required int unitNumber,
  }) async {
    final snapshot = await _questionsCollection
        .where('grade', isEqualTo: grade)
        .where('subject', isEqualTo: subject)
        .where('unitNumber', isEqualTo: unitNumber)
        .get();

    return snapshot.docs
        .map((document) => Question.fromMap(document.id, document.data()))
        .toList();
  }

  Future<void> addQuestion(Question question) async {
    final document = _questionsCollection.doc();

    await document.set({
      ...question.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

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

  Future<Question?> getQuestionById(String questionId) async {
    final document = await _questionsCollection.doc(questionId).get();

    if (!document.exists) {
      return null;
    }

    return Question.fromMap(document.id, document.data()!);
  }
}
