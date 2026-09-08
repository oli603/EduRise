import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PracticeService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  PracticeService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _customFirestore = firestore,
        _customAuth = auth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

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
    int? examYear,
    required int totalQuestions,
    required int correctAnswers,
    required int wrongAnswers,
    required int score,
    List<String>? questionIds,
    List<String>? correctQuestionIds,
    List<Map<String, dynamic>>? questionResults,
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
      if (examYear != null && examYear > 0) 'examYear': examYear,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'score': score,
      'questionIds': questionIds ?? [],
      'correctQuestionIds': correctQuestionIds ?? [],
      'questionResults': questionResults ?? {},
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
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
        .get();

    final docs = snapshot.docs
        .map((document) => {'id': document.id, ...document.data()})
        .toList();

    docs.sort((a, b) {
      final tA = a['createdAt'] ?? a['timestamp'];
      final tB = b['createdAt'] ?? b['timestamp'];
      if (tA is Timestamp && tB is Timestamp) {
        return tB.compareTo(tA);
      }
      return 0;
    });

    return docs;
  }
}
