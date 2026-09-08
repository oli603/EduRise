import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ProgressService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _resultsCollection =>
      _firestore.collection('practice_results');

  /// Stream practice results for the current user in real-time.
  Stream<List<Map<String, dynamic>>> getUserResultsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _resultsCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((document) {
        return {'id': document.id, ...document.data()};
      }).toList();

      list.sort((a, b) {
        final tA = a['timestamp'];
        final tB = b['timestamp'];
        DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
        if (tA is Timestamp) dateA = tA.toDate();
        if (tB is Timestamp) dateB = tB.toDate();
        return dateB.compareTo(dateA); // descending
      });

      return list;
    });
  }

  /// Get all practice results belonging to the current user.
  Future<List<Map<String, dynamic>>> getUserResults() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final snapshot = await _resultsCollection
        .where('userId', isEqualTo: user.uid)
        .get();

    final results = snapshot.docs.map((document) {
      return {'id': document.id, ...document.data()};
    }).toList();

    // Sort in memory to avoid Firestore composite index requirement
    results.sort((a, b) {
      final tA = a['timestamp'];
      final tB = b['timestamp'];
      DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
      if (tA is Timestamp) dateA = tA.toDate();
      if (tB is Timestamp) dateB = tB.toDate();
      return dateB.compareTo(dateA);
    });

    return results;
  }

  /// Get total number of questions answered across all sessions.
  Future<int> getTotalQuestions() async {
    final results = await getUserResults();
    int total = 0;
    for (final r in results) {
      total += (r['totalQuestions'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  /// Get number of correctly answered questions across all sessions.
  Future<int> getCorrectAnswers() async {
    final results = await getUserResults();
    int correct = 0;
    for (final r in results) {
      correct += (r['correctAnswers'] as num?)?.toInt() ?? 0;
    }
    return correct;
  }

  /// Get number of incorrectly answered questions across all sessions.
  Future<int> getIncorrectAnswers() async {
    final results = await getUserResults();
    int incorrect = 0;
    for (final r in results) {
      final wrong = (r['wrongAnswers'] as num?)?.toInt();
      if (wrong != null) {
        incorrect += wrong;
      } else {
        final total = (r['totalQuestions'] as num?)?.toInt() ?? 0;
        final corr = (r['correctAnswers'] as num?)?.toInt() ?? 0;
        incorrect += (total - corr).clamp(0, total);
      }
    }
    return incorrect;
  }

  /// Calculate overall accuracy percentage.
  Future<int> getAccuracy() async {
    final total = await getTotalQuestions();
    if (total == 0) return 0;
    final correct = await getCorrectAnswers();
    return ((correct / total) * 100).round();
  }
}
