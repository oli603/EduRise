import 'dart:convert';
import 'dart:typed_data';

import 'package:edurise/features/admin/data/import/past_exam_bulk_import_service.dart';
import 'package:edurise/features/admin/data/import/practice_bulk_import_models.dart';
import 'package:edurise/features/admin/data/import/practice_bulk_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bulk Import Final Acceptance Tests', () {
    final practiceService = PracticeBulkImportService();
    final examService = PastExamBulkImportService();

    test('Practice Acceptance Test: 5 questions in Biology Grade 9 Unit 1 2013', () {
      const csvContent = '''
questionId,stream,entrance_year_ec,subject,textbook_grade,textbook_subject,unit_number,unit_name,topic,question,option_a,option_b,option_c,option_d,answer_letter,explanation
bio_2013_q1,Natural Science,2013,Biology,Grade 9,Biology,1,Introduction to Biology,Branches,What is cytology?,Study of cells,Study of tissues,Study of organs,Study of genes,A,Cytology is the branch of biology studying cells.
bio_2013_q2,Natural Science,2013,Biology,Grade 9,Biology,1,Introduction to Biology,Branches,What is histology?,Study of cells,Study of tissues,Study of organs,Study of plants,B,Histology studies tissues.
bio_2013_q3,Natural Science,2013,Biology,Grade 9,Biology,1,Introduction to Biology,Microscope,Who discovered the cell?,Robert Hooke,Antonie van Leeuwenhoek,Louis Pasteur,Charles Darwin,A,Robert Hooke discovered cells in 1665.
bio_2013_q4,Natural Science,2013,Biology,Grade 9,Biology,1,Introduction to Biology,Tools,Which instrument magnifies minute objects?,Telescope,Microscope,Periscope,Stethoscope,B,Microscopes magnify tiny organisms.
bio_2013_q5,Natural Science,2013,Biology,Grade 9,Biology,1,Introduction to Biology,Ethics,Which rule ensures safety in biological labs?,Wash hands,Eat snacks,Run fast,Ignore spills,A,Safety guidelines require washing hands.
''';

      final file = QueuedImportFile(
        id: 'file_practice_1',
        name: 'Biology_Grade9_Unit1.csv',
        size: csvContent.length,
        bytes: Uint8List.fromList(utf8.encode(csvContent)),
      );

      final rows = practiceService.parseFile(file);

      expect(rows.length, 5);
      expect(rows.every((r) => r.isValid), isTrue);
      expect(file.validRowsCount, 5);
      expect(file.invalidRowsCount, 0);

      // Verify that the produced documents strictly fulfill the existing Practice contract
      final questions = rows.map((r) => r.toQuestion()).toList();
      for (final q in questions) {
        expect(q.grade, 'Grade 9');
        expect(q.subject, 'Biology');
        expect(q.unitNumber, 1);
        expect(q.unitName, 'Introduction to Biology');
        expect(q.examYear, 2013);
        expect(q.options.length, 4);
        expect(['A', 'B', 'C', 'D'].contains(q.correctAnswer), isTrue);
        expect(q.explanation.isNotEmpty, isTrue);
        expect(q.status, 'published');
      }

      // Simulate student answering flow
      final q1 = questions[0];
      // Answering correctly
      expect('A' == q1.correctAnswer, isTrue);
      expect(q1.explanation, 'Cytology is the branch of biology studying cells.');

      // Answering incorrectly
      expect('C' == q1.correctAnswer, isFalse);
      expect(q1.correctAnswer, 'A');
    });

    test('All Years Acceptance Test: Returns questions across multiple years (2013, 2014, 2015, 2016)', () {
      const csvMultiYear = '''
questionId,stream,entrance_year_ec,subject,textbook_grade,unit_number,unit_name,question,option_a,option_b,option_c,option_d,answer_letter,explanation
bio_2013_q1,Natural Science,2013,Biology,Grade 9,1,Unit 1,Q 2013,A,B,C,D,A,Exp 2013
bio_2014_q1,Natural Science,2014,Biology,Grade 9,1,Unit 1,Q 2014,A,B,C,D,B,Exp 2014
bio_2015_q1,Natural Science,2015,Biology,Grade 9,1,Unit 1,Q 2015,A,B,C,D,C,Exp 2015
bio_2016_q1,Natural Science,2016,Biology,Grade 9,1,Unit 1,Q 2016,A,B,C,D,D,Exp 2016
''';
      final file = QueuedImportFile(
        id: 'multi_year',
        name: 'Biology_All_Years.csv',
        size: csvMultiYear.length,
        bytes: Uint8List.fromList(utf8.encode(csvMultiYear)),
      );

      final rows = practiceService.parseFile(file);
      final questions = rows.map((r) => r.toQuestion()).toList();

      final years = questions.map((q) => q.examYear).toSet();
      expect(years, {2013, 2014, 2015, 2016});

      // Confirm all 4 questions share the same Grade 9 Biology Unit 1
      expect(questions.every((q) => q.grade == 'Grade 9' && q.subject == 'Biology' && q.unitNumber == 1), isTrue);
    });

    test('Past Exam Acceptance Test: Question numbers and sequence preserved strictly', () {
      const examCsv = '''
package_id,entrance_year_ec,subject,stream,round,question_number,question,option_a,option_b,option_c,option_d,answer_letter,explanation
Biology_2013,2013,Biology,Natural Science,,4,Fourth Question,A4,B4,C4,D4,D,Explanation 4
Biology_2013,2013,Biology,Natural Science,,1,First Question,A1,B1,C1,D1,A,Explanation 1
Biology_2013,2013,Biology,Natural Science,,3,Third Question,A3,B3,C3,D3,C,Explanation 3
Biology_2013,2013,Biology,Natural Science,,2,Second Question,A2,B2,C2,D2,B,Explanation 2
Biology_2013,2013,Biology,Natural Science,,5,Fifth Question,A5,B5,C5,D5,A,Explanation 5
''';

      final file = QueuedImportFile(
        id: 'past_exam_file',
        name: 'Biology_2013.csv',
        size: examCsv.length,
        bytes: Uint8List.fromList(utf8.encode(examCsv)),
      );

      final packages = examService.parseFile(file);
      expect(packages.length, 1);

      final pkg = packages.first;
      final orderedQuestions = pkg.getOrderedQuestions();

      expect(orderedQuestions.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(orderedQuestions[i].questionNumber, i + 1);
      }
      expect(orderedQuestions[0].questionText, 'First Question');
      expect(orderedQuestions[4].questionText, 'Fifth Question');
    });

    test('Multi-File Queue Acceptance Test: Multiple files queued and validated without individual upload', () {
      final file1 = QueuedImportFile(
        id: 'f1',
        name: 'Biology_2013.csv',
        size: 100,
        bytes: Uint8List.fromList(utf8.encode('question,answer_letter,option_a,option_b,option_c,option_d,explanation\nQ1,A,A,B,C,D,Exp')),
      );
      final file2 = QueuedImportFile(
        id: 'f2',
        name: 'Biology_2014.csv',
        size: 100,
        bytes: Uint8List.fromList(utf8.encode('question,answer_letter,option_a,option_b,option_c,option_d,explanation\nQ2,B,A,B,C,D,Exp')),
      );
      final file3 = QueuedImportFile(
        id: 'f3',
        name: 'Chemistry_2013.csv',
        size: 100,
        bytes: Uint8List.fromList(utf8.encode('question,answer_letter,option_a,option_b,option_c,option_d,explanation\nQ3,C,A,B,C,D,Exp')),
      );

      final queue = [file1, file2, file3];

      // Files remain in queue
      expect(queue.length, 3);
      expect(queue.every((f) => f.status == ImportFileStatus.ready), isTrue);

      // Validate all without premature Firestore write
      for (final f in queue) {
        practiceService.parseFile(f);
      }

      expect(queue[0].practiceRows.length, 1);
      expect(queue[1].practiceRows.length, 1);
      expect(queue[2].practiceRows.length, 1);
    });
  });
}
