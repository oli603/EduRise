import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PracticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void> saveResult({
    required String subject,
    required String topic,
    required String question,
    required int selectedAnswer,
    required int correctAnswer,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }
    final isCorrect = selectedAnswer == correctAnswer;
    await _firestore.collection('practice_results').add({
      'userId': user.uid,
      'subject': subject,
      'topic': topic,
      'question': question,
      'selectedAnswer': selectedAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
