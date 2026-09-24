import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_subjects.dart';
import 'local/book_local_store.dart';
import '../../admin/data/admin_service.dart';
import '../../admin/data/audit_service.dart';
import 'book_model.dart';

class BookService {
  final FirebaseFirestore? _customFirestore;

  BookService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  bool get _hasFirebase {
    if (kIsWeb == false && Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>> get _unitsCollection =>
      _firestore.collection('book_units');

  Future<void> addUnit(BookUnit unit) async {
    if (!_hasFirebase) return;
    final document = _unitsCollection.doc();

    await document.set({
      ...unit.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await AuditService.logAction(
      action: 'book_unit_added',
      targetType: 'book_unit',
      targetId: document.id,
      metadata: {
        'grade': unit.grade,
        'subject': unit.subject,
        'unitNumber': unit.unitNumber,
        'unitName': unit.unitName,
      },
    );
  }

  Future<List<BookUnit>> getUnits({
    required String grade,
    required String subject,
  }) async {
    if (_hasFirebase) {
      try {
        var snapshot = await _unitsCollection
            .where('grade', isEqualTo: grade)
            .where('subject', isEqualTo: subject)
            .get();

      if (snapshot.docs.isEmpty) {
        final altGrade = grade.startsWith('Grade ')
            ? grade.replaceFirst('Grade ', '').trim()
            : 'Grade $grade';
        snapshot = await _unitsCollection
            .where('grade', isEqualTo: altGrade)
            .where('subject', isEqualTo: subject)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        final allDocs = await _unitsCollection.limit(100).get();
        debugPrint('BookService: Found ${allDocs.docs.length} total units in Firestore');
        for (final doc in allDocs.docs) {
          debugPrint('BookUnit doc: grade=${doc.data()['grade']}, subject=${doc.data()['subject']}, unit=${doc.data()['unitNumber']} - ${doc.data()['unitName']}');
        }
        final matched = allDocs.docs.where((d) {
          final g = d.data()['grade']?.toString() ?? '';
          final s = d.data()['subject']?.toString() ?? '';
          final gMatch = g.toLowerCase() == grade.toLowerCase() ||
              g.replaceAll(RegExp(r'grade', caseSensitive: false), '').trim() ==
                  grade.replaceAll(RegExp(r'grade', caseSensitive: false), '').trim();
          final sMatch = s.toLowerCase() == subject.toLowerCase();
          return gMatch && sMatch;
        }).toList();

        if (matched.isNotEmpty) {
          final units = matched
              .map((document) => BookUnit.fromMap(document.id, document.data()))
              .toList();
          units.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
          return units;
        }
      } else {
        final units = snapshot.docs
            .map((document) => BookUnit.fromMap(document.id, document.data()))
            .toList();
        units.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
        return units;
      }
    } catch (e) {
      debugPrint('BookService.getUnits online query failed: $e, checking offline storage');
    }
    }

    // Offline fallback
    final offlineUnits = await BookLocalStore().getOfflineBookUnits(
      grade: grade,
      subject: subject,
    );
    if (offlineUnits.isNotEmpty) {
      return offlineUnits;
    }

    // Default seed units for Ethiopian New Curriculum subjects when database is fresh or offline
    final seedUnits = _getSeedUnits(grade: grade, subject: subject);
    if (seedUnits.isNotEmpty) {
      return seedUnits;
    }

    return [];
  }

  List<BookUnit> _getSeedUnits({required String grade, required String subject}) {
    final canonSubject = EduRiseSubjects.canonicalize(subject);
    final normGrade = grade.isNotEmpty ? (grade.startsWith('Grade ') ? grade : 'Grade $grade') : 'Grade 12';
    final gradePrefix = normGrade.replaceAll(RegExp(r'[^0-9]'), '');
    final gNum = gradePrefix.isNotEmpty ? gradePrefix : '12';

    if (canonSubject == EduRiseSubjects.economics) {
      return [
        BookUnit(
          id: 'econ_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.economics,
          unitNumber: 1,
          unitName: 'Fundamental Concepts of Macroeconomics',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'econ_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.economics,
          unitNumber: 2,
          unitName: 'Aggregate Demand and Aggregate Supply',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'econ_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.economics,
          unitNumber: 3,
          unitName: 'Market Structure and Pricing Theory',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'econ_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.economics,
          unitNumber: 4,
          unitName: 'Fiscal and Monetary Policy in Ethiopia',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    if (canonSubject == EduRiseSubjects.geography) {
      return [
        BookUnit(
          id: 'geo_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.geography,
          unitNumber: 1,
          unitName: 'Geographical Information and Map Reading',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'geo_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.geography,
          unitNumber: 2,
          unitName: 'Physical Environment of Ethiopia and the Horn',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'geo_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.geography,
          unitNumber: 3,
          unitName: 'Population and Settlement in Ethiopia',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'geo_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.geography,
          unitNumber: 4,
          unitName: 'Economic Activities and Natural Resources in Ethiopia',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    if (canonSubject == EduRiseSubjects.history) {
      return [
        BookUnit(
          id: 'hist_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.history,
          unitNumber: 1,
          unitName: 'State Formation and Nation Building in Ethiopia',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'hist_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.history,
          unitNumber: 2,
          unitName: 'Colonialism and Resistance in Africa',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'hist_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.history,
          unitNumber: 3,
          unitName: 'The Era of Modernization and Imperial Rule',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'hist_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.history,
          unitNumber: 4,
          unitName: 'Contemporary Ethiopian and World History',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    if (canonSubject == EduRiseSubjects.mathematics) {
      return [
        BookUnit(
          id: 'math_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.mathematics,
          unitNumber: 1,
          unitName: 'Sequences and Series',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'math_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.mathematics,
          unitNumber: 2,
          unitName: 'Introduction to Linear Programming',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'math_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.mathematics,
          unitNumber: 3,
          unitName: 'Matrices and Determinants',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'math_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.mathematics,
          unitNumber: 4,
          unitName: 'Applied Statistics and Probability',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    if (canonSubject == EduRiseSubjects.chemistry) {
      return [
        BookUnit(
          id: 'chem_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.chemistry,
          unitNumber: 1,
          unitName: 'Solutions and Colloidal Systems',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'chem_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.chemistry,
          unitNumber: 2,
          unitName: 'Chemical Kinetics and Equilibrium',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'chem_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.chemistry,
          unitNumber: 3,
          unitName: 'Electrochemistry and Industrial Chemistry',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'chem_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.chemistry,
          unitNumber: 4,
          unitName: 'Organic Chemistry and Polymers',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    if (canonSubject == EduRiseSubjects.physics) {
      return [
        BookUnit(
          id: 'phy_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.physics,
          unitNumber: 1,
          unitName: 'Thermodynamics',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'phy_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.physics,
          unitNumber: 2,
          unitName: 'Oscillations and Waves',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'phy_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.physics,
          unitNumber: 3,
          unitName: 'Electromagnetism',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'phy_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.physics,
          unitNumber: 4,
          unitName: 'Atomic and Nuclear Physics',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    if (canonSubject == EduRiseSubjects.biology) {
      return [
        BookUnit(
          id: 'bio_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.biology,
          unitNumber: 1,
          unitName: 'Application of Biology',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'bio_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.biology,
          unitNumber: 2,
          unitName: 'Ecology and Conservation',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'bio_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.biology,
          unitNumber: 3,
          unitName: 'Genetics and Evolution',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'bio_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.biology,
          unitNumber: 4,
          unitName: 'Microbiology & Diseases',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    if (canonSubject == EduRiseSubjects.english) {
      return [
        BookUnit(
          id: 'eng_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.english,
          unitNumber: 1,
          unitName: 'Advanced Reading and Textual Analysis',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'eng_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.english,
          unitNumber: 2,
          unitName: 'Grammar and Sentence Structure',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'eng_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.english,
          unitNumber: 3,
          unitName: 'Academic Writing and Composition',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'eng_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.english,
          unitNumber: 4,
          unitName: 'Vocabulary and Idiomatic Expression',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    if (canonSubject == EduRiseSubjects.satSubject) {
      return [
        BookUnit(
          id: 'sat_g${gNum}_u1',
          grade: normGrade,
          subject: EduRiseSubjects.satSubject,
          unitNumber: 1,
          unitName: 'Verbal Reasoning and Reading Comprehension',
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ),
        BookUnit(
          id: 'sat_g${gNum}_u2',
          grade: normGrade,
          subject: EduRiseSubjects.satSubject,
          unitNumber: 2,
          unitName: 'Quantitative Reasoning and Math Aptitude',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'sat_g${gNum}_u3',
          grade: normGrade,
          subject: EduRiseSubjects.satSubject,
          unitNumber: 3,
          unitName: 'Analytical Logic and Critical Thinking',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
        BookUnit(
          id: 'sat_g${gNum}_u4',
          grade: normGrade,
          subject: EduRiseSubjects.satSubject,
          unitNumber: 4,
          unitName: 'Data Interpretation and Problem Solving',
          pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
        ),
      ];
    }

    return [];
  }

  Future<List<BookUnit>> getAllUnits({
    String? grade,
    String? subject,
    int limit = 100,
  }) async {
    Query<Map<String, dynamic>> query = _unitsCollection.orderBy('createdAt', descending: true);

    if (grade != null && grade.isNotEmpty && grade != 'all') {
      query = query.where('grade', isEqualTo: grade);
    }

    if (subject != null && subject.isNotEmpty && subject != 'all') {
      query = query.where('subject', isEqualTo: subject);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((document) => BookUnit.fromMap(document.id, document.data()))
        .toList();
  }

  Future<int> getTotalUnitsCount() async {
    final snapshot = await _unitsCollection.count().get();
    return snapshot.count ?? 0;
  }

  Future<void> deleteUnit(String unitId) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    final doc = await _unitsCollection.doc(unitId).get();
    final data = doc.data() ?? {};

    await _unitsCollection.doc(unitId).delete();

    await AuditService.logAction(
      action: 'book_unit_deleted',
      targetType: 'book_unit',
      targetId: unitId,
      metadata: {
        'grade': data['grade'],
        'subject': data['subject'],
        'unitNumber': data['unitNumber'],
      },
    );
  }

  Future<BookUnit?> getUnitById(String unitId) async {
    final document = await _unitsCollection.doc(unitId).get();

    if (!document.exists) {
      return null;
    }

    return BookUnit.fromMap(document.id, document.data()!);
  }

  Future<bool> unitExists({
    required String grade,
    required String subject,
    required int unitNumber,
  }) async {
    final snapshot = await _unitsCollection
        .where('grade', isEqualTo: grade)
        .where('subject', isEqualTo: subject)
        .where('unitNumber', isEqualTo: unitNumber)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
