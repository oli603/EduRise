import 'package:cloud_firestore/cloud_firestore.dart';

import '../../practice/data/models/question_package_model.dart';

class QuestionPackageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _packagesCollection =>
      _firestore.collection('question_packages');

  // ============================================================
  // CREATE DRAFT PACKAGE
  // ============================================================

  Future<String> createDraftPackage({
    required String grade,
    required String stream,
    required String subject,
    required int unitNumber,
    required String unitName,
    required String examType,
    int? examYear,
  }) async {
    final document = _packagesCollection.doc();

    final package = QuestionPackage(
      packageId: document.id,
      title: '$grade - $subject - $unitName',
      grade: grade,
      stream: stream,
      subject: subject,
      unitNumber: unitNumber,
      unitName: unitName,
      examType: examType,
      examYear: examYear,
      version: 1,
      questionCount: 0,
      status: 'draft',
      createdAt: null,
    );

    await document.set({
      ...package.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  // ============================================================
  // GET ALL PACKAGES
  // ============================================================

  Future<List<QuestionPackage>> getPackages() async {
    final snapshot = await _packagesCollection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (document) => QuestionPackage.fromMap(document.id, document.data()),
        )
        .toList();
  }

  // ============================================================
  // GET PACKAGE BY ID
  // ============================================================

  Future<QuestionPackage?> getPackageById(String packageId) async {
    final document = await _packagesCollection.doc(packageId).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return QuestionPackage.fromMap(document.id, data);
  }

  // ============================================================
  // GET ASSIGNED QUESTION IDS
  // ============================================================

  Future<Set<String>> getAssignedQuestionIds(String packageId) async {
    final snapshot = await _packagesCollection
        .doc(packageId)
        .collection('questions')
        .get();

    return snapshot.docs.map((document) => document.id).toSet();
  }

  // ============================================================
  // SAVE QUESTION ASSIGNMENTS
  // ============================================================

  Future<void> saveQuestionAssignments({
    required String packageId,
    required Set<String> selectedQuestionIds,
    required Set<String> previouslyAssignedQuestionIds,
  }) async {
    final packageQuestions = _packagesCollection
        .doc(packageId)
        .collection('questions');

    final batch = _firestore.batch();

    // ----------------------------------------------------------
    // REMOVE QUESTIONS THAT ARE NO LONGER SELECTED
    // ----------------------------------------------------------

    final removedQuestionIds = previouslyAssignedQuestionIds.difference(
      selectedQuestionIds,
    );

    for (final questionId in removedQuestionIds) {
      batch.delete(packageQuestions.doc(questionId));
    }

    // ----------------------------------------------------------
    // ADD NEWLY SELECTED QUESTIONS
    // ----------------------------------------------------------

    final newQuestionIds = selectedQuestionIds.difference(
      previouslyAssignedQuestionIds,
    );

    for (final questionId in newQuestionIds) {
      batch.set(packageQuestions.doc(questionId), {
        'questionId': questionId,
        'assignedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // ----------------------------------------------------------
    // UPDATE PACKAGE QUESTION COUNT
    // ----------------------------------------------------------

    await _packagesCollection.doc(packageId).update({
      'questionCount': selectedQuestionIds.length,
    });
  }
}
