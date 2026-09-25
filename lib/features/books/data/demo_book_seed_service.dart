import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_subjects.dart';
import 'book_model.dart';

/// Service responsible for managing repeatable, idempotent demo book content
/// across Grades 9, 10, and 11 for all supported Ethiopian New Curriculum subjects.
class DemoBookSeedService {
  final FirebaseFirestore? _customFirestore;

  DemoBookSeedService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

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

  /// Idempotently seed demo books for Grades 9, 10, and 11 in Firestore.
  /// Uses deterministic document IDs (`demo_g{grade}_{subject}_{unit}`)
  /// so calling this repeatedly will never duplicate content.
  Future<int> seedDemoBooks({bool force = false}) async {
    if (!_hasFirebase) {
      return getAllDemoUnits().length;
    }

    final allDemoUnits = getAllDemoUnits();
    int seededCount = 0;

    // Use Firestore batched writes (max 500 operations per batch)
    final chunks = <List<BookUnit>>[];
    for (int i = 0; i < allDemoUnits.length; i += 400) {
      chunks.add(allDemoUnits.sublist(
        i,
        i + 400 > allDemoUnits.length ? allDemoUnits.length : i + 400,
      ));
    }

    for (final chunk in chunks) {
      final batch = _firestore.batch();
      for (final unit in chunk) {
        final docRef = _unitsCollection.doc(unit.id);
        batch.set(
          docRef,
          {
            ...unit.toMap(),
            'isDemo': true,
            'seededAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        seededCount++;
      }
      await batch.commit();
    }

    return seededCount;
  }

  /// Remove all seeded demo books from Firestore without touching production units.
  Future<int> removeDemoBooks() async {
    if (!_hasFirebase) return 0;

    final snapshot = await _unitsCollection
        .where('isDemo', isEqualTo: true)
        .get();

    int removedCount = 0;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      removedCount++;
    }
    if (removedCount > 0) {
      await batch.commit();
    }

    // Also catch any units created with the demo_ ID prefix
    final allDocs = await _unitsCollection.get();
    final demoPrefixDocs = allDocs.docs.where((d) => d.id.startsWith('demo_'));
    if (demoPrefixDocs.isNotEmpty) {
      final prefixBatch = _firestore.batch();
      for (final doc in demoPrefixDocs) {
        prefixBatch.delete(doc.reference);
        removedCount++;
      }
      await prefixBatch.commit();
    }

    return removedCount;
  }

  /// Get demo units for a specific grade and subject.
  static List<BookUnit> getDemoUnits({
    required String grade,
    required String subject,
  }) {
    final canonSubject = EduRiseSubjects.canonicalize(subject);
    final normGrade = grade.isNotEmpty
        ? (grade.startsWith('Grade ') ? grade : 'Grade $grade')
        : 'Grade 9';
    final gradeNum = normGrade.replaceAll(RegExp(r'[^0-9]'), '');

    return getAllDemoUnits().where((u) {
      final uGradeNum = u.grade.replaceAll(RegExp(r'[^0-9]'), '');
      final uCanonSubject = EduRiseSubjects.canonicalize(u.subject);
      return uGradeNum == gradeNum && uCanonSubject == canonSubject;
    }).toList();
  }

  /// Returns the complete registry of curriculum-accurate demo units for Grades 9, 10, and 11.
  static List<BookUnit> getAllDemoUnits() {
    final list = <BookUnit>[];

    // =========================================================================
    // GRADE 9 DEMO BOOKS (Ethiopian New Curriculum Foundation)
    // =========================================================================
    const g9 = 'Grade 9';

    // Mathematics Grade 9
    list.addAll(_createUnits(
      grade: g9,
      subject: EduRiseSubjects.mathematics,
      slug: 'math',
      units: [
        (1, 'Further on Sets & Venn Diagrams'),
        (2, 'The Real Number System & Radical Expressions'),
        (3, 'Linear Equations and Inequalities in One Variable'),
        (4, 'Introduction to Trigonometry & Ratios'),
      ],
    ));

    // Physics Grade 9
    list.addAll(_createUnits(
      grade: g9,
      subject: EduRiseSubjects.physics,
      slug: 'physics',
      units: [
        (1, 'Physical Quantities and Vector Analysis'),
        (2, 'Uniform Motion in a Straight Line'),
        (3, 'Newton’s Laws of Motion & Friction'),
        (4, 'Work, Energy, and Simple Machines'),
      ],
    ));

    // Chemistry Grade 9
    list.addAll(_createUnits(
      grade: g9,
      subject: EduRiseSubjects.chemistry,
      slug: 'chemistry',
      units: [
        (1, 'Structure of the Atom & Atomic Models'),
        (2, 'Periodic Classification of Elements'),
        (3, 'Chemical Bonding: Ionic & Covalent'),
        (4, 'Chemical Reactions and Stoichiometry'),
      ],
    ));

    // Biology Grade 9
    list.addAll(_createUnits(
      grade: g9,
      subject: EduRiseSubjects.biology,
      slug: 'biology',
      units: [
        (1, 'Introduction to Biology & Scientific Methods'),
        (2, 'Characteristics and Classification of Living Organisms'),
        (3, 'Cell Structure, Organelles & Function'),
        (4, 'Reproduction in Plants and Animals'),
      ],
    ));

    // English Grade 9
    list.addAll(_createUnits(
      grade: g9,
      subject: EduRiseSubjects.english,
      slug: 'english',
      units: [
        (1, 'Living in a Global Community'),
        (2, 'Water Resources and Conservation in Ethiopia'),
        (3, 'Environmental Protection and Reforestation'),
        (4, 'Traditional and Modern Agriculture'),
      ],
    ));

    // Geography Grade 9
    list.addAll(_createUnits(
      grade: g9,
      subject: EduRiseSubjects.geography,
      slug: 'geography',
      units: [
        (1, 'Geological Structure and Relief of Ethiopia'),
        (2, 'Drainage Systems and Water Resources of Ethiopia'),
        (3, 'Climate Zones and Agro-ecological Divisions'),
        (4, 'Natural Vegetation, Wildlife and Conservation'),
      ],
    ));

    // History Grade 9
    list.addAll(_createUnits(
      grade: g9,
      subject: EduRiseSubjects.history,
      slug: 'history',
      units: [
        (1, 'Peoples and States of Ancient and Medieval Ethiopia'),
        (2, 'The Age of Regionalism and Reunification (1855–1889)'),
        (3, 'European Imperialism and the Scramble for Africa'),
        (4, 'The Battle of Adwa & Anti-Colonial Victory'),
      ],
    ));

    // Economics Grade 9
    list.addAll(_createUnits(
      grade: g9,
      subject: EduRiseSubjects.economics,
      slug: 'economics',
      units: [
        (1, 'Nature and Scope of Economics'),
        (2, 'Scarcity, Choice and Opportunity Cost'),
        (3, 'Comparative Economic Systems'),
        (4, 'Elementary Theory of Demand and Supply'),
      ],
    ));

    // =========================================================================
    // GRADE 10 DEMO BOOKS (Ethiopian New Curriculum Foundation)
    // =========================================================================
    const g10 = 'Grade 10';

    // Mathematics Grade 10
    list.addAll(_createUnits(
      grade: g10,
      subject: EduRiseSubjects.mathematics,
      slug: 'math',
      units: [
        (1, 'Relations and Functions'),
        (2, 'Polynomial Functions and Roots'),
        (3, 'Exponential and Logarithmic Functions'),
        (4, 'Coordinate Geometry of Straight Lines & Circles'),
      ],
    ));

    // Physics Grade 10
    list.addAll(_createUnits(
      grade: g10,
      subject: EduRiseSubjects.physics,
      slug: 'physics',
      units: [
        (1, 'Motion in Two Dimensions & Projectiles'),
        (2, 'Rotational Dynamics and Torque'),
        (3, 'Static Equilibrium and Elastic Properties'),
        (4, 'Fluid Mechanics and Pascal’s Principle'),
      ],
    ));

    // Chemistry Grade 10
    list.addAll(_createUnits(
      grade: g10,
      subject: EduRiseSubjects.chemistry,
      slug: 'chemistry',
      units: [
        (1, 'Solutions, Concentration and Solubility'),
        (2, 'Rates of Chemical Reaction and Kinetics'),
        (3, 'Dynamic Chemical Equilibrium'),
        (4, 'Acid-Base Equilibria and pH Indicators'),
      ],
    ));

    // Biology Grade 10
    list.addAll(_createUnits(
      grade: g10,
      subject: EduRiseSubjects.biology,
      slug: 'biology',
      units: [
        (1, 'Sub-disciplines of Modern Biology'),
        (2, 'Plants, Photosynthesis and Transpiration'),
        (3, 'Enzyme Action and Metabolic Pathways'),
        (4, 'Mendelian Genetics and Monohybrid Crosses'),
      ],
    ));

    // English Grade 10
    list.addAll(_createUnits(
      grade: g10,
      subject: EduRiseSubjects.english,
      slug: 'english',
      units: [
        (1, 'Science and Technology Breakthroughs'),
        (2, 'National Parks and Eco-Tourism in Ethiopia'),
        (3, 'Preserving Tangible & Intangible Cultural Heritage'),
        (4, 'Mass Communication and Digital Media Literacy'),
      ],
    ));

    // Geography Grade 10
    list.addAll(_createUnits(
      grade: g10,
      subject: EduRiseSubjects.geography,
      slug: 'geography',
      units: [
        (1, 'Map Reading, Scale and Topographic Interpretation'),
        (2, 'Global Weather, Atmospheric Pressure and Winds'),
        (3, 'Soil Types, Erosion and Conservation in Ethiopia'),
        (4, 'Population Trends and Urbanization in Ethiopia'),
      ],
    ));

    // History Grade 10
    list.addAll(_createUnits(
      grade: g10,
      subject: EduRiseSubjects.history,
      slug: 'history',
      units: [
        (1, 'Paleoanthropology and Early Human Origins in the Rift Valley'),
        (2, 'Medieval Sultanates and the Christian Kingdom Interactions'),
        (3, 'The Industrial Revolution and Colonial Expansion'),
        (4, 'State Centralization & Modernization under Menelik II'),
      ],
    ));

    // Economics Grade 10
    list.addAll(_createUnits(
      grade: g10,
      subject: EduRiseSubjects.economics,
      slug: 'economics',
      units: [
        (1, 'Theory of Consumer Behavior & Utility Analysis'),
        (2, 'Theory of Production and Cost Minimization'),
        (3, 'Perfect Competition vs. Monopoly Markets'),
        (4, 'Macroeconomic Indicators: GDP and Inflation'),
      ],
    ));

    // =========================================================================
    // GRADE 11 DEMO BOOKS (Ethiopian New Curriculum Streams)
    // =========================================================================
    const g11 = 'Grade 11';

    // Mathematics Grade 11
    list.addAll(_createUnits(
      grade: g11,
      subject: EduRiseSubjects.mathematics,
      slug: 'math',
      units: [
        (1, 'Advanced Relations and Inverse Functions'),
        (2, 'Rational Functions and Partial Fractions'),
        (3, 'Analytical Geometry of Conic Sections'),
        (4, 'Matrices, Determinants and Systems of Linear Equations'),
      ],
    ));

    // Physics Grade 11
    list.addAll(_createUnits(
      grade: g11,
      subject: EduRiseSubjects.physics,
      slug: 'physics',
      units: [
        (1, 'Measurement, Uncertainty and Dimensional Analysis'),
        (2, 'Kinematics in Two and Three Dimensions'),
        (3, 'Newtonian Dynamics and Applications'),
        (4, 'Work, Kinetic Energy and Conservation of Energy'),
      ],
    ));

    // Chemistry Grade 11
    list.addAll(_createUnits(
      grade: g11,
      subject: EduRiseSubjects.chemistry,
      slug: 'chemistry',
      units: [
        (1, 'Fundamental Concepts of Stoichiometry & Gases'),
        (2, 'Atomic Structure and Quantum Mechanical Model'),
        (3, 'Chemical Bonding and Molecular Geometry (VSEPR)'),
        (4, 'Intermolecular Forces and Liquid-Solid States'),
      ],
    ));

    // Biology Grade 11
    list.addAll(_createUnits(
      grade: g11,
      subject: EduRiseSubjects.biology,
      slug: 'biology',
      units: [
        (1, 'The Nature of Science and Biological Research'),
        (2, 'Biochemistry: Carbohydrates, Lipids and Proteins'),
        (3, 'Cellular Respiration and ATP Generation'),
        (4, 'Human Health, Immunology and Disease Prevention'),
      ],
    ));

    // English Grade 11
    list.addAll(_createUnits(
      grade: g11,
      subject: EduRiseSubjects.english,
      slug: 'english',
      units: [
        (1, 'Higher Education Pathways and Career Readiness'),
        (2, 'Indigenous Knowledge Systems of Ethiopia'),
        (3, 'Sustainable Energy and Environmental Resilience'),
        (4, 'Advanced Analytical Writing and Debate'),
      ],
    ));

    // Geography Grade 11
    list.addAll(_createUnits(
      grade: g11,
      subject: EduRiseSubjects.geography,
      slug: 'geography',
      units: [
        (1, 'The Physical Earth: Plate Tectonics and Volcanism'),
        (2, 'Climatology and Global Climate Classifications'),
        (3, 'Hydrology, Watershed Management and Oceans'),
        (4, 'Human-Environment Interactions in Sub-Saharan Africa'),
      ],
    ));

    // History Grade 11
    list.addAll(_createUnits(
      grade: g11,
      subject: EduRiseSubjects.history,
      slug: 'history',
      units: [
        (1, 'Historiography, Primary Sources and Oral Traditions'),
        (2, 'The Aksumite Empire: Trade, Currency and Inscriptions'),
        (3, 'The Zagwe Dynasty and Lalibela Rock-Hewn Architecture'),
        (4, 'The Gondarine Period and Zemene Mesafint Era'),
      ],
    ));

    // Economics Grade 11
    list.addAll(_createUnits(
      grade: g11,
      subject: EduRiseSubjects.economics,
      slug: 'economics',
      units: [
        (1, 'National Income Accounting and GDP Measurement'),
        (2, 'Aggregate Consumption, Savings and Investment Functions'),
        (3, 'Inflation, Unemployment and Business Cycles'),
        (4, 'Fiscal Policy and Government Budgeting in Ethiopia'),
      ],
    ));

    return list;
  }

  static List<BookUnit> _createUnits({
    required String grade,
    required String subject,
    required String slug,
    required List<(int, String)> units,
  }) {
    final gradeNum = grade.replaceAll(RegExp(r'[^0-9]'), '');
    return units.map((u) {
      final unitNum = u.$1;
      final unitName = u.$2;
      return BookUnit(
        id: 'demo_g${gradeNum}_${slug}_u$unitNum',
        grade: grade,
        subject: subject,
        unitNumber: unitNum,
        unitName: unitName,
        pdfUrl: 'https://raw.githubusercontent.com/mozilla/pdf.js/master/web/compressed.tracemonkey-pldi-09.pdf',
      );
    }).toList();
  }
}
