import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/offline/storage_engine.dart';
import 'book_download_service.dart';
import 'book_model.dart';

class BookTextResult {
  final String text;
  final bool isScannedOnly;
  final bool hasPdf;
  final String? errorMessage;

  const BookTextResult({
    required this.text,
    this.isScannedOnly = false,
    this.hasPdf = true,
    this.errorMessage,
  });

  bool get hasUsableText => text.trim().length >= 50 && !isScannedOnly;
}

/// Service responsible for extracting, caching, and serving authoritative
/// textbook unit text from downloaded unit PDFs for EduRise AI features.
class BookTextService {
  static final BookTextService _instance = BookTextService._internal();
  factory BookTextService() => _instance;
  BookTextService._internal();

  final StorageEngine _storageEngine = StorageEngine.instance;
  final BookDownloadService _downloadService = BookDownloadService();

  // In-memory cache for fast repeated access during a study session
  final Map<String, String> _memoryTextCache = {};

  /// Retrieves extracted text for a book unit.
  /// Priority:
  /// 1. Memory cache
  /// 2. Atomic disk cache (book_text_cache.json)
  /// 3. Physical PDF text extraction via pdfrx
  Future<BookTextResult> getUnitText(BookUnit unit) async {
    final unitId = unit.id;

    // 1. Check memory cache
    if (_memoryTextCache.containsKey(unitId)) {
      final cached = _memoryTextCache[unitId]!;
      if (cached.trim().length < 50) {
        return const BookTextResult(text: '', isScannedOnly: true);
      }
      return BookTextResult(text: cached);
    }

    // 2. Check disk cache
    try {
      await _storageEngine.init();
      final cachedRaw = await _storageEngine.readAtomic('book_text_cache.json');
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final Map<String, dynamic> cacheMap = jsonDecode(cachedRaw);
        if (cacheMap.containsKey(unitId)) {
          final text = cacheMap[unitId]?.toString() ?? '';
          _memoryTextCache[unitId] = text;
          if (text.trim().length < 50) {
            return const BookTextResult(text: '', isScannedOnly: true);
          }
          return BookTextResult(text: text);
        }
      }
    } catch (e) {
      debugPrint('BookTextService: Error reading disk cache: $e');
    }

    // 3. Check if physical PDF exists
    final File? pdfFile = await _downloadService.getLocalBookFile(unitId);
    if (pdfFile == null || !await pdfFile.exists()) {
      return const BookTextResult(
        text: '',
        hasPdf: false,
        errorMessage: 'Textbook unit is not downloaded yet.',
      );
    }

    // 4. Extract text from PDF via pdfrx
    try {
      final doc = await PdfDocument.openFile(pdfFile.path);
      final buffer = StringBuffer();

      for (final page in doc.pages) {
        final pageText = await page.loadText();
        if (pageText != null && pageText.fullText.trim().isNotEmpty) {
          buffer.writeln(pageText.fullText.trim());
          buffer.writeln();
        }
      }

      await doc.dispose();

      final fullExtracted = buffer.toString().trim();

      // Scanned image PDF detection (< 50 characters across all pages)
      if (fullExtracted.length < 50) {
        await _saveToDiskCache(unitId, '');
        _memoryTextCache[unitId] = '';
        return const BookTextResult(
          text: '',
          isScannedOnly: true,
          errorMessage:
              'This textbook unit consists of scanned images. Readable text extraction is unavailable.',
        );
      }

      // Cache extracted text
      await _saveToDiskCache(unitId, fullExtracted);
      _memoryTextCache[unitId] = fullExtracted;

      return BookTextResult(text: fullExtracted);
    } catch (e) {
      debugPrint('BookTextService: Text extraction failed: $e');
      return BookTextResult(
        text: '',
        errorMessage: 'Failed to extract textbook text: $e',
      );
    }
  }

  /// Extracts a token-efficient context window (up to ~6000 characters)
  /// centered on the primary content of the unit.
  String prepareContextWindow(String fullText, {int maxChars = 6000}) {
    final trimmed = fullText.trim();
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars)}\n\n[... Unit text continues ...]';
  }

  Future<void> _saveToDiskCache(String unitId, String text) async {
    try {
      await _storageEngine.init();
      Map<String, dynamic> cacheMap = {};
      final cachedRaw = await _storageEngine.readAtomic('book_text_cache.json');
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        cacheMap = jsonDecode(cachedRaw) as Map<String, dynamic>;
      }
      cacheMap[unitId] = text;
      await _storageEngine.writeAtomic(
        'book_text_cache.json',
        jsonEncode(cacheMap),
      );
    } catch (e) {
      debugPrint('BookTextService: Error saving disk cache: $e');
    }
  }

  void clearMemoryCache() {
    _memoryTextCache.clear();
  }
}
