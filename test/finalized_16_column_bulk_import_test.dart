import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edurise/features/admin/data/import/practice_bulk_import_models.dart';
import 'package:edurise/features/admin/data/import/practice_bulk_import_service.dart';
import 'package:edurise/features/admin/data/import/spreadsheet_parser_service.dart';
import 'package:edurise/features/admin/presentation/import_past_exams_screen.dart';
import 'package:edurise/features/admin/presentation/import_practice_questions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = PracticeBulkImportService();

  group('Finalized 16-Column EduRise Format - Parsing & Mapping', () {
    test('parses all 16 columns correctly for Natural & Social science rows', () {
      const csv = '''question_number,stream,textbook_grade,subject,unit_number,unit_name,question_text,option_a,option_b,option_c,option_d,answer_letter,explanation,entrance_year_ec,exam_type,status
1,natural,9,Biology,1,Introduction to Biology,What is cytology?,Study of cells,Study of tissues,Study of organs,Study of genes,A,Cytology is the study of cells.,2013,Practice Question,published
2,social,11,Geography,2,Physical Geography,What causes day and night?,Earth rotation,Earth revolution,Moon rotation,Solar flares,A,The rotation of the Earth on its axis causes day and night.,2014,Model Exam,review
''';

      final file = QueuedImportFile(
        id: 'f_16col',
        name: 'sample_16_columns.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final rows = service.parseFile(file);

      expect(rows.length, 2);

      // Row 1: Natural Science row
      final r1 = rows[0];
      expect(r1.isValid, isTrue);
      expect(r1.questionNumber, 1);
      expect(r1.stream, 'natural');
      expect(r1.grade, 'Grade 9');
      expect(r1.subject, 'Biology');
      expect(r1.unitNumber, 1);
      expect(r1.unitName, 'Introduction to Biology');
      expect(r1.question, 'What is cytology?');
      expect(r1.optionA, 'Study of cells');
      expect(r1.optionB, 'Study of tissues');
      expect(r1.optionC, 'Study of organs');
      expect(r1.optionD, 'Study of genes');
      expect(r1.correctAnswer, 'A');
      expect(r1.explanation, 'Cytology is the study of cells.');
      expect(r1.examYear, 2013);
      expect(r1.examType, 'Practice Question');
      expect(r1.publicationStatus, 'published');
      expect(r1.effectiveStatus, 'published');

      final q1 = r1.toQuestion();
      expect(q1.questionNumber, 1);
      expect(q1.stream, 'natural');
      expect(q1.grade, 'Grade 9');
      expect(q1.subject, 'Biology');
      expect(q1.unitNumber, 1);
      expect(q1.unitName, 'Introduction to Biology');
      expect(q1.examYear, 2013);
      expect(q1.examType, 'Practice Question');
      expect(q1.status, 'published');

      // Row 2: Social Science row with 'review' status
      final r2 = rows[1];
      expect(r2.isValid, isTrue);
      expect(r2.questionNumber, 2);
      expect(r2.stream, 'social');
      expect(r2.grade, 'Grade 11');
      expect(r2.subject, 'Geography');
      expect(r2.unitNumber, 2);
      expect(r2.unitName, 'Physical Geography');
      expect(r2.correctAnswer, 'A');
      expect(r2.examYear, 2014);
      expect(r2.examType, 'Model Exam');
      expect(r2.publicationStatus, 'draft'); // 'review' maps to 'draft' in effectiveStatus
      expect(r2.effectiveStatus, 'draft');

      final q2 = r2.toQuestion();
      expect(q2.questionNumber, 2);
      expect(q2.stream, 'social');
      expect(q2.grade, 'Grade 11');
      expect(q2.examType, 'Model Exam');
      expect(q2.status, 'draft');
    });

    test('strictly validates stream: allows natural/social, rejects invalid streams', () {
      const csv = '''question_number,stream,textbook_grade,subject,unit_number,unit_name,question_text,option_a,option_b,option_c,option_d,answer_letter,explanation,entrance_year_ec,exam_type,status
1,Natural Science,9,Biology,1,Unit 1,Question 1?,A,B,C,D,A,Explanation 1,2013,Practice,published
2,general,9,Biology,1,Unit 1,Question 2?,A,B,C,D,B,Explanation 2,2013,Practice,published
3,invalid_stream,9,Biology,1,Unit 1,Question 3?,A,B,C,D,C,Explanation 3,2013,Practice,published
''';

      final file = QueuedImportFile(
        id: 'f_stream',
        name: 'stream_validation.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final rows = service.parseFile(file);
      expect(rows.length, 3);

      expect(rows[0].isValid, isTrue);
      expect(rows[0].stream, 'natural');

      expect(rows[1].isValid, isFalse);
      expect(rows[1].validationErrors.any((e) => e.contains('Stream must be either "natural" or "social"')), isTrue);

      expect(rows[2].isValid, isFalse);
      expect(rows[2].validationErrors.any((e) => e.contains('Stream must be either "natural" or "social"')), isTrue);
    });

    test('strictly validates textbook_grade: allows 9, 10, 11, 12, rejects others', () {
      const csv = '''question_number,stream,textbook_grade,subject,unit_number,unit_name,question_text,option_a,option_b,option_c,option_d,answer_letter,explanation,entrance_year_ec,exam_type,status
1,natural,9,Biology,1,Unit 1,Q1?,A,B,C,D,A,Exp 1,2013,Practice,published
2,natural,10,Biology,1,Unit 1,Q2?,A,B,C,D,B,Exp 2,2013,Practice,published
3,social,11,History,1,Unit 1,Q3?,A,B,C,D,C,Exp 3,2013,Practice,published
4,social,12,Economics,1,Unit 1,Q4?,A,B,C,D,D,Exp 4,2013,Practice,published
5,natural,8,Biology,1,Unit 1,Q5?,A,B,C,D,A,Exp 5,2013,Practice,published
6,natural,13,Biology,1,Unit 1,Q6?,A,B,C,D,B,Exp 6,2013,Practice,published
''';

      final file = QueuedImportFile(
        id: 'f_grade',
        name: 'grade_validation.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final rows = service.parseFile(file);
      expect(rows.length, 6);

      expect(rows[0].isValid, isTrue);
      expect(rows[0].grade, 'Grade 9');

      expect(rows[1].isValid, isTrue);
      expect(rows[1].grade, 'Grade 10');

      expect(rows[2].isValid, isTrue);
      expect(rows[2].grade, 'Grade 11');

      expect(rows[3].isValid, isTrue);
      expect(rows[3].grade, 'Grade 12');

      expect(rows[4].isValid, isFalse);
      expect(rows[4].validationErrors.any((e) => e.contains('Textbook grade must be 9, 10, 11, or 12')), isTrue);

      expect(rows[5].isValid, isFalse);
      expect(rows[5].validationErrors.any((e) => e.contains('Textbook grade must be 9, 10, 11, or 12')), isTrue);
    });

    test('strictly preserves question_number from cell and generates readable questionId', () {
      const csv = '''question_number,stream,textbook_grade,subject,unit_number,unit_name,question_text,option_a,option_b,option_c,option_d,answer_letter,explanation
94,natural,12,Physics,4,Electromagnetism,What is magnetic flux?,Weber,Tesla,Volt,Ohm,A,Magnetic flux is measured in Webers.
''';

      final file = QueuedImportFile(
        id: 'f_qnum',
        name: 'qnum.csv',
        size: csv.length,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      final rows = service.parseFile(file);
      expect(rows.length, 1);
      final r = rows.first;

      expect(r.isValid, isTrue);
      expect(r.questionNumber, 94);
      // Clean readable generated ID without error or warning
      expect(r.questionId, 'q_grade12_natural_physics_u4_q94');
      expect(r.validationWarnings.isEmpty, isTrue);
    });
  });

  group('Real OpenXML .xlsx Parser & Import', () {
    test('parses real binary .xlsx archive with 16 columns', () {
      // Build a valid OpenXML XLSX archive with shared strings and sheet1.xml
      final sharedStringsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="17" uniqueCount="17">
  <si><t>question_number</t></si>
  <si><t>stream</t></si>
  <si><t>textbook_grade</t></si>
  <si><t>subject</t></si>
  <si><t>unit_number</t></si>
  <si><t>unit_name</t></si>
  <si><t>question_text</t></si>
  <si><t>option_a</t></si>
  <si><t>option_b</t></si>
  <si><t>option_c</t></si>
  <si><t>option_d</t></si>
  <si><t>answer_letter</t></si>
  <si><t>explanation</t></si>
  <si><t>entrance_year_ec</t></si>
  <si><t>exam_type</t></si>
  <si><t>status</t></si>
  <si><t>Cell Biology</t></si>
</sst>''';

      final sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
      <c r="C1" t="s"><v>2</v></c>
      <c r="D1" t="s"><v>3</v></c>
      <c r="E1" t="s"><v>4</v></c>
      <c r="F1" t="s"><v>5</v></c>
      <c r="G1" t="s"><v>6</v></c>
      <c r="H1" t="s"><v>7</v></c>
      <c r="I1" t="s"><v>8</v></c>
      <c r="J1" t="s"><v>9</v></c>
      <c r="K1" t="s"><v>10</v></c>
      <c r="L1" t="s"><v>11</v></c>
      <c r="M1" t="s"><v>12</v></c>
      <c r="N1" t="s"><v>13</v></c>
      <c r="O1" t="s"><v>14</v></c>
      <c r="P1" t="s"><v>15</v></c>
    </row>
    <row r="2">
      <c r="A2"><v>1</v></c>
      <c r="B2" t="inlineStr"><is><t>natural</t></is></c>
      <c r="C2"><v>9</v></c>
      <c r="D2" t="inlineStr"><is><t>Biology</t></is></c>
      <c r="E2"><v>1</v></c>
      <c r="F2" t="s"><v>16</v></c>
      <c r="G2" t="inlineStr"><is><t>What is the powerhouse of the cell?</t></is></c>
      <c r="H2" t="inlineStr"><is><t>Mitochondria</t></is></c>
      <c r="I2" t="inlineStr"><is><t>Nucleus</t></is></c>
      <c r="J2" t="inlineStr"><is><t>Ribosome</t></is></c>
      <c r="K2" t="inlineStr"><is><t>Golgi body</t></is></c>
      <c r="L2" t="inlineStr"><is><t>A</t></is></c>
      <c r="M2" t="inlineStr"><is><t>Mitochondria generate most ATP cellular energy.</t></is></c>
      <c r="N2"><v>2013</v></c>
      <c r="O2" t="inlineStr"><is><t>Practice Question</t></is></c>
      <c r="P2" t="inlineStr"><is><t>published</t></is></c>
    </row>
  </sheetData>
</worksheet>''';

      final archive = Archive();
      archive.addFile(ArchiveFile('xl/sharedStrings.xml', sharedStringsXml.length, utf8.encode(sharedStringsXml)));
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));

      final xlsxBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      // Verify SpreadsheetParserService can parse this XLSX
      final rawRows = SpreadsheetParserService.parseXlsx(xlsxBytes);
      expect(rawRows.length, 2);
      expect(rawRows[0][0], 'question_number');
      expect(rawRows[0][1], 'stream');
      expect(rawRows[1][0], '1');
      expect(rawRows[1][1], 'natural');
      expect(rawRows[1][6], 'What is the powerhouse of the cell?');

      // Verify PracticeBulkImportService can parse file end-to-end
      final queuedFile = QueuedImportFile(
        id: 'xlsx_test_file',
        name: 'biology_grade9.xlsx',
        size: xlsxBytes.length,
        bytes: xlsxBytes,
      );

      final parsed = service.parseFile(queuedFile);
      expect(parsed.length, 1);
      final r = parsed.first;
      expect(r.isValid, isTrue);
      expect(r.questionNumber, 1);
      expect(r.stream, 'natural');
      expect(r.grade, 'Grade 9');
      expect(r.subject, 'Biology');
      expect(r.unitNumber, 1);
      expect(r.unitName, 'Cell Biology');
      expect(r.question, 'What is the powerhouse of the cell?');
      expect(r.optionA, 'Mitochondria');
      expect(r.correctAnswer, 'A');
      expect(r.explanation, 'Mitochondria generate most ATP cellular energy.');
      expect(r.effectiveStatus, 'published');

      final q = r.toQuestion();
      expect(q.id, 'q_grade9_natural_biology_u1_q1');
      expect(q.status, 'published');
    });
  });

  group('Layout Overflow Verification on Mobile Viewport (360x640)', () {
    testWidgets('ImportPracticeQuestionsScreen has no horizontal overflow in Step 3 info banner', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ImportPracticeQuestionsScreen(),
        ),
      );

      // Verify screen renders cleanly
      expect(find.text('Import Practice Questions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ImportPastExamsScreen has no horizontal overflow in Step 3 info banner', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ImportPastExamsScreen(),
        ),
      );

      expect(find.text('Import Past Entrance Exams'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
