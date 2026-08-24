import 'package:cloud_firestore/cloud_firestore.dart';

class PastExamQuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> addQuestion({
    required String year,
    required String stream,
    required String? round,
    required String subject,
    required String duration,
    required int questionNumber,
    required String questionText,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctAnswer,
    required String explanation,
    String? imageUrl,
  }) async {
    final document = await _firestore.collection('past_exam_questions').add({
      'year': year,
      'stream': stream,
      'round': round,
      'subject': subject,
      'duration': duration,

      'questionNumber': questionNumber,

      'questionText': questionText,

      'options': {'A': optionA, 'B': optionB, 'C': optionC, 'D': optionD},

      'correctAnswer': correctAnswer,

      'explanation': explanation,

      'imageUrl': imageUrl,

      'createdAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }
}
