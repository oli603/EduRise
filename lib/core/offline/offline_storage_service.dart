import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models/download_package_record.dart';
import 'models/student_profile_record.dart';
import 'storage_engine.dart';
import 'stores/package_store.dart';
import 'stores/profile_store.dart';

export 'models/download_package_record.dart';
export 'models/student_profile_record.dart';
export 'storage_engine.dart';
export 'stores/package_store.dart';
export 'stores/profile_store.dart';

/// Offline Storage Service providing local persistence and facade coordination
/// for EduRise offline learning.
///
/// This service contains ZERO feature dependencies.
class OfflineStorageService {
  static final OfflineStorageService _instance = OfflineStorageService._internal();
  factory OfflineStorageService({
    StorageEngine? engine,
    PackageStore? packageStore,
    ProfileStore? profileStore,
  }) {
    if (engine != null || packageStore != null || profileStore != null) {
      return OfflineStorageService._withStores(
        engine: engine ?? StorageEngine.instance,
        packageStore: packageStore ?? PackageStore(),
        profileStore: profileStore ?? ProfileStore(),
      );
    }
    return _instance;
  }
  static OfflineStorageService get instance => _instance;
  OfflineStorageService._internal()
      : _engine = StorageEngine.instance,
        _packageStore = PackageStore(),
        _profileStore = ProfileStore();

  OfflineStorageService._withStores({
    required StorageEngine engine,
    required PackageStore packageStore,
    required ProfileStore profileStore,
  })  : _engine = engine,
        _packageStore = packageStore,
        _profileStore = profileStore;

  final StorageEngine _engine;
  final PackageStore _packageStore;
  final ProfileStore _profileStore;

  bool get isInitialized => _isInitialized;
  bool _isInitialized = false;

  final List<Map<String, dynamic>> _practiceResults = [];
  final List<Map<String, dynamic>> _pastExamResults = [];
  final Map<String, Map<String, dynamic>> _coachContent = {};

  Future<Directory> get storageDirectory => _engine.storageDirectory;
  Future<void> initialize() => init();

