import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Pure Core Storage Engine providing low-level, crash-safe, atomic file I/O
/// and per-file write locks for EduRise offline operations.
///
/// This engine contains NO feature dependencies.
class StorageEngine {
  static final StorageEngine _instance = StorageEngine._internal();
  factory StorageEngine() => _instance;
  static StorageEngine get instance => _instance;
  StorageEngine._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  Directory? _cachedDir;

  // Per-file sequential async write queue to guarantee atomic sequential writes
  final Map<String, Future<void>> _writeLocks = {};

  Future<Directory> get storageDirectory => _offlineDir;

  Future<Directory> get _offlineDir async {
    if (_cachedDir != null) return _cachedDir!;
    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        Platform.environment.containsKey('DART_VM_OPTIONS') ||
        (!Platform.isAndroid && !Platform.isIOS);
    if (isTest) {
      final dir = Directory('${Directory.systemTemp.path}/edurise_offline_test');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cachedDir = dir;
      return dir;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/edurise_offline');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cachedDir = dir;
      return dir;
    } catch (_) {
      final dir = Directory('${Directory.systemTemp.path}/edurise_offline');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cachedDir = dir;
      return dir;
    }
  }

  /// Initializes the storage engine and cleans up any orphan `.tmp` files.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final dir = await _offlineDir;
      if (await dir.exists()) {
        await cleanOrphanTempFiles();
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing StorageEngine: $e');
    }
  }

  /// Scans the offline directory and removes leftover `.tmp` files from aborted writes.
  Future<void> cleanOrphanTempFiles() async {
    try {
      final dir = await _offlineDir;
      if (!await dir.exists()) return;
      final entities = await dir.list(followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.tmp')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error cleaning orphan temp files: $e');
    }
  }

  /// Writes content atomically to [filename].
  ///
  /// Safe replacement flow:
  /// 1. Queues sequential write lock for [filename].
  /// 2. Writes full content to `<filename>.tmp` and flushes to disk.
  /// 3. Safely replaces the target file without pre-deleting it, eliminating
  ///    the crash window where the target file could be lost.
  /// 4. If platform atomic rename fails (e.g. Windows file exists), copies and removes `.tmp`.
  Future<void> writeAtomic(String filename, String content) async {
    final previousLock = _writeLocks[filename] ?? Future.value();
    final completer = Completer<void>();
    _writeLocks[filename] = completer.future;

    try {
      await previousLock;
      final dir = await _offlineDir;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/$filename');
      final tempFile = File('${dir.path}/$filename.tmp');

      // Step 1: Write completely to temp file with flush
      await tempFile.writeAsString(content, flush: true);

      // Step 2: Safe replace without pre-deleting target
      try {
        await tempFile.rename(file.path);
      } catch (_) {
        // Fallback for OS where rename does not overwrite an existing file (e.g. Windows MoveFile)
        await tempFile.copy(file.path);
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error writing atomic file $filename: $e');
      rethrow;
    } finally {
      completer.complete();
      if (_writeLocks[filename] == completer.future) {
        _writeLocks.remove(filename);
      }
    }
  }

  /// Reads content atomically from [filename], waiting for any active write lock to complete.
  Future<String?> readAtomic(String filename) async {
    if (_writeLocks.containsKey(filename)) {
      await _writeLocks[filename];
    }
    final dir = await _offlineDir;
    if (!await dir.exists()) {
      return null;
    }
    final file = File('${dir.path}/$filename');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  /// Deletes [filename] and its corresponding `.tmp` file.
  Future<void> deleteFile(String filename) async {
    if (_writeLocks.containsKey(filename)) {
      await _writeLocks[filename];
    }
    final dir = await _offlineDir;
    if (!await dir.exists()) return;
    final file = File('${dir.path}/$filename');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    final tempFile = File('${dir.path}/$filename.tmp');
    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }
  }

  /// Checks whether [filename] exists in storage directory.
  Future<bool> fileExists(String filename) async {
    final dir = await _offlineDir;
    if (!await dir.exists()) return false;
    return File('${dir.path}/$filename').exists();
  }

  /// Sanitizes maps before JSON encoding by converting Firestore Timestamps and DateTimes to ISO-8601 strings.
  Map<String, dynamic> sanitizeMapForDisk(Map<String, dynamic> map) {
    final clean = <String, dynamic>{};
    map.forEach((k, v) {
      if (v is Timestamp) {
        clean[k] = v.toDate().toIso8601String();
      } else if (v is DateTime) {
        clean[k] = v.toIso8601String();
      } else if (v is Map) {
        clean[k] = sanitizeMapForDisk(Map<String, dynamic>.from(v));
      } else if (v is List) {
        clean[k] = v.map((item) {
          if (item is Map) return sanitizeMapForDisk(Map<String, dynamic>.from(item));
          if (item is Timestamp) return item.toDate().toIso8601String();
          if (item is DateTime) return item.toIso8601String();
          return item;
        }).toList();
      } else {
        clean[k] = v;
      }
    });
    return clean;
  }

  /// Calculates total bytes used by offline educational content and databases.
  Future<int> getTotalStorageBytes() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return 0;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory().timeout(
        const Duration(milliseconds: 100),
      );
      int totalBytes = 0;

      // 1. Books directory
      final booksDir = Directory('${appDir.path}/edurise_books');
      if (await booksDir.exists()) {
        final entities = await booksDir.list(recursive: true, followLinks: false).toList();
        for (final entity in entities) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      // 2. Past Exams directory
      final examsDir = Directory('${appDir.path}/edurise_past_exams');
      if (await examsDir.exists()) {
        final entities = await examsDir.list(recursive: true, followLinks: false).toList();
        for (final entity in entities) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      // 3. Offline storage files
      final offlineDir = await _offlineDir;
      if (await offlineDir.exists()) {
        final entities = await offlineDir.list(recursive: true, followLinks: false).toList();
        for (final entity in entities) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      return totalBytes;
    } catch (e) {
      debugPrint('Error calculating storage bytes: $e');
      return 0;
    }
  }

  /// Formats byte counts into human-readable strings (e.g. 512.0 B, 1.5 KB, 5.0 MB).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Clears all files in the offline directory and resets lock states for tests.
  Future<void> clearAllForTesting() async {
    _writeLocks.clear();
    _isInitialized = false;
    try {
      final dir = await _offlineDir;
      if (await dir.exists()) {
        final entities = await dir.list(followLinks: false).toList();
        for (final file in entities) {
          if (file is File) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
