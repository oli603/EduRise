import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _resultsCollection =>
      _firestore.collection('practice_results');

  /// Get all practice results belonging to the current user.
  Future<List<Map<String, dynamic>>> getUserResults() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final snapshot = await _resultsCollection
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((document) {
      return {'id': document.id, ...document.data()};
    }).toList();
  }

  /// Get total number of questions answered by the user.
  Future<int> getTotalQuestions() async {
    final results = await getUserResults();

    return results.length;
  }

  /// Get number of correctly answered questions.
  Future<int> getCorrectAnswers() async {
    final results = await getUserResults();

    return results.where((result) {
      return result['isCorrect'] == true;
    }).length;
  }

  /// Get number of incorrectly answered questions.
  Future<int> getIncorrectAnswers() async {
    final results = await getUserResults();

    return results.where((result) {
      return result['isCorrect'] == false;
    }).length;
  }

  /// Calculate overall accuracy percentage.
  Future<int> getAccuracy() async {
    final results = await getUserResults();

    if (results.isEmpty) {
      return 0;
    }

    final correctAnswers = results.where((result) {
      return result['isCorrect'] == true;
    }).length;

    return ((correctAnswers / results.length) * 100).round();
  }
}
