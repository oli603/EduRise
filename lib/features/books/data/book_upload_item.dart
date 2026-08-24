import 'dart:io';

class BookUploadItem {
  final int unitNumber;
  final String unitName;
  final File pdfFile;

  const BookUploadItem({
    required this.unitNumber,
    required this.unitName,
    required this.pdfFile,
  });
}
