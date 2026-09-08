import 'dart:convert';
import 'dart:typed_data';

import 'package:edurise/features/admin/data/import/practice_bulk_import_models.dart';
import 'package:edurise/features/admin/data/import/practice_bulk_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = PracticeBulkImportService();

  group('PracticeBulkImportService - Parsing & Validation', () {
    test('parses and maps valid practice question row to existing Question model', () {
      const csv = '''
questionId,stream,entrance_year_ec,subject,textbook_grade,textbook_subject,unit_number,unit_name,topic,question,option_a,option_b,option_c,option_d,answer_letter,answer_text,explanation,difficulty,answer_status,image_required,publication_status
bio_2013_q1,Natural Science,2013,Biology,9,Biology,1,Introduction to Biology,Branches,Which field studies heredity?,Taxonomy,Genetics,Ecology,Anatomy,B,Genetics,Genetics is the study of heredity.,Easy,verified,false,published
''';
      final file = QueuedImportFile(
        id: '1',
        name: 'biology_grade9.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final rows = service.parseFile(file);

      expect(rows.length, 1);
      final row = rows.first;

      expect(row.isValid, isTrue);
      expect(row.questionId, 'bio_2013_q1');
      expect(row.grade, 'Grade 9');
      expect(row.subject, 'Biology');
      expect(row.unitNumber, 1);
      expect(row.unitName, 'Introduction to Biology');
      expect(row.examYear, 2013);
      expect(row.correctAnswer, 'B');
      expect(row.options, ['Taxonomy', 'Genetics', 'Ecology', 'Anatomy']);
      expect(row.explanation, 'Genetics is the study of heredity.');
      expect(row.effectiveStatus, 'published');

      // Verify Question model contract compatibility
      final question = row.toQuestion();
      expect(question.id, 'bio_2013_q1');
      expect(question.grade, 'Grade 9');
      expect(question.unitNumber, 1);
      expect(question.correctAnswer, 'B');
      expect(question.status, 'published');
    });

    test('flags validation errors for invalid answer and missing required values', () {
      const csv = '''
questionId,subject,textbook_grade,unit_number,unit_name,question,option_a,option_b,option_c,option_d,answer_letter,explanation
invalid_1,Biology,9,0,Unit Name,Question?,OptA,OptB,OptC,OptD,E,
''';
      final file = QueuedImportFile(
        id: '2',
        name: 'invalid.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final rows = service.parseFile(file);

      expect(rows.length, 1);
      final row = rows.first;

      expect(row.isValid, isFalse);
      expect(row.validationErrors.any((e) => e.contains('Unit number')), isTrue);
      expect(row.validationErrors.any((e) => e.contains('Answer must be A, B, C, or D')), isTrue);
      expect(row.validationErrors.any((e) => e.contains('Explanation is required')), isTrue);
    });

    test('retains draft status when answer_status is rejected or image required is missing', () {
      const csv = '''
questionId,subject,textbook_grade,unit_number,unit_name,question,option_a,option_b,option_c,option_d,answer_letter,explanation,answer_status,image_required
rejected_q,Biology,10,2,Cells,Sample Question,A,B,C,D,A,Sample explanation,rejected,false
img_q,Biology,10,2,Cells,Sample Question 2,A,B,C,D,C,Sample explanation,verified,true
''';
      final file = QueuedImportFile(
        id: '3',
        name: 'status_checks.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final rows = service.parseFile(file);
      expect(rows.length, 2);

      expect(rows[0].effectiveStatus, 'draft');
      expect(rows[0].needsReview, isTrue);

      expect(rows[1].effectiveStatus, 'draft');
      expect(rows[1].needsReview, isTrue);
    });
  });
}
