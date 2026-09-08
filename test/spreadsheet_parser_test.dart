import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edurise/features/admin/data/import/spreadsheet_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpreadsheetParserService - CSV', () {
    test('parses basic comma-separated rows with trim', () {
      const csvData = '''
questionId,subject,grade,unit_number,unit_name
bio_2013_q1, Biology , Grade 9 , 1 , Introduction to Biology 
bio_2013_q2, Biology , Grade 9 , 1 , Cells
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final rows = SpreadsheetParserService.parseSpreadsheet(
        bytes: bytes,
        fileName: 'test.csv',
      );

      expect(rows.length, 3);
      expect(rows[0], ['questionId', 'subject', 'grade', 'unit_number', 'unit_name']);
      expect(rows[1], ['bio_2013_q1', 'Biology', 'Grade 9', '1', 'Introduction to Biology']);
      expect(rows[2], ['bio_2013_q2', 'Biology', 'Grade 9', '1', 'Cells']);
    });

    test('handles quoted strings containing commas', () {
      const csvData = 'id,question,answer\n1,"Which cell organelle, if damaged, stops respiration?",Mitochondria';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final rows = SpreadsheetParserService.parseSpreadsheet(
        bytes: bytes,
        fileName: 'quotes.csv',
      );

      expect(rows.length, 2);
      expect(rows[1][1], 'Which cell organelle, if damaged, stops respiration?');
    });

    test('tolerates UTF-8 BOM', () {
      const csvData = '\uFEFFcol1,col2\nval1,val2';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final rows = SpreadsheetParserService.parseSpreadsheet(
        bytes: bytes,
        fileName: 'bom.csv',
      );

      expect(rows.first[0], 'col1');
    });
  });

  group('SpreadsheetParserService - XLSX', () {
    test('parses minimal OpenXML zip archive', () {
      // Build a synthetic XLSX structure in memory
      final archive = Archive();

      const sharedStringsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="4" uniqueCount="4">
  <si><t>questionId</t></si>
  <si><t>subject</t></si>
  <si><t>bio_2013_q1</t></si>
  <si><t>Biology</t></si>
</sst>''';

      const sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>2</v></c>
      <c r="B2" t="s"><v>3</v></c>
    </row>
  </sheetData>
</worksheet>''';

      final ssBytes = utf8.encode(sharedStringsXml);
      archive.addFile(ArchiveFile('xl/sharedStrings.xml', ssBytes.length, ssBytes));

      final sheetBytes = utf8.encode(sheetXml);
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetBytes.length, sheetBytes));

      final xlsxBytes = ZipEncoder().encode(archive);
      final rows = SpreadsheetParserService.parseSpreadsheet(
        bytes: Uint8List.fromList(xlsxBytes),
        fileName: 'sample.xlsx',
      );

      expect(rows.length, 2);
      expect(rows[0], ['questionId', 'subject']);
      expect(rows[1], ['bio_2013_q1', 'Biology']);
    });
  });
}
