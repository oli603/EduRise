import 'dart:convert';
import 'dart:typed_data';

import 'package:edurise/features/admin/data/import/past_exam_bulk_import_service.dart';
import 'package:edurise/features/admin/data/import/practice_bulk_import_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = PastExamBulkImportService();

  group('PastExamBulkImportService - Order Preservation & Validation', () {
    test('strictly preserves Q1 -> Q2 -> Q3 question order and numbers', () {
      // Intentionally provide rows out of order in CSV
      const csv = '''
package_id,entrance_year_ec,subject,stream,round,question_number,question,option_a,option_b,option_c,option_d,answer_letter,answer_text,explanation
bio_2013,2013,Biology,Natural Science,Round 1,3,Question Three,A3,B3,C3,D3,C,Text3,Explanation Three
bio_2013,2013,Biology,Natural Science,Round 1,1,Question One,A1,B1,C1,D1,A,Text1,Explanation One
bio_2013,2013,Biology,Natural Science,Round 1,2,Question Two,A2,B2,C2,D2,B,Text2,Explanation Two
''';

      final file = QueuedImportFile(
        id: '1',
        name: 'Biology_2013.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final packages = service.parseFile(file);

      expect(packages.length, 1);
      final pkg = packages.first;

      expect(pkg.packageId, 'bio_2013');
      expect(pkg.year, '2013');
      expect(pkg.subject, 'Biology');
      expect(pkg.stream, 'Natural Science');
      expect(pkg.round, 'Round 1');
      expect(pkg.totalQuestions, 3);
      expect(pkg.isPackageValid, isTrue);

      // Verify strict question order: Q1 -> Q2 -> Q3
      final ordered = pkg.getOrderedQuestions();
      expect(ordered.length, 3);
      expect(ordered[0].questionNumber, 1);
      expect(ordered[0].questionText, 'Question One');
      expect(ordered[0].correctAnswer, 'A');

      expect(ordered[1].questionNumber, 2);
      expect(ordered[1].questionText, 'Question Two');
      expect(ordered[1].correctAnswer, 'B');

      expect(ordered[2].questionNumber, 3);
      expect(ordered[2].questionText, 'Question Three');
      expect(ordered[2].correctAnswer, 'C');

      // Verify toPastExam() model conversion
      final exam = pkg.toPastExam();
      expect(exam.id, 'bio_2013');
      expect(exam.questions.first.questionNumber, 1);
      expect(exam.questions.last.questionNumber, 3);
    });

    test('flags duplicate question numbers inside an exam package', () {
      const csv = '''
entrance_year_ec,subject,stream,question_number,question,option_a,option_b,option_c,option_d,answer_letter,explanation
2014,Chemistry,Natural Science,1,Q One,A,B,C,D,A,Exp 1
2014,Chemistry,Natural Science,1,Duplicate Q One,A,B,C,D,B,Exp 2
''';
      final file = QueuedImportFile(
        id: '2',
        name: 'Chemistry_2014.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final packages = service.parseFile(file);
      expect(packages.length, 1);
      final pkg = packages.first;

      expect(pkg.isPackageValid, isFalse);
      expect(pkg.rows.any((r) => r.validationErrors.any((e) => e.contains('Duplicate question number'))), isTrue);
    });
  });
}
