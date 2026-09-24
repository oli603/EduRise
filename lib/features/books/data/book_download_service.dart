import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/offline/storage_engine.dart';
import '../../../core/offline/stores/package_store.dart';

class BookDownloadService {
  static final BookDownloadService _instance = BookDownloadService._internal();
  factory BookDownloadService() => _instance;
  BookDownloadService._internal();

  final StorageEngine _storageEngine = StorageEngine.instance;
  final PackageStore _packageStore = PackageStore();

  // User-scoped registry: userId -> Set of unit IDs
  final Map<String, Set<String>> _userDownloadedUnits = {};
  bool _isRegistryLoaded = false;

  String _resolveUid(String? explicitUid) {
    if (explicitUid != null && explicitUid.isNotEmpty) return explicitUid;
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    } catch (_) {}
    final sessionUid = SessionManager.currentUid;
    if (sessionUid != null && sessionUid.isNotEmpty) return sessionUid;
    return 'default_user';
  }

  Future<void> _initRegistry() async {
    if (_isRegistryLoaded) return;
    try {
      await _storageEngine.init();
      final data = await _storageEngine.readAtomic('book_unit_downloads.json');
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          _userDownloadedUnits.clear();
          decoded.forEach((key, val) {
            if (val is List) {
              _userDownloadedUnits[key.toString()] = val.map((e) => e.toString()).toSet();
            }
          });
        }
      }
      _isRegistryLoaded = true;
    } catch (e) {
      debugPrint('Error loading book unit downloads registry: $e');
    }
  }

  Future<void> _saveRegistry() async {
    try {
      final map = <String, List<String>>{};
      _userDownloadedUnits.forEach((k, v) {
        if (v.isNotEmpty) {
          map[k] = v.toList();
        }
      });
      await _storageEngine.writeAtomic('book_unit_downloads.json', jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving book unit downloads registry: $e');
    }
  }

  Future<Directory> _getBooksDirectory() async {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        Platform.environment.containsKey('DART_VM_OPTIONS') ||
        (!Platform.isAndroid && !Platform.isIOS);

    if (isTest) {
      final dir = Directory('${Directory.systemTemp.path}/edurise_books');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final booksDirectory = Directory('${appDirectory.path}/edurise_books');

      if (!await booksDirectory.exists()) {
        await booksDirectory.create(recursive: true);
      }

      return booksDirectory;
    } catch (_) {
      final dir = Directory('${Directory.systemTemp.path}/edurise_books');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  /// Returns physical book file if it exists on disk, regardless of account ownership.
  Future<File?> getLocalBookFile(String bookId) async {
    final directory = await _getBooksDirectory();
    final file = File('${directory.path}/$bookId.pdf');

    if (await file.exists()) {
      return file;
    }

    return null;
  }

  /// Checks whether [bookId] is downloaded for the current (or specified) user UID.
  /// Evaluates BOTH physical file existence AND user ownership metadata.
  Future<bool> isDownloaded(String bookId, {String? uid}) async {
    final file = await getLocalBookFile(bookId);
    if (file == null) {
      return false;
    }

    await _initRegistry();
    final targetUid = _resolveUid(uid);

    // 1. Check user-scoped unit registry
    if (_userDownloadedUnits[targetUid]?.contains(bookId) == true) {
      return true;
    }

    // 2. Check user's package records in PackageStore
    try {
      final packages = await _packageStore.getAllPackages(uid: targetUid);
      for (final pkg in packages) {
        if (pkg.packageType == 'book') {
          final unitIds = (pkg.extraData['unitIds'] as List?)?.cast<String>() ?? [];
          if (unitIds.contains(bookId)) {
            // Self-heal user registry
            _userDownloadedUnits.putIfAbsent(targetUid, () => {}).add(bookId);
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Downloads one unit PDF. If the physical PDF already exists locally (from another account),
  /// reuses the cached file while marking [bookId] as downloaded for [targetUid].
  Future<File> downloadBook({
    required String bookId,
    required String pdfUrl,
    void Function(double progress)? onProgress,
    String? uid,
  }) async {
    await _initRegistry();
    final targetUid = _resolveUid(uid);
    final directory = await _getBooksDirectory();
    final file = File('${directory.path}/$bookId.pdf');

    // Physical reuse: If already cached on device, mark user ownership and return immediately
    if (await file.exists() && (await file.length()) > 0) {
      _userDownloadedUnits.putIfAbsent(targetUid, () => {}).add(bookId);
      await _saveRegistry();
      onProgress?.call(1.0);
      return file;
    }

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

    _userDownloadedUnits.putIfAbsent(targetUid, () => {}).add(bookId);
    await _saveRegistry();

    return file;
  }

  /// Removes logical ownership of [bookId] for [targetUid].
  /// The physical PDF is deleted ONLY if NO other active user account references it.
  Future<void> deleteBook(String bookId, {String? uid}) async {
    await _initRegistry();
    final targetUid = _resolveUid(uid);

    // 1. Remove from current user's registry
    _userDownloadedUnits[targetUid]?.remove(bookId);
    await _saveRegistry();

    // 2. Check if ANY other user on this device still references this unit
    bool referencedByOther = false;
    for (final entry in _userDownloadedUnits.entries) {
      if (entry.key != targetUid && entry.value.contains(bookId)) {
        referencedByOther = true;
        break;
      }
    }

    if (!referencedByOther) {
      try {
        referencedByOther = await _packageStore.isPhysicalFileReferencedByOtherUsers(
          currentUid: targetUid,
          unitId: bookId,
        );
      } catch (_) {}
    }

    // 3. Only delete physical file if NO other user references it
    if (!referencedByOther) {
      final file = await getLocalBookFile(bookId);
      if (file != null) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  void clearMemoryCache() {
    _userDownloadedUnits.clear();
    _isRegistryLoaded = false;
  }
}
