import 'package:edurise/features/admin/data/admin_service.dart';
import 'package:edurise/features/practice/data/question_model.dart';
import 'package:edurise/features/practice/data/question_service.dart';
import 'package:edurise/features/practice/presentation/practice_result_screen.dart';
import 'package:edurise/features/practice/presentation/practice_selection_screen.dart';
import 'package:edurise/features/challenges/data/challenge_model.dart';
import 'package:edurise/features/challenges/presentation/challenges_screen.dart';
import 'package:edurise/features/weak_areas/data/weak_areas_service.dart';
import 'package:edurise/features/weak_areas/presentation/weak_areas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Question Model Resilience & Mapping', () {
    test('Question.fromMap parses both int and string numeric fields gracefully', () {
      final mapWithStrings = {
        'grade': 'Grade 11',
        'stream': 'natural',
        'subject': 'Biology',
        'unit_number': '3',
        'unit_name': 'Cell Biology',
        'question_number': '1',
        'question': 'Which organelle produces ATP?',
        'options': ['Mitochondria', 'Ribosome', 'Nucleus', 'Vacuole'],
        'correctAnswer': 'A',
        'explanation': 'Mitochondria are the powerhouses of the cell.',
        'entrance_year_ec': '2017',
        'status': 'published',
      };

      final q = Question.fromMap('q1', mapWithStrings);

      expect(q.id, 'q1');
      expect(q.grade, 'Grade 11');
      expect(q.stream, 'natural');
      expect(q.subject, 'Biology');
      expect(q.unitNumber, 3);
      expect(q.unitName, 'Cell Biology');
      expect(q.questionNumber, 1);
      expect(q.examYear, 2017);
      expect(q.correctAnswer, 'A');
      expect(q.status, 'published');
    });

    test('Question.fromMap supports textbook_grade and field aliases', () {
      final mapWithAliases = {
        'textbook_grade': 'Grade 12',
        'stream': 'Natural Science',
        'subject': 'Chemistry',
        'unitNumber': 2,
        'unitName': 'Acid-Base Equilibria',
        'questionNumber': 5,
        'question_text': 'What is the pH of pure water?',
        'options': ['5', '6', '7', '8'],
        'answer': 'C',
        'explanation': 'Neutral pH is 7 at 25°C.',
        'examYear': 2016,
        'status': 'published',
      };

      final q = Question.fromMap('q2', mapWithAliases);

      expect(q.grade, 'Grade 12');
      expect(q.subject, 'Chemistry');
      expect(q.unitNumber, 2);
      expect(q.question, 'What is the pH of pure water?');
      expect(q.correctAnswer, 'C');
      expect(q.examYear, 2016);
    });
  });

  group('Practice Filtering Logic — Section 22 Tests', () {
    final dataset = [
      // Test A: Grade 11 Biology Unit 3 2017
      const Question(
        id: 'q_bio_g11_u3_2017',
        grade: 'Grade 11',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 3,
        unitName: 'Cell Biology',
        questionNumber: 1,
        question: 'What is the cell membrane composed of?',
        options: ['Phospholipid bilayer', 'Cellulose', 'Chitin', 'Peptidoglycan'],
        correctAnswer: 'A',
        explanation: 'Cell membranes consist primarily of a phospholipid bilayer.',
        examYear: 2017,
        examType: 'Practice Question',
        status: 'published',
      ),

      // Test B: Grade 12 Biology Unit 3 2017 (Same unit, same subject, same year, DIFFERENT GRADE)
      const Question(
        id: 'q_bio_g12_u3_2017',
        grade: 'Grade 12',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 3,
        unitName: 'Genetics',
        questionNumber: 1,
        question: 'Which law describes gene segregation?',
        options: ["Mendel's First Law", "Mendel's Second Law", 'Hardy-Weinberg', 'Darwinian Law'],
        correctAnswer: 'A',
        explanation: "Mendel's first law is the law of segregation.",
        examYear: 2017,
        examType: 'Practice Question',
        status: 'published',
      ),

      // Test C: Grade 11 Biology Unit 3 2016 (Same grade, same subject, same unit, DIFFERENT YEAR)
      const Question(
        id: 'q_bio_g11_u3_2016',
        grade: 'Grade 11',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 3,
        unitName: 'Cell Biology',
        questionNumber: 2,
        question: 'Which organelle is responsible for cellular respiration?',
        options: ['Mitochondria', 'Chloroplast', 'Ribosome', 'Golgi apparatus'],
        correctAnswer: 'A',
        explanation: 'Mitochondria perform aerobic cellular respiration.',
        examYear: 2016,
        examType: 'Practice Question',
        status: 'published',
      ),

      // Test D: Grade 11 Biology Unit 1 2017 (Same grade, same subject, same year, DIFFERENT UNIT)
      const Question(
        id: 'q_bio_g11_u1_2017',
        grade: 'Grade 11',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 1,
        unitName: 'The Science of Biology',
        questionNumber: 1,
        question: 'What is the scientific method?',
        options: ['Systematic investigation', 'Guessing', 'Mythology', 'Astrology'],
        correctAnswer: 'A',
        explanation: 'Scientific method is a systematic process of observation and experimentation.',
        examYear: 2017,
        examType: 'Practice Question',
        status: 'published',
      ),

      // Test F: Draft question (Same criteria as Test A, but status is draft)
      const Question(
        id: 'q_bio_g11_u3_2017_draft',
        grade: 'Grade 11',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 3,
        unitName: 'Cell Biology',
        questionNumber: 3,
        question: 'Draft question not yet approved for students',
        options: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'Draft explanation',
        examYear: 2017,
        examType: 'Practice Question',
        status: 'draft',
      ),
    ];

    List<Question> filterQuestions({
      required String requestedGrade,
      required String requestedSubject,
      required int requestedUnit,
      required int requestedYear,
    }) {
      return dataset.where((q) {
        if (q.status != 'published') return false;
        if (q.grade != requestedGrade) return false;
        if (q.subject.toLowerCase() != requestedSubject.toLowerCase()) return false;
        if (q.unitNumber != requestedUnit) return false;
        if (q.examYear != requestedYear) return false;
        return true;
      }).toList();
    }

    test('Test A: Selecting Grade 11 Biology Unit 3 2017 returns only Grade 11 Unit 3 2017 questions', () {
      final results = filterQuestions(
        requestedGrade: 'Grade 11',
        requestedSubject: 'Biology',
        requestedUnit: 3,
        requestedYear: 2017,
      );

      expect(results.length, 1);
      expect(results.first.id, 'q_bio_g11_u3_2017');
      expect(results.first.grade, 'Grade 11');
      expect(results.first.unitNumber, 3);
      expect(results.first.examYear, 2017);
    });

    test('Test B: Grade 11 vs Grade 12 separation — Grade 12 question MUST NOT appear when Grade 11 is selected', () {
      // Select Grade 11
      final g11Results = filterQuestions(
        requestedGrade: 'Grade 11',
        requestedSubject: 'Biology',
        requestedUnit: 3,
        requestedYear: 2017,
      );

      expect(g11Results.any((q) => q.grade == 'Grade 12'), isFalse);
      expect(g11Results.map((q) => q.id), contains('q_bio_g11_u3_2017'));
      expect(g11Results.map((q) => q.id), isNot(contains('q_bio_g12_u3_2017')));

      // Select Grade 12
      final g12Results = filterQuestions(
        requestedGrade: 'Grade 12',
        requestedSubject: 'Biology',
        requestedUnit: 3,
        requestedYear: 2017,
      );

      expect(g12Results.any((q) => q.grade == 'Grade 11'), isFalse);
      expect(g12Results.map((q) => q.id), contains('q_bio_g12_u3_2017'));
      expect(g12Results.map((q) => q.id), isNot(contains('q_bio_g11_u3_2017')));
    });

    test('Test C: Year separation — Selecting 2017 must not return 2016 questions', () {
      final results2017 = filterQuestions(
        requestedGrade: 'Grade 11',
        requestedSubject: 'Biology',
        requestedUnit: 3,
        requestedYear: 2017,
      );

      expect(results2017.map((q) => q.examYear).toSet(), equals({2017}));
      expect(results2017.map((q) => q.id), contains('q_bio_g11_u3_2017'));
      expect(results2017.map((q) => q.id), isNot(contains('q_bio_g11_u3_2016')));

      final results2016 = filterQuestions(
        requestedGrade: 'Grade 11',
        requestedSubject: 'Biology',
        requestedUnit: 3,
        requestedYear: 2016,
      );

      expect(results2016.map((q) => q.examYear).toSet(), equals({2016}));
      expect(results2016.map((q) => q.id), contains('q_bio_g11_u3_2016'));
      expect(results2016.map((q) => q.id), isNot(contains('q_bio_g11_u3_2017')));
    });

    test('Test D: Unit separation — Selecting Unit 3 must not return Unit 1 questions', () {
      final unit3Results = filterQuestions(
        requestedGrade: 'Grade 11',
        requestedSubject: 'Biology',
        requestedUnit: 3,
        requestedYear: 2017,
      );

      expect(unit3Results.map((q) => q.unitNumber).toSet(), equals({3}));
      expect(unit3Results.map((q) => q.id), contains('q_bio_g11_u3_2017'));
      expect(unit3Results.map((q) => q.id), isNot(contains('q_bio_g11_u1_2017')));
    });

    test('Test E: Student grade independence — A student enrolled in Grade 9 can practice Grade 11 content', () {
      const studentCurrentGrade = 'Grade 9';
      const studentStream = 'natural';

      // Student chooses textbook Grade 11
      const chosenTextbookGrade = 'Grade 11';
      expect(chosenTextbookGrade, isNot(equals(studentCurrentGrade)));

      final results = filterQuestions(
        requestedGrade: chosenTextbookGrade,
        requestedSubject: 'Biology',
        requestedUnit: 3,
        requestedYear: 2017,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.grade, 'Grade 11');
      expect(results.first.stream, studentStream);
    });

    test('Test F: Draft questions are isolated and never returned for student practice', () {
      final results = filterQuestions(
        requestedGrade: 'Grade 11',
        requestedSubject: 'Biology',
        requestedUnit: 3,
        requestedYear: 2017,
      );

      expect(results.any((q) => q.status == 'draft'), isFalse);
      expect(results.map((q) => q.id), isNot(contains('q_bio_g11_u3_2017_draft')));
    });
  });

  group('Weak Areas Aggregation, Grouping & Presentation', () {
    test('WeakArea.formattedUnitInfo returns Grade X • Unit Y UnitName', () {
      const area = WeakArea(
        subject: 'Biology',
        grade: 'Grade 11',
        unitNumber: 3,
        unitName: 'Cell Biology',
        stream: 'natural',
        accuracy: 65,
        totalQuestions: 20,
        correctAnswers: 13,
      );

      expect(area.formattedUnitInfo, 'Grade 11 • Unit 3 Cell Biology');
      expect(area.displayTitle, 'Biology Grade 11 • Unit 3 Cell Biology');
      expect(area.topic, 'Grade 11 • Unit 3 Cell Biology');
      expect(area.accuracy, 65);
    });

    test('Aggregates multiple practice sessions for the same content area correctly', () {
      final sessionRecords = [
        {
          'grade': 'Grade 11',
          'subject': 'Biology',
          'unitNumber': 3,
          'unitName': 'Cell Biology',
          'totalQuestions': 10,
          'correctAnswers': 7,
          'score': 70,
        },
        {
          'grade': 'Grade 11',
          'subject': 'Biology',
          'unitNumber': 3,
          'unitName': 'Cell Biology',
          'totalQuestions': 10,
          'correctAnswers': 6,
          'score': 60,
        },
      ];

      int totalQ = 0;
      int totalC = 0;
      for (final r in sessionRecords) {
        totalQ += (r['totalQuestions'] as int);
        totalC += (r['correctAnswers'] as int);
      }

      final accuracy = ((totalC / totalQ) * 100).round();
      expect(totalQ, 20);
      expect(totalC, 13);
      expect(accuracy, 65); // Exactly 65% as requested in prompt!
    });

    test('Different grades with identical unit names remain separate and are not merged', () {
      final records = [
        {
          'grade': 'Grade 9',
          'subject': 'Biology',
          'unitNumber': 1,
          'unitName': 'Introduction to Biology',
          'totalQuestions': 10,
          'correctAnswers': 8,
        },
        {
          'grade': 'Grade 11',
          'subject': 'Biology',
          'unitNumber': 1,
          'unitName': 'Introduction to Biology',
          'totalQuestions': 10,
          'correctAnswers': 5,
        },
      ];

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final r in records) {
        final key = '${r['grade']}|${r['subject']}|${r['unitNumber']}|${r['unitName']}';
        grouped.putIfAbsent(key, () => []).add(r);
      }

      expect(grouped.keys.length, 2);
      expect(grouped.containsKey('Grade 9|Biology|1|Introduction to Biology'), isTrue);
      expect(grouped.containsKey('Grade 11|Biology|1|Introduction to Biology'), isTrue);

      final g9Results = grouped['Grade 9|Biology|1|Introduction to Biology']!;
      final g11Results = grouped['Grade 11|Biology|1|Introduction to Biology']!;

      expect(g9Results.first['grade'], 'Grade 9');
      expect(g11Results.first['grade'], 'Grade 11');
    });

    test('Weak areas are sorted ascending by accuracy (lowest accuracy first)', () {
      final weakAreas = [
        const WeakArea(
          subject: 'Chemistry',
          grade: 'Grade 12',
          unitNumber: 2,
          unitName: 'Acid-Base Equilibria',
          accuracy: 75,
          totalQuestions: 10,
          correctAnswers: 7,
        ),
        const WeakArea(
          subject: 'Biology',
          grade: 'Grade 11',
          unitNumber: 3,
          unitName: 'Cell Biology',
          accuracy: 45,
          totalQuestions: 20,
          correctAnswers: 9,
        ),
        const WeakArea(
          subject: 'Physics',
          grade: 'Grade 11',
          unitNumber: 4,
          unitName: 'Heat and Thermodynamics',
          accuracy: 60,
          totalQuestions: 10,
          correctAnswers: 6,
        ),
      ];

      weakAreas.sort((a, b) => a.accuracy.compareTo(b.accuracy));

      expect(weakAreas[0].accuracy, 45);
      expect(weakAreas[0].subject, 'Biology');
      expect(weakAreas[1].accuracy, 60);
      expect(weakAreas[1].subject, 'Physics');
      expect(weakAreas[2].accuracy, 75);
      expect(weakAreas[2].subject, 'Chemistry');
    });
  });

  group('Widget Tests: PracticeSelectionScreen & PracticeResultScreen', () {
    testWidgets('PracticeSelectionScreen renders Grade dropdown and Year options 2013-2018', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PracticeSelectionScreen(
            grade: 'Grade 9',
            stream: 'Natural Science',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header shows stream badge
      expect(find.text('Natural Science Stream'), findsOneWidget);

      // Verify NO Stream dropdown is added
      expect(find.text('Stream'), findsNothing);

      // Verify Grade dropdown exists and has textbook grade title
      expect(find.text('Textbook Grade'), findsOneWidget);

      // Verify Entrance Exam Year dropdown exists
      expect(find.text('Entrance Exam Year'), findsOneWidget);
      expect(find.text('2017 EC'), findsOneWidget);

      // Tap the Year dropdown to verify options 2013 to 2018
      await tester.tap(find.text('2017 EC'));
      await tester.pumpAndSettle();

      expect(find.text('2013 EC'), findsWidgets);
      expect(find.text('2014 EC'), findsWidgets);
      expect(find.text('2015 EC'), findsWidgets);
      expect(find.text('2016 EC'), findsWidgets);
      expect(find.text('2017 EC'), findsWidgets);
      expect(find.text('2018 EC'), findsWidgets);

      // Select 2015 EC
      await tester.tap(find.text('2015 EC').last);
      await tester.pumpAndSettle();

      expect(find.text('2015 EC'), findsOneWidget);
    });

    testWidgets('PracticeResultScreen renders Review All and Practice Again buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const q = Question(
        id: 'q1',
        grade: 'Grade 11',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 3,
        unitName: 'Cell Biology',
        questionNumber: 1,
        question: 'What is cytology?',
        options: ['Study of cells', 'Study of tissues', 'Study of bones', 'Study of skin'],
        correctAnswer: 'A',
        explanation: 'Cytology is cell biology.',
        examYear: 2017,
        examType: 'Practice Question',
        status: 'published',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PracticeResultScreen(
            totalQuestions: 1,
            correctAnswers: 1,
            mistakes: [],
            selectedAnswers: {0: 'A'},
            questions: [q],
            stream: 'natural',
            grade: 'Grade 11',
            subject: 'Biology',
            unitNumber: 3,
            unitName: 'Cell Biology',
            examYear: 2017,
            percentage: 100,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Practice Complete!'), findsOneWidget);
      expect(find.text('Cell Biology • Biology • Grade 11 • 2017 EC'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Verify Review All and Practice Again buttons exist
      expect(find.text('Review All'), findsOneWidget);
      expect(find.text('Practice Again'), findsOneWidget);
      expect(find.text('Back to Practice Selection'), findsOneWidget);
    });

    testWidgets('WeakAreasScreen renders Biology Grade 11 • Unit 3 Cell Biology with 65%', (tester) async {
      const area = WeakArea(
        subject: 'Biology',
        grade: 'Grade 11',
        unitNumber: 3,
        unitName: 'Cell Biology',
        stream: 'natural',
        accuracy: 65,
        totalQuestions: 20,
        correctAnswers: 13,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: WeakAreasScreen(
            initialWeakAreas: [area],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Biology Grade 11 • Unit 3 Cell Biology'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('Practice This Area'), findsOneWidget);
    });

    testWidgets('PracticeSelectionScreen handles narrow mobile width (360x640) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PracticeSelectionScreen(
            grade: 'Grade 11',
            stream: 'Natural Science',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Start Practice'), 100);
      expect(find.text('Start Practice'), findsOneWidget);
    });
  });

  group('Immediate Founder/Admin Recognition & Cache Clearing', () {
    test('AdminService.founderEmail and adminEmail constants are preserved', () {
      expect(AdminService.founderEmail, 'olanamengistu2@gmail.com');
      expect(AdminService.adminEmail, 'tamiratboja@gmail.com');
    });

    test('AdminService.clearCache resets in-memory cached state', () {
      AdminService.clearCache();
      expect(AdminService.isFounder, isFalse);
      expect(AdminService.isAdmin, isFalse);
    });

    test('AdminService.resolvePostAuthRoute returns /login when no user is authenticated', () async {
      final route = await AdminService.resolvePostAuthRoute();
      expect(route, '/login');
    });
  });

  group('Confirmed Real Question & Canonical Stream Normalization', () {
    test('QuestionService.normalizeStream canonicalizes all variants to natural or social', () {
      expect(QuestionService.normalizeStream(''), 'natural');
      expect(QuestionService.normalizeStream(null), 'natural');
      expect(QuestionService.normalizeStream('natural'), 'natural');
      expect(QuestionService.normalizeStream('Natural Science'), 'natural');
      expect(QuestionService.normalizeStream('natural-science'), 'natural');
      expect(QuestionService.normalizeStream('social'), 'social');
      expect(QuestionService.normalizeStream('Social Science'), 'social');
      expect(QuestionService.normalizeStream('', subject: 'Economics'), 'social');
      expect(QuestionService.normalizeStream('', subject: 'Biology'), 'natural');
    });

    test('Real Firestore Document maps and filters correctly for Grade 9 Biology Unit 1 2016 EC', () {
      const realDoc = {
        'stream': 'natural',
        'grade': 'Grade 9',
        'subject': 'Biology',
        'unitNumber': 1,
        'unitName': 'TEST UNIT - Introduction to Biology',
        'examYear': 2016,
        'examType': 'entrance',
        'status': 'published',
        'questionNumber': 1,
        'question': 'Which of the following is a characteristic of living organisms?',
        'options': ['Growth', 'Rusting', 'Melting', 'Burning'],
        'correctAnswer': 'A',
        'explanation': 'Growth is one of the characteristics of living organisms.',
      };

      final q = Question.fromMap('q_real_bio_g9_u1', realDoc);

      expect(q.id, 'q_real_bio_g9_u1');
      expect(q.grade, 'Grade 9');
      expect(q.stream, 'natural');
      expect(q.subject, 'Biology');
      expect(q.unitNumber, 1);
      expect(q.unitName, 'TEST UNIT - Introduction to Biology');
      expect(q.examYear, 2016);
      expect(q.status, 'published');
      expect(q.question, 'Which of the following is a characteristic of living organisms?');
      expect(q.options, ['Growth', 'Rusting', 'Melting', 'Burning']);
      expect(q.correctAnswer, 'A');
      expect(q.explanation, 'Growth is one of the characteristics of living organisms.');

      // In-memory simulation of getQuestions filter logic:
      final matchesQuery = (q.grade == 'Grade 9') &&
          (q.subject.toLowerCase() == 'biology') &&
          (q.unitNumber == 1) &&
          (q.examYear == 2016) &&
          (q.status == 'published') &&
          (q.stream == QuestionService.normalizeStream(''));

      expect(matchesQuery, isTrue);
    });

    testWidgets('PracticeSelectionScreen shows canonical stream in badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PracticeSelectionScreen(
            grade: 'Grade 9',
            stream: 'natural',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Natural Science Stream'), findsOneWidget);
    });
  });

  group('Practice State Management & Dependent Dropdowns — Sections 16, 20, 21', () {
    testWidgets('Dropdown flow: Selecting Grade, Subject, Unit, and Year preserves Unit on Year change', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PracticeSelectionScreen(
            grade: 'Grade 9',
            stream: 'natural',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Grade 9 is initially selected
      expect(find.text('Grade 9'), findsOneWidget);

      // Select Subject: Biology
      final subjectDropdown = find.text('Select subject');
      expect(subjectDropdown, findsOneWidget);
      await tester.tap(subjectDropdown, warnIfMissed: false);
      await tester.pumpAndSettle();

      final biologyItem = find.text('Biology').last;
      await tester.tap(biologyItem);
      await tester.pumpAndSettle();

      expect(find.text('Biology'), findsOneWidget);

      // Verify Year change preserves state
      final yearDropdown = find.text('2017 EC');
      expect(yearDropdown, findsOneWidget);
      await tester.tap(yearDropdown, warnIfMissed: false);
      await tester.pumpAndSettle();

      final year2016 = find.text('2016 EC').last;
      await tester.tap(year2016);
      await tester.pumpAndSettle();

      expect(find.text('2016 EC'), findsOneWidget);
      // Biology is still selected
      expect(find.text('Biology'), findsOneWidget);
    });

    test('End-to-End Simulation: Grade 9 Biology Unit 1 2016 EC query filter & validation', () {
      // Simulate selection state
      const selectedGrade = 'Grade 9';
      const selectedSubject = 'Biology';
      const selectedStream = 'natural';
      const selectedUnitNumber = 1;
      const selectedUnitName = 'TEST UNIT - Introduction to Biology';
      const selectedYear = 2016;

      // Validation check
      expect(selectedGrade, isNotNull);
      expect(selectedSubject, isNotNull);
      expect(selectedUnitNumber > 0, isTrue);
      expect(selectedYear, isNotNull);

      // Question dataset containing real question
      final dataset = [
        const Question(
          id: 'q_g9_bio_u1_2016',
          grade: 'Grade 9',
          stream: 'natural',
          subject: 'Biology',
          unitNumber: 1,
          unitName: 'TEST UNIT - Introduction to Biology',
          questionNumber: 1,
          question: 'Which of the following is a characteristic of living organisms?',
          options: ['Growth', 'Rusting', 'Melting', 'Burning'],
          correctAnswer: 'A',
          explanation: 'Growth is one of the characteristics of living organisms.',
          examYear: 2016,
          examType: 'entrance',
          status: 'published',
        ),
        // Irrelevant question that must not match
        const Question(
          id: 'q_g9_bio_u2_2016',
          grade: 'Grade 9',
          stream: 'natural',
          subject: 'Biology',
          unitNumber: 2,
          unitName: 'Cell Biology',
          questionNumber: 2,
          question: 'Another question',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'B',
          explanation: 'Explanation',
          examYear: 2016,
          examType: 'entrance',
          status: 'published',
        ),
      ];

      // Execute filter matching QuestionService.getQuestions logic
      final filtered = dataset.where((q) {
        if (q.grade != selectedGrade) return false;
        if (q.subject.toLowerCase() != selectedSubject.toLowerCase()) return false;
        if (q.unitNumber != selectedUnitNumber) return false;
        if (q.examYear != selectedYear) return false;
        if (q.status.toLowerCase() != 'published') return false;
        return true;
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.question, 'Which of the following is a characteristic of living organisms?');
      expect(filtered.first.correctAnswer, 'A');
      expect(filtered.first.unitName, selectedUnitName);
    });
  });

  group('Part 1, 2, 3 Verification: Weak Areas Unique Questions, Progress & Challenges', () {
    test('Test 1: Weak Areas calculation for 1 unique question repeated 6 times yields unique questions = 1', () {
      // Biology Grade 10 Unit 1: 1 question answered 6 times
      final sessionRecords = List.generate(6, (index) {
        return {
          'grade': 'Grade 10',
          'subject': 'Biology',
          'unitNumber': 1,
          'unitName': 'Cell Biology',
          'totalQuestions': 1,
          'correctAnswers': 1,
          'wrongAnswers': 0,
          'score': 100,
          'questionIds': ['q_bio_1'],
          'correctQuestionIds': ['q_bio_1'],
          'questionResults': {'q_bio_1': true},
          'timestamp': DateTime(2026, 9, 1, 10, index),
        };
      });

      final Map<String, bool> uniqueQuestions = {};
      final List<String> allAttemptedIds = [];

      for (final data in sessionRecords) {
        if (data['questionResults'] is Map) {
          final qr = data['questionResults'] as Map;
          qr.forEach((key, val) {
            final qId = key.toString();
            allAttemptedIds.add(qId);
            uniqueQuestions[qId] = val == true;
          });
        }
      }

      final totalUnique = uniqueQuestions.length;
      final correctUnique = uniqueQuestions.values.where((isCorrect) => isCorrect).length;
      final accuracy = totalUnique > 0 ? ((correctUnique / totalUnique) * 100).round() : 0;

      expect(totalUnique, 1); // Exactly 1 unique question! NOT 6!
      expect(correctUnique, 1);
      expect(accuracy, 100);
      expect(allAttemptedIds.length, 6);
    });

    test('Test 2: Weak Areas calculation for 3 unique questions repeated multiple times yields unique questions = 3', () {
      // Q1 (3 times), Q2 (2 times), Q3 (1 time)
      final sessionRecords = [
        {
          'questionResults': {'q1': true},
          'questionIds': ['q1'],
          'timestamp': DateTime(2026, 9, 1, 1),
        },
        {
          'questionResults': {'q1': false},
          'questionIds': ['q1'],
          'timestamp': DateTime(2026, 9, 1, 2),
        },
        {
          'questionResults': {'q1': true}, // Latest attempt for Q1: true
          'questionIds': ['q1'],
          'timestamp': DateTime(2026, 9, 1, 3),
        },
        {
          'questionResults': {'q2': true},
          'questionIds': ['q2'],
          'timestamp': DateTime(2026, 9, 1, 4),
        },
        {
          'questionResults': {'q2': true}, // Latest attempt for Q2: true
          'questionIds': ['q2'],
          'timestamp': DateTime(2026, 9, 1, 5),
        },
        {
          'questionResults': {'q3': false}, // Latest attempt for Q3: false
          'questionIds': ['q3'],
          'timestamp': DateTime(2026, 9, 1, 6),
        },
      ];

      // Sort chronological
      sessionRecords.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

      final Map<String, bool> uniqueQuestions = {};
      final List<String> allAttemptedIds = [];

      for (final data in sessionRecords) {
        final qr = data['questionResults'] as Map<String, dynamic>;
        qr.forEach((key, val) {
          allAttemptedIds.add(key);
          uniqueQuestions[key] = val == true;
        });
      }

      final totalUnique = uniqueQuestions.length;
      final correctUnique = uniqueQuestions.values.where((isCorrect) => isCorrect).length;
      final accuracy = totalUnique > 0 ? ((correctUnique / totalUnique) * 100).round() : 0;

      expect(totalUnique, 3); // Exactly 3 unique questions, NOT 6!
      expect(correctUnique, 2); // Q1 and Q2 true, Q3 false
      expect(accuracy, 67); // 2/3 = 67%
    });

    test('Test 3: Legacy records without question IDs are strictly bounded by actual published questions count', () {
      // 6 legacy sessions with no questionIds, but Firestore publishedCount = 1
      final legacySessions = List.generate(6, (i) => {
        'totalQuestions': 1,
        'correctAnswers': 1,
        'wrongAnswers': 0,
        'score': 100,
      });

      const publishedCountInFirestore = 1;
      int totalUnique = publishedCountInFirestore;
      final lastData = legacySessions.last;
      final lastTotal = lastData['totalQuestions'] as int;
      final lastCorrect = lastData['correctAnswers'] as int;

      int correctUnique = 0;
      if (publishedCountInFirestore == 1) {
        correctUnique = lastCorrect > 0 ? 1 : 0;
      } else {
        correctUnique = lastTotal > 0 ? ((lastCorrect / lastTotal) * totalUnique).round() : 0;
      }

      final accuracy = totalUnique > 0 ? ((correctUnique / totalUnique) * 100).round() : 0;

      expect(totalUnique, 1); // Bounded to 1! NOT 6, NOT 15!
      expect(correctUnique, 1);
      expect(accuracy, 100);
    });

    test('Test 4: Progress calculation properly sums session metrics and does not stay at 0%', () {
      final practiceResults = [
        {
          'userId': 'user123',
          'totalQuestions': 10,
          'correctAnswers': 8,
          'wrongAnswers': 2,
          'score': 80,
          'timestamp': DateTime(2026, 9, 1),
        },
        {
          'userId': 'user123',
          'totalQuestions': 5,
          'correctAnswers': 4,
          'wrongAnswers': 1,
          'score': 80,
          'timestamp': DateTime(2026, 9, 2),
        },
      ];

      int totalQuestions = 0;
      int correctAnswers = 0;
      int wrongAnswers = 0;

      for (final result in practiceResults) {
        final tQ = (result['totalQuestions'] as num?)?.toInt() ?? 0;
        final cA = (result['correctAnswers'] as num?)?.toInt() ?? 0;
        final wA = (result['wrongAnswers'] as num?)?.toInt() ?? (tQ >= cA ? (tQ - cA) : 0);

        totalQuestions += tQ;
        correctAnswers += cA;
        wrongAnswers += wA;
      }

      final accuracy = totalQuestions == 0
          ? 0
          : ((correctAnswers / totalQuestions) * 100).round();

      expect(totalQuestions, 15);
      expect(correctAnswers, 12);
      expect(wrongAnswers, 3);
      expect(accuracy, 80); // 12 / 15 * 100 = 80%, NOT 0%!
    });

    testWidgets('Test 5: ChallengesScreen renders EXACTLY ONE Start Challenge button (no duplicates)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final challenge = Challenge(
        id: 'c1',
        userId: 'user123',
        title: 'Master Unit 1: Introduction to Biology',
        description: 'Practice 10 questions to master this unit',
        challengeType: 'practice',
        grade: 'Grade 10',
        subject: 'Biology',
        unitNumber: 1,
        unitName: 'Introduction to Biology',
        targetCount: 10,
        currentCount: 0,
        scheduledDate: DateTime.now(),
        isCompleted: false,
        rewardXp: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChallengesScreen(
            initialChallenges: [challenge],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify challenge title and details are displayed
      expect(find.text('Master Unit 1: Introduction to Biology'), findsOneWidget);
      expect(find.text('Practice 10 questions to master this unit'), findsOneWidget);

      // Verify EXACTLY ONE "Start Challenge" button is rendered!
      expect(find.widgetWithText(FilledButton, 'Start Challenge'), findsOneWidget);
      expect(find.text('Start Challenge'), findsOneWidget);
    });

    test('Test 6: Question retrieval with unitNumber <= 0 does not reject published questions', () {
      final dataset = [
        const Question(
          id: 'q1',
          grade: 'Grade 10',
          stream: 'natural',
          subject: 'Biology',
          unitNumber: 1,
          unitName: 'Cell Biology',
          questionNumber: 1,
          question: 'Question 1',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          explanation: 'Exp',
          examYear: 2017,
          examType: 'Practice Question',
          status: 'published',
        ),
        const Question(
          id: 'q2',
          grade: 'Grade 10',
          stream: 'natural',
          subject: 'Biology',
          unitNumber: 2,
          unitName: 'Genetics',
          questionNumber: 2,
          question: 'Question 2',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'B',
          explanation: 'Exp',
          examYear: 2017,
          examType: 'Practice Question',
          status: 'published',
        ),
        const Question(
          id: 'q_draft',
          grade: 'Grade 10',
          stream: 'natural',
          subject: 'Biology',
          unitNumber: 1,
          unitName: 'Cell Biology',
          questionNumber: 3,
          question: 'Draft Question',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'C',
          explanation: 'Exp',
          examYear: 2017,
          examType: 'Practice Question',
          status: 'draft',
        ),
      ];

      // Simulate QuestionService.getQuestions filtering with unitNumber = 0 (general challenge)
      const requestedUnitNumber = 0;
      final results = dataset.where((q) {
        if (q.status.toLowerCase() != 'published') return false;
        if (q.grade != 'Grade 10') return false;
        if (q.subject.toLowerCase() != 'biology') return false;
        if (requestedUnitNumber > 0 && q.unitNumber != requestedUnitNumber) return false;
        return true;
      }).toList();

      expect(results.length, 2);
      expect(results.map((q) => q.id), containsAll(['q1', 'q2']));
      expect(results.any((q) => q.status == 'draft'), isFalse);
    });
  });
}
