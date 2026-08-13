import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WeakArea {
  final String subject;
  final String topic;
  final int accuracy;
  final int totalQuestions;
  final int correctAnswers;

  const WeakArea({
    required this.subject,
    required this.topic,
    required this.accuracy,
    required this.totalQuestions,
    required this.correctAnswers,
  });
}

class WeakAreasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<WeakArea>> getWeakAreas() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final snapshot = await _firestore
        .collection('practice_results')
        .where('userId', isEqualTo: user.uid)
        .get();

    final Map<String, List<QueryDocumentSnapshot>> groupedResults = {};

    for (final document in snapshot.docs) {
      final data = document.data();

      final subject = data['subject'] as String? ?? 'Unknown';
      final topic = data['topic'] as String? ?? 'Unknown';

      final key = '$subject|$topic';

      groupedResults.putIfAbsent(key, () => []);

      groupedResults[key]!.add(document);
    }

    final List<WeakArea> weakAreas = [];

    for (final entry in groupedResults.entries) {
      final results = entry.value;

      final firstData = results.first.data() as Map<String, dynamic>;

      final subject = firstData['subject'] as String? ?? 'Unknown';

      final topic = firstData['topic'] as String? ?? 'Unknown';

      final totalQuestions = results.length;

      final correctAnswers = results.where((document) {
        final data = document.data() as Map<String, dynamic>;

        return data['isCorrect'] == true;
      }).length;

      final accuracy = ((correctAnswers / totalQuestions) * 100).round();

      weakAreas.add(
        WeakArea(
          subject: subject,
          topic: topic,
          accuracy: accuracy,
          totalQuestions: totalQuestions,
          correctAnswers: correctAnswers,
        ),
      );
    }

    weakAreas.sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return weakAreas;
  }
}
