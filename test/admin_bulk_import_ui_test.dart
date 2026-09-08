import 'package:edurise/features/admin/presentation/import_past_exams_screen.dart';
import 'package:edurise/features/admin/presentation/import_practice_questions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('ImportPracticeQuestionsScreen Widget Tests', () {
    testWidgets('renders all 4 steps and action buttons', (tester) async {
      await tester.pumpWidget(createTestWidget(const ImportPracticeQuestionsScreen()));

      expect(find.text('Import Practice Questions'), findsOneWidget);
      expect(find.text('Step 1 — Add Files'), findsOneWidget);
      expect(find.text('Step 2 — Validate All'), findsOneWidget);
      expect(find.text('Step 3 — Review'), findsOneWidget);
      expect(find.text('Step 4 — Import'), findsOneWidget);

      expect(find.text('📄  ADD FILE'), findsOneWidget);
      expect(find.text('Validate All Files'), findsOneWidget);
      expect(find.text('🚀 IMPORT ALL'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders summary cards with initial counts', (tester) async {
      await tester.pumpWidget(createTestWidget(const ImportPracticeQuestionsScreen()));

      expect(find.text('Files'), findsOneWidget);
      expect(find.text('Questions found'), findsOneWidget);
      expect(find.text('✓ Valid questions'), findsOneWidget);
      expect(find.text('⚠ Need review'), findsOneWidget);
      expect(find.text('✕ Invalid'), findsOneWidget);
    });
  });

  group('ImportPastExamsScreen Widget Tests', () {
    testWidgets('renders all 4 steps for past exam bulk import', (tester) async {
      await tester.pumpWidget(createTestWidget(const ImportPastExamsScreen()));

      expect(find.text('Import Past Entrance Exams'), findsOneWidget);
      expect(find.text('Step 1 — Add Exam Files'), findsOneWidget);
      expect(find.text('Step 2 — Validate All Exams'), findsOneWidget);
      expect(find.text('Step 3 — Review'), findsOneWidget);
      expect(find.text('Step 4 — Import'), findsOneWidget);

      expect(find.text('📄  ADD EXAM FILE'), findsOneWidget);
      expect(find.text('Validate All Exams'), findsOneWidget);
      expect(find.text('🚀 IMPORT ALL EXAMS'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders exam package summary stats', (tester) async {
      await tester.pumpWidget(createTestWidget(const ImportPastExamsScreen()));

      expect(find.text('Exam packages'), findsOneWidget);
      expect(find.text('Total questions'), findsOneWidget);
      expect(find.text('✓ Complete'), findsOneWidget);
      expect(find.text('⚠ Need review'), findsOneWidget);
      expect(find.text('✕ Invalid'), findsOneWidget);
    });
  });
}
