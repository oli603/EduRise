import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/downloads/presentation/downloads_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleBook = DownloadPackageRecord(
    id: 'book_grade_12_biology',
    packageType: 'book',
    title: 'Biology • Grade 12',
    grade: 'Grade 12',
    subject: 'Biology',
    version: 1,
    itemCount: 8,
    sizeBytes: 24500000,
    downloadedAt: DateTime.now(),
    status: 'downloaded',
    extraData: const {'unitIds': ['u1', 'u2']},
  );

  final samplePractice = DownloadPackageRecord(
    id: 'practice_grade_12_natural_biology_u1_y2017',
    packageType: 'practice',
    title: 'Biology Grade 12 — Unit 1 • 2017 EC',
    grade: 'Grade 12',
    stream: 'natural',
    subject: 'Biology',
    unitNumber: 1,
    unitName: 'Cell Biology',
    examYear: 2017,
    version: 1,
    itemCount: 45,
    sizeBytes: 120000,
    downloadedAt: DateTime.now(),
    status: 'downloaded',
  );

  final samplePastExam = DownloadPackageRecord(
    id: 'past_exam_2017_natural_biology',
    packageType: 'past_exam',
    title: '2017 EC Biology Entrance Exam',
    stream: 'natural',
    subject: 'Biology',
    examYear: 2017,
    version: 1,
    itemCount: 50,
    sizeBytes: 150000,
    downloadedAt: DateTime.now(),
    status: 'downloaded',
  );

  group('DownloadsScreen UI Tests', () {
    testWidgets('Renders storage banner, empty state, and offline activity section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DownloadsScreen(
            initialPackages: [],
            initialStorageBytes: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and storage banner
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Local Storage Used'), findsOneWidget);
      expect(find.text('0 B'), findsOneWidget);
      expect(find.text('Ready Offline'), findsOneWidget);

      // Section title and empty count
      expect(find.text('Downloaded Content'), findsOneWidget);
      expect(find.text('0 packages'), findsOneWidget);

      // Category Tabs
      expect(find.text('Books (0)'), findsOneWidget);
      expect(find.text('Practice (0)'), findsOneWidget);
      expect(find.text('Past Exams (0)'), findsOneWidget);

      // Empty State for Books tab
      expect(find.text('No Books Downloaded'), findsOneWidget);

      // Offline Activity Section
      expect(find.text('Offline Activity'), findsOneWidget);
      expect(find.text('Study Plan'), findsOneWidget);
      expect(find.text('Progress Tracking'), findsOneWidget);
      expect(find.text('Weak Areas Analysis'), findsOneWidget);
      expect(find.text('Personalized Challenges'), findsOneWidget);
      expect(find.text('Offline Ready'), findsNWidgets(4));
    });

    testWidgets('Renders downloaded package cards across tabs accurately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadsScreen(
            initialPackages: [sampleBook, samplePractice, samplePastExam],
            initialStorageBytes: 24770000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Total count and storage
      expect(find.text('3 packages'), findsOneWidget);
      expect(find.text('23.6 MB'), findsOneWidget);

      // Books Tab (Active by default)
      expect(find.text('Biology • Grade 12'), findsOneWidget);
      expect(find.text('8 Units'), findsOneWidget);
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      // Switch to Practice Tab
      await tester.tap(find.text('Practice (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Biology Grade 12 — Unit 1 • 2017 EC'), findsOneWidget);
      expect(find.text('45 Questions'), findsOneWidget);

      // Switch to Past Exams Tab
      await tester.tap(find.text('Past Exams (1)'));
      await tester.pumpAndSettle();
      expect(find.text('2017 EC Biology Entrance Exam'), findsOneWidget);
      expect(find.text('50 Questions'), findsOneWidget);
    });

    testWidgets('Tapping Remove shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadsScreen(
            initialPackages: [sampleBook],
            initialStorageBytes: 24500000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remove'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Remove Download'), findsOneWidget);
      expect(
        find.textContaining('Are you sure you want to remove "Biology • Grade 12"'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Download'), findsNothing);
    });
  });
}
