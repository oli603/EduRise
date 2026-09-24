import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/offline/storage_engine.dart';
import '../../../core/offline/stores/package_store.dart';
import 'past_exam_model.dart';

class PastExamDownloadService {
  final FirebaseFirestore? _customFirestore;
  Directory? _cachedExamDir;

  final StorageEngine _storageEngine = StorageEngine.instance;
  final PackageStore _packageStore = PackageStore();

  // User-scoped exam registry: userId -> Set of exam IDs
  final Map<String, Set<String>> _userDownloadedExams = {};
  bool _isRegistryLoaded = false;

  PastExamDownloadService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

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
      final data = await _storageEngine.readAtomic('exam_downloads.json');
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          _userDownloadedExams.clear();
          decoded.forEach((key, val) {
            if (val is List) {
              _userDownloadedExams[key.toString()] = val.map((e) => e.toString()).toSet();
            }
          });
        }
      }
      _isRegistryLoaded = true;
    } catch (e) {
      debugPrint('Error loading exam downloads registry: $e');
    }
  }

  Future<void> _saveRegistry() async {
    try {
      final map = <String, List<String>>{};
      _userDownloadedExams.forEach((k, v) {
        if (v.isNotEmpty) {
          map[k] = v.toList();
        }
      });
      await _storageEngine.writeAtomic('exam_downloads.json', jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving exam downloads registry: $e');
    }
  }

  Future<Directory> _getExamDir() async {
    if (_cachedExamDir != null) return _cachedExamDir!;

    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        Platform.environment.containsKey('DART_VM_OPTIONS') ||
        (!Platform.isAndroid && !Platform.isIOS);

    if (isTest) {
      final dir = Directory('${Directory.systemTemp.path}/edurise_past_exams');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cachedExamDir = dir;
      return dir;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final examDirectory = Directory('${directory.path}/edurise_past_exams');
      if (!await examDirectory.exists()) {
        await examDirectory.create(recursive: true);
      }
      _cachedExamDir = examDirectory;
      return examDirectory;
    } catch (_) {
      final dir = Directory('${Directory.systemTemp.path}/edurise_past_exams');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cachedExamDir = dir;
      return dir;
    }
  }

  /// Downloads one complete exam from Firestore and saves it locally.
  /// If the physical exam JSON already exists on the device (downloaded by another user),
  /// the physical file is reused and ownership is recorded for [uid].
  Future<void> downloadExam({required String examId, String? uid}) async {
    await _initRegistry();
    final targetUid = _resolveUid(uid);

    final dir = await _getExamDir();
    final file = File('${dir.path}/$examId.json');

    // Physical reuse if already cached
    if (await file.exists() && (await file.length()) > 0) {
      _userDownloadedExams.putIfAbsent(targetUid, () => {}).add(examId);
      await _saveRegistry();
      return;
    }

    final document = await _firestore.collection('past_exams').doc(examId).get();

    if (!document.exists) {
      throw Exception('Exam not found.');
    }

    final data = document.data();
    if (data == null) {
      throw Exception('Exam data is empty.');
    }

    await saveDownloadedExamData(examId, data);
    _userDownloadedExams.putIfAbsent(targetUid, () => {}).add(examId);
    await _saveRegistry();
  }

  /// Saves exam data map locally (used for downloads and tests).
  Future<void> saveDownloadedExamData(
    String examId,
    Map<String, dynamic> data, {
    String? uid,
  }) async {
    final dir = await _getExamDir();
    final file = File('${dir.path}/$examId.json');
    final tempFile = File('${dir.path}/$examId.json.tmp');

    final jsonData = jsonEncode(data);
    await tempFile.writeAsString(jsonData, flush: true);

    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);

    await _initRegistry();
    final targetUid = _resolveUid(uid);
    _userDownloadedExams.putIfAbsent(targetUid, () => {}).add(examId);
    await _saveRegistry();
  }

  /// Checks whether an exam is downloaded for the current (or specified) user account.
  /// Evaluates BOTH physical file existence AND current UID download ownership.
  Future<bool> isExamDownloaded({required String examId, String? uid}) async {
    final fileExists = await isExamDownloadedLocally(examId);
    if (!fileExists) return false;

    await _initRegistry();
    final targetUid = _resolveUid(uid);

    // 1. Check user-scoped exam registry
    if (_userDownloadedExams[targetUid]?.contains(examId) == true) {
      return true;
    }

    // 2. Check PackageStore for user's past exam packages
    try {
      final packages = await _packageStore.getAllPackages(uid: targetUid);
      for (final pkg in packages) {
        if (pkg.packageType == 'past_exam') {
          final eId = pkg.extraData['examId'] as String? ?? pkg.id;
          if (eId == examId || pkg.id == examId || pkg.id == 'past_exam_$examId') {
            _userDownloadedExams.putIfAbsent(targetUid, () => {}).add(examId);
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Low-level check verifying whether exam file physically exists locally on disk.
  Future<bool> isExamDownloadedLocally(String examId) async {
    final dir = await _getExamDir();
    final file = File('${dir.path}/$examId.json');
    return await file.exists();
  }

  /// Loads an already downloaded exam directly from device disk.
  Future<Map<String, dynamic>> getDownloadedExam({
    required String examId,
  }) async {
    final dir = await _getExamDir();
    final file = File('${dir.path}/$examId.json');

    if (!await file.exists()) {
      throw Exception('This exam has not been downloaded.');
    }

    final jsonString = await file.readAsString();
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid downloaded exam data.');
    }

    return decoded;
  }

  /// Loads downloaded PastExam model object directly.
  Future<PastExam?> getDownloadedPastExamModel({
    required String examId,
  }) async {
    try {
      final data = await getDownloadedExam(examId: examId);
      return PastExam.fromMap(examId, data);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a downloaded exam for [uid].
  /// The physical JSON file is deleted ONLY if NO other active user account references it.
  Future<void> deleteDownloadedExam({String? examId, String? id, String? uid}) async {
    final targetId = examId ?? id;
    if (targetId == null) return;

    await _initRegistry();
    final targetUid = _resolveUid(uid);

    // 1. Remove from current user's registry
    _userDownloadedExams[targetUid]?.remove(targetId);
    await _saveRegistry();

    // 2. Check if ANY other user on this device still references this exam
    bool referencedByOther = false;
    for (final entry in _userDownloadedExams.entries) {
      if (entry.key != targetUid && entry.value.contains(targetId)) {
        referencedByOther = true;
        break;
      }
    }

    if (!referencedByOther) {
      try {
        referencedByOther = await _packageStore.isPhysicalFileReferencedByOtherUsers(
          currentUid: targetUid,
          examId: targetId,
        );
      } catch (_) {}
    }

    // 3. Only delete physical file if NO other user references it
    if (!referencedByOther) {
      final dir = await _getExamDir();
      final file = File('${dir.path}/$targetId.json');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  void clearMemoryCache() {
    _userDownloadedExams.clear();
    _isRegistryLoaded = false;
  }
}
