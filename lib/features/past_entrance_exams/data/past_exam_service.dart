import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'past_exam_model.dart';

class PastExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // STUDENT PROFILE
  // ============================================================

  Future<Map<String, String>> getStudentAcademicInfo() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final document = await _firestore
        .collection('students')
        .doc(user.uid)
        .get();

    if (!document.exists) {
      throw Exception('Student profile not found.');
    }

    final data = document.data();

    if (data == null) {
      throw Exception('Student profile data is empty.');
    }

    final grade = data['grade'] as String? ?? '';
    final stream = data['stream'] as String? ?? '';

    if (grade.isEmpty || stream.isEmpty) {
      throw Exception('Student grade or stream is missing.');
    }

    return {'grade': grade, 'stream': stream};
  }

  // ============================================================
  // PAST EXAMS COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _pastExams =>
      _firestore.collection('past_exams');

  // ============================================================
  // ADMIN — SAVE COMPLETE EXAM
  // ============================================================

  Future<void> savePastExam(PastExam exam) async {
    await _pastExams.doc(exam.id).set({
      ...exam.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // GET ONE EXAM
  // ============================================================

  Future<PastExam?> getPastExam(String examId) async {
    final document = await _pastExams.doc(examId).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return PastExam.fromMap(document.id, data);
  }

  // ============================================================
  // GET EXAMS FOR A YEAR + STREAM
  // ============================================================

  Future<List<PastExam>> getPastExams({
    required String year,
    required String stream,
  }) async {
    final snapshot = await _pastExams
        .where('year', isEqualTo: year)
        .where('stream', isEqualTo: stream)
        .get();

    return snapshot.docs
        .map((document) => PastExam.fromMap(document.id, document.data()))
        .toList();
  }
}
