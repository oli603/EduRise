import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PracticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // PRACTICE RESULTS COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _resultsCollection =>
      _firestore.collection('practice_results');

  // ============================================================
  // SAVE ONE QUESTION RESULT
  // ============================================================

  Future<void> saveResult({
    required String grade,
    required String stream,
    required String subject,
    required int unitNumber,
    required String unitName,
    required int totalQuestions,
    required int correctAnswers,
    required int wrongAnswers,
    required int score,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    await _resultsCollection.add({
      'userId': user.uid,
      'grade': grade,
      'stream': stream,
      'subject': subject,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'score': score,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // GET CURRENT STUDENT RESULTS
  // ============================================================

  Future<List<Map<String, dynamic>>> getMyResults() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final snapshot = await _resultsCollection
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((document) => {'id': document.id, ...document.data()})
        .toList();
  }
}
