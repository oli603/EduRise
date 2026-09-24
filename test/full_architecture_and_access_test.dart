import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/core/auth/access_service.dart';
import 'package:edurise/core/constants/app_subjects.dart';
import 'package:edurise/core/localization/app_localizations.dart';
import 'package:edurise/features/profile_setup/presentation/profile_setup_screen.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

void main() {
  group('PART 1 & 2: Onboarding Grade Selection & Profile Setup', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(800, 1400);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('TEST 1: ProfileSetupScreen renders choices for Grade 9, 10, 11, and 12', (tester) async {
      await tester.pumpWidget(buildTestApp(const ProfileSetupScreen()));
      await tester.pumpAndSettle();

      // Check that all 4 high school grades are selectable
      expect(find.text('Grade 9'), findsOneWidget);
      expect(find.text('Grade 10'), findsOneWidget);
      expect(find.text('Grade 11'), findsOneWidget);
      expect(find.text('Grade 12'), findsOneWidget);

      // Verify selecting Grade 9 works
      await tester.tap(find.text('Grade 9'));
      await tester.pumpAndSettle();

      // Verify single Full Name text field is present
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      // Verify Stream dropdown is present
      expect(find.text('Stream'), findsOneWidget);
      expect(find.text('Select Stream'), findsOneWidget);
    });
  });

  group('PART 6 & 15: Centralized Ethiopian New Curriculum Subjects', () {
    test('TEST 2: EduRiseSubjects defines exact subjects and excludes Civics from entrance', () {
      // Natural stream subjects
      final natural = EduRiseSubjects.naturalStream;
      expect(natural, containsAll(['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English']));
      expect(natural.contains('Civics'), isFalse);
      expect(natural.contains('Civics & Ethical Education'), isFalse);

      // Social stream subjects
      final social = EduRiseSubjects.socialStream;
      expect(social, containsAll(['Mathematics', 'Economics', 'Geography', 'History', 'English']));
      expect(social.contains('Civics'), isFalse);
      expect(social.contains('Civics & Ethical Education'), isFalse);

      // Entrance exam subjects include SAT
      final naturalEntrance = EduRiseSubjects.getEntranceExamSubjects(stream: 'natural');
      expect(naturalEntrance, contains('SAT'));
      expect(naturalEntrance.contains('Civics'), isFalse);

      final socialEntrance = EduRiseSubjects.getEntranceExamSubjects(stream: 'social');
      expect(socialEntrance, contains('SAT'));
      expect(socialEntrance.contains('Civics'), isFalse);

      // Foundation grades (Grades 9 & 10)
      final foundation = EduRiseSubjects.foundationGrades9And10;
      expect(foundation.length, 9);
      expect(foundation.contains('Civics'), isFalse);
      expect(foundation.contains('SAT'), isTrue);

      // Practice subjects helper
      final practiceNatural12 = EduRiseSubjects.getPracticeSubjects(stream: 'natural', grade: 'Grade 12');
      expect(practiceNatural12, equals(natural));

      final practiceSocial12 = EduRiseSubjects.getPracticeSubjects(stream: 'social', grade: 'Grade 12');
      expect(practiceSocial12, equals(social));
    });
  });

  group('PART 7, 8, 9, 10: Free vs Paid Access Policy Rules', () {
    test('TEST 3: Grade 12 + Unit 1 + 2017 EC is allowed free for platform testing', () {
      final isAllowed = AccessService.isFreeAllowedPractice(
        grade: 'Grade 12',
        examYear: 2017,
        unitNumber: 1,
      );
      expect(isAllowed, isTrue);

      // Unit 2 is locked
      final isUnit2Allowed = AccessService.isFreeAllowedPractice(
        grade: 'Grade 12',
        examYear: 2017,
        unitNumber: 2,
      );
      expect(isUnit2Allowed, isFalse);
    });

    test('TEST 4: Any grade other than Grade 12 is LOCKED for free students', () {
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 9', examYear: 2017, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 10', examYear: 2017, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 11', examYear: 2017, unitNumber: 1),
        isFalse,
      );
    });

    test('TEST 5: Any year other than 2017 EC is LOCKED for free students', () {
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2016, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2015, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2014, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2013, unitNumber: 1),
        isFalse,
      );
    });
  });

  group('PART 12 & 18: Security Rules Logic Simulation', () {
    test('TEST 6: Firestore question read access logic for Free vs Paid students', () {
      bool canStudentReadQuestion({
        required bool isPaid,
        required String grade,
        required int examYear,
        required int unitNumber,
        required String status,
      }) {
        if (status != 'published') return false;
        // Free tier exception: Grade 12, Unit 1, 2017 EC
        if (grade == 'Grade 12' && examYear == 2017 && unitNumber == 1) return true;
        // Paid student can read any published question
        return isPaid;
      }

      // Case A: Free student + Grade 12 + Unit 1 + 2017 EC -> ALLOWED
      expect(
        canStudentReadQuestion(isPaid: false, grade: 'Grade 12', examYear: 2017, unitNumber: 1, status: 'published'),
        isTrue,
      );

      // Case A2: Free student + Grade 12 + Unit 2 + 2017 EC -> REJECTED
      expect(
        canStudentReadQuestion(isPaid: false, grade: 'Grade 12', examYear: 2017, unitNumber: 2, status: 'published'),
        isFalse,
      );

      // Case B: Free student + Grade 11 + Unit 1 + 2017 EC -> REJECTED
      expect(
        canStudentReadQuestion(isPaid: false, grade: 'Grade 11', examYear: 2017, unitNumber: 1, status: 'published'),
        isFalse,
      );

      // Case C: Free student + Grade 12 + Unit 1 + 2016 EC -> REJECTED
      expect(
        canStudentReadQuestion(isPaid: false, grade: 'Grade 12', examYear: 2016, unitNumber: 1, status: 'published'),
        isFalse,
      );

      // Case D: Paid student + Grade 11 + Unit 2 + 2016 EC -> ALLOWED
      expect(
        canStudentReadQuestion(isPaid: true, grade: 'Grade 11', examYear: 2016, unitNumber: 2, status: 'published'),
        isTrue,
      );

      // Case E: Draft question -> REJECTED for both free and paid students
      expect(
        canStudentReadQuestion(isPaid: true, grade: 'Grade 12', examYear: 2017, unitNumber: 1, status: 'draft'),
        isFalse,
      );
      expect(
        canStudentReadQuestion(isPaid: false, grade: 'Grade 12', examYear: 2017, unitNumber: 1, status: 'draft'),
        isFalse,
      );
    });

    test('TEST 7: Firestore student stream update rule without null property crash', () {
      bool evaluateSafeStreamUpdateRule({
        required Map<String, dynamic> existingData,
        required Map<String, dynamic> incomingData,
      }) {
        final existingStream = existingData['stream'];
        final incomingStream = incomingData['stream'];

        // Condition 1: Stream not in request
        if (incomingStream == null) return true;

        // Condition 2: Stream already set and incoming matches existing
        if (existingStream != null && existingStream != '' && incomingStream == existingStream) {
          return true;
        }

        // Condition 3: Stream was empty/unset, incoming is natural or social
        if ((existingStream == null || existingStream == '') &&
            (incomingStream == 'natural' || incomingStream == 'social')) {
          return true;
        }

        return false;
      }

      // 1. Initial establishment on doc with no stream -> ALLOWED
      expect(
        evaluateSafeStreamUpdateRule(
          existingData: {'name': 'Student'},
          incomingData: {'name': 'Student', 'stream': 'natural'},
        ),
        isTrue,
      );

      // 2. Grade update only (stream not in update) -> ALLOWED
      expect(
        evaluateSafeStreamUpdateRule(
          existingData: {'name': 'Student', 'grade': 'Grade 11', 'stream': 'natural'},
          incomingData: {'grade': 'Grade 12'},
        ),
        isTrue,
      );

      // 3. Attempting to change established natural -> social -> REJECTED
      expect(
        evaluateSafeStreamUpdateRule(
          existingData: {'name': 'Student', 'stream': 'natural'},
          incomingData: {'stream': 'social'},
        ),
        isFalse,
      );

      // 4. Attempting to set unauthorized stream -> REJECTED
      expect(
        evaluateSafeStreamUpdateRule(
          existingData: {'name': 'Student'},
          incomingData: {'stream': 'general'},
        ),
        isFalse,
      );
    });
  });
}
