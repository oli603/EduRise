import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/download_manager.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/books/data/book_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Book Package Identity and Metadata Tests', () {
    final downloadManager = DownloadManager();

    test('Book package identity is deterministic and represents complete book (grade + subject)', () {
      final id1 = downloadManager.getBookPackageId(grade: 'Grade 12', subject: 'Biology');
      final id2 = downloadManager.getBookPackageId(grade: ' Grade 12 ', subject: 'biology');
      final id3 = downloadManager.getBookPackageId(grade: 'grade_12', subject: 'Chemistry');

      expect(id1, 'book_grade_12_biology');
      expect(id2, 'book_grade_12_biology');
      expect(id3, 'book_grade_12_chemistry');
    });

    test('Book DownloadPackageRecord serializes multi-unit book accurately', () {
      final now = DateTime.now();
      const unitsList = [
        {'id': 'u1', 'grade': 'Grade 12', 'subject': 'Biology', 'unitNumber': 1, 'unitName': 'Unit 1'},
        {'id': 'u2', 'grade': 'Grade 12', 'subject': 'Biology', 'unitNumber': 2, 'unitName': 'Unit 2'},
        {'id': 'u3', 'grade': 'Grade 12', 'subject': 'Biology', 'unitNumber': 3, 'unitName': 'Unit 3'},
      ];

      final record = DownloadPackageRecord(
        id: 'book_grade_12_biology',
        packageType: 'book',
        title: 'Biology • Grade 12',
        grade: 'Grade 12',
        subject: 'Biology',
        version: 1,
        itemCount: 3,
        sizeBytes: 18500000,
        downloadedAt: now,
        status: 'downloaded',
        extraData: const {
          'unitIds': ['u1', 'u2', 'u3'],
          'units': unitsList,
          'downloadedCount': 3,
          'totalCount': 3,
        },
      );

      final map = record.toMap();
      final recreated = DownloadPackageRecord.fromMap(map);

      expect(recreated.id, 'book_grade_12_biology');
      expect(recreated.packageType, 'book');
      expect(recreated.itemCount, 3);
      expect(recreated.sizeBytes, 18500000);
      expect(recreated.status, 'downloaded');
      expect(recreated.extraData['unitIds'], ['u1', 'u2', 'u3']);
      expect((recreated.extraData['units'] as List).length, 3);
    });
  });

  group('Partial Download, Retry & Offline Fallback Tests', () {
    test('Partial download records failed status and tracks completed units', () {
      final record = DownloadPackageRecord(
        id: 'book_grade_12_biology',
        packageType: 'book',
        title: 'Biology • Grade 12',
        grade: 'Grade 12',
        subject: 'Biology',
        itemCount: 8,
        sizeBytes: 12000000,
        downloadedAt: DateTime.now(),
        status: 'failed',
        extraData: const {
          'unitIds': ['u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8'],
          'downloadedCount': 6,
          'totalCount': 8,
          'lastError': 'SocketException: Network unreachable',
        },
      );

      expect(record.status, 'failed');
      expect(record.extraData['downloadedCount'], 6);
      expect(record.extraData['totalCount'], 8);

      // On retry, after all 8 succeed, update to downloaded
      final updated = record.copyWith(
        status: 'downloaded',
        sizeBytes: 16000000,
        extraData: {
          ...record.extraData,
          'downloadedCount': 8,
          'lastError': null,
        },
      );

      expect(updated.status, 'downloaded');
      expect(updated.extraData['downloadedCount'], 8);
    });

    test('BookUnit model serialization and deserialization', () {
      final unit = BookUnit(
        id: 'unit_bio_1',
        grade: 'Grade 12',
        subject: 'Biology',
        unitNumber: 1,
        unitName: 'Applications of Biology',
        pdfUrl: 'https://example.com/bio1.pdf',
      );

      final map = unit.toMap();
      final recreated = BookUnit.fromMap('unit_bio_1', map);

      expect(recreated.id, 'unit_bio_1');
      expect(recreated.grade, 'Grade 12');
      expect(recreated.subject, 'Biology');
      expect(recreated.unitNumber, 1);
      expect(recreated.unitName, 'Applications of Biology');
      expect(recreated.pdfUrl, 'https://example.com/bio1.pdf');
    });
  });
}