  Future<void> init({bool forceReload = false}) async {
    if (_isInitialized && !forceReload) return;
    try {
      await _engine.init();
      await _packageStore.init(forceReload: forceReload);
      await _profileStore.init(forceReload: forceReload);

      try {
        await _loadPracticeResultsFromDisk();
      } catch (e) {
        debugPrint('Error loading practice results: $e');
      }
      try {
        await _loadPastExamResultsFromDisk();
      } catch (e) {
        debugPrint('Error loading past exam results: $e');
      }
      try {
        await _loadCoachContentFromDisk();
      } catch (e) {
        debugPrint('Error loading coach content: $e');
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing OfflineStorageService: $e');
    }
  }

  // ============================================================
  // PACKAGES FACADE
  // ============================================================

  Future<List<DownloadPackageRecord>> getAllPackages({String? uid}) async {
    await init();
    return _packageStore.getAllPackages(uid: uid);
  }

  Future<List<DownloadPackageRecord>> getPackagesByType(String packageType, {String? uid}) async {
    await init();
    return _packageStore.getPackagesByType(packageType, uid: uid);
  }

  Future<DownloadPackageRecord?> getPackage(String packageId, {String? uid}) async {
    await init();
    return _packageStore.getPackage(packageId, uid: uid);
  }

  Future<void> savePackage(DownloadPackageRecord package, {String? uid}) async {
    await init();
    await _packageStore.savePackage(package, uid: uid);
  }

  Future<void> deletePackageRecord(String packageId, {String? uid}) async {
    await init();
    await _packageStore.deletePackageRecord(packageId, uid: uid);
  }

  Future<bool> isPhysicalFileReferencedByOtherUsers({
    required String currentUid,
    String? unitId,
    String? examId,
    List<String>? questionIds,
  }) async {
    await init();
    return _packageStore.isPhysicalFileReferencedByOtherUsers(
      currentUid: currentUid,
      unitId: unitId,
      examId: examId,
      questionIds: questionIds,
    );
  }

  Future<List<String>> getUserIdsForPackage(String packageId) async {
    await init();
    return _packageStore.getUserIdsForPackage(packageId);
  }

  // ============================================================
  // STUDENT PROFILES FACADE
  // ============================================================

  Future<StudentProfileRecord?> getStudentProfile(String uid) async {
    await init();
    return _profileStore.getStudentProfile(uid);
  }

  Future<void> saveStudentProfile(StudentProfileRecord profile) async {
    await init();
    await _profileStore.saveStudentProfile(profile);
  }

  Future<void> removeStudentProfile(String uid) async {
    await init();
    await _profileStore.removeStudentProfile(uid);
  }

  Future<List<StudentProfileRecord>> getAllStudentProfiles() async {
    await init();
    return _profileStore.getAllStudentProfiles();
  }

  // ============================================================
  // PRACTICE RESULTS PERSISTENCE
  // ============================================================

  Future<void> _loadPracticeResultsFromDisk() async {
    final data = await _engine.readAtomic('practice_results.json');
    if (data != null && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is List) {
        _practiceResults.clear();
        for (final item in decoded) {
          if (item is Map) {
            _practiceResults.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }
  }

  Future<void> _savePracticeResultsToDisk() async {
    final list = _practiceResults.map((r) => _engine.sanitizeMapForDisk(r)).toList();
    await _engine.writeAtomic('practice_results.json', jsonEncode(list));
  }

  Future<void> savePracticeResultLocally(Map<String, dynamic> result) async {
    await init();
    final localId = (result['localId'] ?? result['id'])?.toString();
    if (localId != null && localId.isNotEmpty) {
      final index = _practiceResults.indexWhere((r) =>
          ((r['localId'] ?? r['id'])?.toString()) == localId);
      if (index >= 0) {
        _practiceResults[index] = Map<String, dynamic>.from(result);
        await _savePracticeResultsToDisk();
        return;
      }
    }
    _practiceResults.add(Map<String, dynamic>.from(result));
    await _savePracticeResultsToDisk();
  }

  Future<List<Map<String, dynamic>>> getLocalPracticeResults({String? userId}) async {
    await init();
    if (userId == null) return List.from(_practiceResults);
    return _practiceResults.where((r) => r['userId'] == userId).toList();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPracticeResults() async {
    await init();
    return _practiceResults.where((r) => r['isSynced'] != true).toList();
  }

  Future<void> markPracticeResultSynced(String localId, {String? serverId}) async {
    await init();
    for (var i = 0; i < _practiceResults.length; i++) {
      if (_practiceResults[i]['localId'] == localId || _practiceResults[i]['id'] == localId) {
        _practiceResults[i]['isSynced'] = true;
        if (serverId != null) {
          _practiceResults[i]['serverId'] = serverId;
        }
        break;
      }
    }
    await _savePracticeResultsToDisk();
  }

  Future<void> cacheRemotePracticeResults(List<Map<String, dynamic>> results) async {
    await init();
    final existingIds = <String>{};
    for (final r in _practiceResults) {
      final localId = r['localId'] as String?;
      final id = r['id'] as String?;
      if (localId != null && localId.isNotEmpty) existingIds.add(localId);
      if (id != null && id.isNotEmpty) existingIds.add(id);
    }

    bool added = false;
    for (final r in results) {
      final id = r['id'] as String? ?? r['localId'] as String?;
      if (id != null && !existingIds.contains(id)) {
        _practiceResults.add(Map<String, dynamic>.from(r));
        existingIds.add(id);
        added = true;
      }
    }

    if (added) {
      await _savePracticeResultsToDisk();
    }
  }

  // ============================================================
  // PAST EXAM RESULTS PERSISTENCE
  // ============================================================

  Future<void> _loadPastExamResultsFromDisk() async {
    final data = await _engine.readAtomic('past_exam_results.json');
    if (data != null && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is List) {
        _pastExamResults.clear();
        for (final item in decoded) {
          if (item is Map) {
            _pastExamResults.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }
  }

  Future<void> _savePastExamResultsToDisk() async {
    final list = _pastExamResults.map((r) => _engine.sanitizeMapForDisk(r)).toList();
    await _engine.writeAtomic('past_exam_results.json', jsonEncode(list));
  }

  Future<void> savePastExamResultLocally(Map<String, dynamic> result) async {
    await init();
    final localId = (result['localId'] ?? result['id'])?.toString();
    if (localId != null && localId.isNotEmpty) {
      final index = _pastExamResults.indexWhere((r) =>
          ((r['localId'] ?? r['id'])?.toString()) == localId);
      if (index >= 0) {
        _pastExamResults[index] = Map<String, dynamic>.from(result);
        await _savePastExamResultsToDisk();
        return;
      }
    }
    _pastExamResults.add(Map<String, dynamic>.from(result));
    await _savePastExamResultsToDisk();
  }

  Future<List<Map<String, dynamic>>> getLocalPastExamResults({
    String? userId,
    String? examId,
  }) async {
    await init();
    var list = List<Map<String, dynamic>>.from(_pastExamResults);
    if (userId != null) {
      list = list.where((r) => r['userId'] == userId).toList();
    }
    if (examId != null) {
      list = list.where((r) => r['examId'] == examId).toList();
    }
    return list;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPastExamResults() async {
    await init();
    return _pastExamResults
        .where((r) => r['syncStatus'] == 'pending' || r['isSynced'] != true)
        .toList();
  }

  Future<void> markPastExamResultSynced(String localId, {String? serverId}) async {
    await init();
    for (int i = 0; i < _pastExamResults.length; i++) {
      if (_pastExamResults[i]['localId'] == localId || _pastExamResults[i]['id'] == localId) {
        _pastExamResults[i]['syncStatus'] = 'synced';
        _pastExamResults[i]['isSynced'] = true;
        if (serverId != null) {
          _pastExamResults[i]['serverId'] = serverId;
        }
        break;
      }
    }
    await _savePastExamResultsToDisk();
  }

  Future<void> cacheRemotePastExamResults(List<Map<String, dynamic>> results) async {
    await init();
    final existingIds = <String>{};
    for (final r in _pastExamResults) {
      final localId = r['localId'] as String?;
      final id = r['id'] as String?;
      if (localId != null && localId.isNotEmpty) existingIds.add(localId);
      if (id != null && id.isNotEmpty) existingIds.add(id);
    }

    bool added = false;
    for (final r in results) {
      final id = r['id'] as String? ?? r['localId'] as String?;
      if (id != null && !existingIds.contains(id)) {
        _pastExamResults.add(Map<String, dynamic>.from(r));
        existingIds.add(id);
        added = true;
      }
    }

    if (added) {
      await _savePastExamResultsToDisk();
    }
  }

  // ============================================================
  // EDURISE COACH CONTENT CACHING (OFFLINE ACCESS)
  // ============================================================

  Future<void> _loadCoachContentFromDisk() async {
    final raw = await _engine.readAtomic('coach_content.json');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _coachContent.clear();
        decoded.forEach((k, v) {
          if (v is Map) {
            _coachContent[k] = Map<String, dynamic>.from(v);
          }
        });
      } catch (e) {
        debugPrint('Error parsing coach_content.json: $e');
      }
    }
  }

  Future<void> _saveCoachContentToDisk() async {
    final sanitized = <String, dynamic>{};
    _coachContent.forEach((k, v) {
      sanitized[k] = _engine.sanitizeMapForDisk(v);
    });
    await _engine.writeAtomic('coach_content.json', jsonEncode(sanitized));
  }

  Future<void> saveCoachContentLocally({
    required String feature,
    required String contentId,
    required Map<String, dynamic> content,
  }) async {
    await init();
    final cacheKey = '${feature}_$contentId';
    final toSave = Map<String, dynamic>.from(content);
    toSave['cached'] = true;
    _coachContent[cacheKey] = toSave;
    await _saveCoachContentToDisk();
  }

  Map<String, dynamic>? getLocalCoachContent({
    required String feature,
    required String contentId,
  }) {
    final cacheKey = '${feature}_$contentId';
    final data = _coachContent[cacheKey];
    if (data == null) return null;
    final res = Map<String, dynamic>.from(data);
    res['cached'] = true;
    return res;
  }

  Future<Map<String, dynamic>?> getLocalCoachContentAsync({
    required String feature,
    required String contentId,
  }) async {
    await init();
    return getLocalCoachContent(feature: feature, contentId: contentId);
  }

  // ============================================================
  // STORAGE USAGE CALCULATIONS
  // ============================================================

  Future<int> getTotalStorageBytes() => _engine.getTotalStorageBytes();

  static String formatBytes(int bytes) => StorageEngine.formatBytes(bytes);

  // ============================================================
  // MEMORY CACHE RESET (ACCOUNT SWITCH / LOGOUT)
  // ============================================================

  void clearMemoryCache() {
    _packageStore.clearMemoryCache();
    _profileStore.clearMemoryCache();
    _practiceResults.clear();
    _pastExamResults.clear();
    _coachContent.clear();
    _isInitialized = false;
  }

  // ============================================================
  // TESTING CLEANUP
  // ============================================================

  Future<void> clearLocalDataForTesting() async {
    _packageStore.clearMemoryCache();
    _profileStore.clearMemoryCache();
    _practiceResults.clear();
    _pastExamResults.clear();
    _coachContent.clear();
    _isInitialized = false;
    await _engine.clearAllForTesting();
  }
}
