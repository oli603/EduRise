import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class BookDownloadService {
  Future<Directory> _getBooksDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final booksDirectory = Directory('${appDirectory.path}/edurise_books');

    if (!await booksDirectory.exists()) {
      await booksDirectory.create(recursive: true);
    }

    return booksDirectory;
  }

  Future<File?> getLocalBookFile(String bookId) async {
    final directory = await _getBooksDirectory();

    final file = File('${directory.path}/$bookId.pdf');

    if (await file.exists()) {
      return file;
    }

    return null;
  }

  Future<bool> isDownloaded(String bookId) async {
    final file = await getLocalBookFile(bookId);
    return file != null;
  }

  Future<File> downloadBook({
    required String bookId,
    required String pdfUrl,
    void Function(double progress)? onProgress,
  }) async {
    final directory = await _getBooksDirectory();

    final file = File('${directory.path}/$bookId.pdf');

    final response = await http.Client().send(
      http.Request('GET', Uri.parse(pdfUrl)),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download PDF. Status code: ${response.statusCode}',
      );
    }

    final totalBytes = response.contentLength ?? 0;
    var downloadedBytes = 0;

    final sink = file.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);

        downloadedBytes += chunk.length;

        if (totalBytes > 0) {
          onProgress?.call(downloadedBytes / totalBytes);
        }
      }
    } finally {
      await sink.close();
    }

    return file;
  }

  Future<void> deleteBook(String bookId) async {
    final file = await getLocalBookFile(bookId);

    if (file != null) {
      await file.delete();
    }
  }
}
