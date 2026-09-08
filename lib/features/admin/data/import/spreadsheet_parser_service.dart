import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';

/// Service responsible for parsing .csv and .xlsx spreadsheets into raw rows of text.
class SpreadsheetParserService {
  /// Parses bytes into a table of string cells [rows x columns].
  static List<List<String>> parseSpreadsheet({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.csv')) {
      return parseCsv(bytes);
    } else if (lowerName.endsWith('.xlsx')) {
      return parseXlsx(bytes);
    } else {
      throw FormatException(
        'Unsupported file type for "$fileName". Supported formats are .xlsx and .csv.',
      );
    }
  }

  /// Parses CSV bytes with BOM removal, encoding fallback, and CSV dialect tolerance.
  static List<List<String>> parseCsv(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    // Strip UTF-8 BOM if present
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    if (content.trim().isEmpty) {
      return [];
    }

    // Use modern csv 8.0 API with auto-detection and string-preservation
    final parser = Csv(
      autoDetect: true,
      dynamicTyping: false,
      skipEmptyLines: true,
    );

    final dynamic decoded = parser.decode(content);
    final rawRows = <List<String>>[];

    if (decoded is List) {
      for (final dynamic row in decoded) {
        if (row is Iterable) {
          final rowStrings = row.map((dynamic cell) => cell?.toString().trim() ?? '').toList();
          if (rowStrings.any((c) => c.isNotEmpty)) {
            rawRows.add(rowStrings);
          }
        }
      }
    }

    return rawRows;
  }

  /// Parses XLSX OpenXML ZIP archive bytes into rows.
  static List<List<String>> parseXlsx(Uint8List bytes) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw FormatException('Invalid or corrupted .xlsx file: $e');
    }

    // 1. Extract shared strings (xl/sharedStrings.xml)
    final sharedStrings = <String>[];
    final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      try {
        final xmlContent = utf8.decode(sharedStringsFile.content as List<int>);
        final document = XmlDocument.parse(xmlContent);

        for (final si in document.findAllElements('si')) {
          // A string item can contain direct <t> or multiple rich text runs <r><t>
          final buffer = StringBuffer();
          for (final t in si.findAllElements('t')) {
            buffer.write(t.innerText);
          }
          sharedStrings.add(buffer.toString());
        }
      } catch (e) {
        // Fallback: continue without shared strings
      }
    }

    // 2. Locate first worksheet (xl/worksheets/sheet1.xml)
    ArchiveFile? sheetFile;
    for (final file in archive.files) {
      if (file.name.toLowerCase().startsWith('xl/worksheets/sheet') &&
          file.name.toLowerCase().endsWith('.xml')) {
        sheetFile = file;
        break;
      }
    }

    if (sheetFile == null) {
      throw const FormatException('Could not locate a worksheet inside the .xlsx file.');
    }

    final sheetXml = utf8.decode(sheetFile.content as List<int>);
    final sheetDoc = XmlDocument.parse(sheetXml);

    final resultRows = <List<String>>[];

    for (final rowElem in sheetDoc.findAllElements('row')) {
      final cellMap = <int, String>{};
      int maxCol = -1;

      for (final cellElem in rowElem.findElements('c')) {
        final rAttr = cellElem.getAttribute('r'); // e.g. "B3"
        int colIndex;
        if (rAttr != null) {
          colIndex = _columnRefToIndex(rAttr);
        } else {
          colIndex = maxCol + 1;
        }

        if (colIndex > maxCol) {
          maxCol = colIndex;
        }

        final typeAttr = cellElem.getAttribute('t'); // "s" for shared string, "b" for bool, "inlineStr"
        String value = '';

        if (typeAttr == 's') {
          final vElem = cellElem.getElement('v');
          if (vElem != null) {
            final sIndex = int.tryParse(vElem.innerText.trim());
            if (sIndex != null && sIndex >= 0 && sIndex < sharedStrings.length) {
              value = sharedStrings[sIndex];
            }
          }
        } else if (typeAttr == 'inlineStr') {
          final isElem = cellElem.getElement('is');
          if (isElem != null) {
            value = isElem.findAllElements('t').map((e) => e.innerText).join();
          }
        } else if (typeAttr == 'b') {
          final vElem = cellElem.getElement('v');
          value = (vElem?.innerText.trim() == '1') ? 'true' : 'false';
        } else {
          final vElem = cellElem.getElement('v');
          value = vElem?.innerText.trim() ?? '';
        }

        cellMap[colIndex] = value.trim();
      }

      if (maxCol >= 0) {
        final rowData = List<String>.generate(
          maxCol + 1,
          (i) => cellMap[i] ?? '',
        );

        // Include row if at least one cell has content
        if (rowData.any((c) => c.isNotEmpty)) {
          resultRows.add(rowData);
        }
      }
    }

    return resultRows;
  }

  /// Helper converting an Excel cell reference (e.g. "C12", "AA4") to a 0-indexed column index.
  static int _columnRefToIndex(String cellRef) {
    final letters = cellRef.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (letters.isEmpty) return 0;

    int col = 0;
    for (int i = 0; i < letters.length; i++) {
      col = col * 26 + (letters.codeUnitAt(i) - 64);
    }
    return col - 1;
  }
}
