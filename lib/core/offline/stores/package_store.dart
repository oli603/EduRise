import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../auth/session_manager.dart';
import '../models/download_package_record.dart';
import '../storage_engine.dart';

/// Core store for downloaded educational package metadata records,
/// strictly isolated per Firebase Authenticated User UID.
class PackageStore {
  static final PackageStore _instance = PackageStore._internal();
  factory PackageStore({StorageEngine? engine}) {
    if (engine != null) {
      return PackageStore._withEngine(engine);
    }
    return _instance;
  }
  PackageStore._internal() : _engine = StorageEngine.instance;
  PackageStore._withEngine(this._engine);

  final StorageEngine _engine;
  // Account-scoped packages: userId -> (packageId -> DownloadPackageRecord)
  final Map<String, Map<String, DownloadPackageRecord>> _userPackages = {};
  bool _isLoaded = false;

  /// Resolves the effective UID: explicit UID -> FirebaseAuth UID -> SessionManager UID -> fallback.
  String resolveUid(String? explicitUid) {
    if (explicitUid != null && explicitUid.isNotEmpty) return explicitUid;
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    } catch (_) {}
    final sessionUid = SessionManager.currentUid;
    if (sessionUid != null && sessionUid.isNotEmpty) return sessionUid;
    return 'default_user';
  }

  Future<void> init({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) return;
    await _engine.init();
    await _loadFromDisk();
    _isLoaded = true;
  }

  DownloadPackageRecord _sanitizePackageRecord(DownloadPackageRecord pkg) {
    var result = pkg;
    // 1. Self-healing sanitization for corrupted legacy Social Biology records:
    final stream = (result.stream ?? '').toLowerCase();
    final isSocial = stream.contains('social') || result.id.contains('_social_');
    if (isSocial && result.subject.toLowerCase() == 'biology') {
      String correctedSubject = 'Economics';
      if (result.id.contains('history')) {
        correctedSubject = 'History';
      } else if (result.id.contains('geography')) {
        correctedSubject = 'Geography';
      } else if (result.id.contains('economics')) {
        correctedSubject = 'Economics';
      } else if (result.id.contains('mathematics') || result.id.contains('math')) {
        correctedSubject = 'Mathematics';
      }
      result = result.copyWith(
        subject: correctedSubject,
        title: result.title.replaceAll('Biology', correctedSubject),
      );
    }

    // 2. Self-healing stream assignment for packages lacking explicit stream metadata:
    if (result.stream == null || result.stream!.trim().isEmpty) {
      final sLower = result.subject.toLowerCase();
      String derivedStream = 'natural';
      if (result.id.contains('_social_') || ['history', 'geography', 'economics'].contains(sLower)) {
        derivedStream = 'social';
      } else if (result.id.contains('_natural_') || ['physics', 'chemistry', 'biology'].contains(sLower)) {
        derivedStream = 'natural';
      }
      result = result.copyWith(stream: derivedStream);
    }

    return result;
  }

  Future<void> _loadFromDisk() async {
    try {
      final data = await _engine.readAtomic('packages.json');
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        _userPackages.clear();

        if (decoded is Map) {
          decoded.forEach((uKey, uVal) {
            final uId = uKey.toString();
            if (uVal is Map) {
              final pkgMap = <String, DownloadPackageRecord>{};
              uVal.forEach((pkgKey, pkgVal) {
                if (pkgVal is Map) {
                  var pkg = DownloadPackageRecord.fromMap(
                    Map<String, dynamic>.from(pkgVal),
                    fallbackUserId: uId,
                  );
                  if (pkg.id.isNotEmpty) {
                    pkg = _sanitizePackageRecord(pkg);
                    pkgMap[pkg.id] = pkg;
                  }
                }
              });
              if (pkgMap.isNotEmpty) {
                _userPackages[uId] = pkgMap;
              }
            } else if (uVal is List) {
              final pkgMap = <String, DownloadPackageRecord>{};
              for (final item in uVal) {
                if (item is Map) {
                  var pkg = DownloadPackageRecord.fromMap(
                    Map<String, dynamic>.from(item),
                    fallbackUserId: uId,
                  );
                  if (pkg.id.isNotEmpty) {
                    pkg = _sanitizePackageRecord(pkg);
                    pkgMap[pkg.id] = pkg;
                  }
                }
              }
              if (pkgMap.isNotEmpty) {
                _userPackages[uId] = pkgMap;
              }
            }
          });
        } else if (decoded is List) {
          // Graceful backward-compatible migration of legacy un-scoped package list
          for (final item in decoded) {
            if (item is Map) {
              var pkg = DownloadPackageRecord.fromMap(Map<String, dynamic>.from(item));
              if (pkg.id.isNotEmpty) {
                pkg = _sanitizePackageRecord(pkg);
                final targetUid = pkg.userId.isNotEmpty ? pkg.userId : resolveUid(null);
                _userPackages.putIfAbsent(targetUid, () => {})[pkg.id] =
                    pkg.copyWith(userId: targetUid);
              }
            }
          }
          await _saveToDisk();
        }
      }
    } catch (e) {
      debugPrint('Error loading packages from disk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    final map = <String, dynamic>{};
    _userPackages.forEach((uid, packagesMap) {
      if (uid.isNotEmpty && packagesMap.isNotEmpty) {
        final userMap = <String, dynamic>{};
        packagesMap.forEach((pkgId, pkg) {
          userMap[pkgId] = _engine.sanitizeMapForDisk(pkg.toMap());
        });
        map[uid] = userMap;
      }
    });
    await _engine.writeAtomic('packages.json', jsonEncode(map));
  }

  Future<List<DownloadPackageRecord>> getAllPackages({String? uid}) async {
    await init();
    final targetUid = resolveUid(uid);
    if (targetUid.isEmpty) return [];
    return _userPackages[targetUid]?.values.toList() ?? [];
  }

  Future<List<DownloadPackageRecord>> getPackagesByType(String packageType, {String? uid}) async {
    await init();
    final targetUid = resolveUid(uid);
    if (targetUid.isEmpty) return [];
    return (_userPackages[targetUid]?.values ?? [])
        .where((p) => p.packageType == packageType)
        .toList();
  }

  Future<DownloadPackageRecord?> getPackage(String packageId, {String? uid}) async {
    await init();
    final targetUid = resolveUid(uid);
    if (targetUid.isEmpty) return null;
    return _userPackages[targetUid]?[packageId];
  }

  Future<void> savePackage(DownloadPackageRecord package, {String? uid}) async {
    await init();
    final targetUid = resolveUid(uid ?? (package.userId.isNotEmpty ? package.userId : null));
    if (targetUid.isEmpty) return;

    final record = package.userId == targetUid ? package : package.copyWith(userId: targetUid);
    _userPackages.putIfAbsent(targetUid, () => {})[record.id] = record;
    await _saveToDisk();
  }

  Future<void> deletePackageRecord(String packageId, {String? uid}) async {
    await init();
    final targetUid = resolveUid(uid);
    if (targetUid.isEmpty) return;
    _userPackages[targetUid]?.remove(packageId);
    await _saveToDisk();
  }

  /// Checks if any user other than [currentUid] references the given physical asset.
  /// Used for safe reference-counted file deletion to prevent cross-account file deletion bugs.
  Future<bool> isPhysicalFileReferencedByOtherUsers({
    required String currentUid,
    String? unitId,
    String? examId,
    List<String>? questionIds,
  }) async {
    await init();
    for (final entry in _userPackages.entries) {
      if (entry.key == currentUid) continue;
      for (final pkg in entry.value.values) {
        if (unitId != null && unitId.isNotEmpty) {
          final unitIds = (pkg.extraData['unitIds'] as List?)?.cast<String>() ?? [];
          if (unitIds.contains(unitId)) return true;
        }
        if (examId != null && examId.isNotEmpty) {
          final eId = pkg.extraData['examId'] as String? ?? pkg.id;
          if (eId == examId || pkg.id == examId || pkg.id == 'past_exam_$examId') {
            return true;
          }
        }
        if (questionIds != null && questionIds.isNotEmpty) {
          final qIds = (pkg.extraData['questionIds'] as List?)?.cast<String>() ?? [];
          if (qIds.any((id) => questionIds.contains(id))) return true;
        }
      }
    }
    return false;
  }

  /// Returns all UIDs who currently have the given package downloaded.
  Future<List<String>> getUserIdsForPackage(String packageId) async {
    await init();
    final uids = <String>[];
    _userPackages.forEach((uid, pkgs) {
      if (pkgs.containsKey(packageId)) {
        uids.add(uid);
      }
    });
    return uids;
  }

  void clearMemoryCache() {
    _userPackages.clear();
    _isLoaded = false;
  }
}
