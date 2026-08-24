import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfReaderScreen extends StatelessWidget {
  final String pdfPath;
  final String title;

  const PdfReaderScreen({
    super.key,
    required this.pdfPath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: PdfViewer.file(pdfPath),
    );
  }
}
