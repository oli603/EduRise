import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/student_profile_record.dart';
import '../storage_engine.dart';

/// Core store for student profile caching, providing offline-first profile resolution
/// and UID-isolated student records.
class ProfileStore {
  static final ProfileStore _instance = ProfileStore._internal();
  factory ProfileStore({StorageEngine? engine}) {
    if (engine != null) {
      return ProfileStore._withEngine(engine);
    }
    return _instance;
  }
  ProfileStore._internal() : _engine = StorageEngine.instance;
  ProfileStore._withEngine(this._engine);

  final StorageEngine _engine;
  final Map<String, StudentProfileRecord> _studentProfiles = {};
  bool _isLoaded = false;

  Future<void> init({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) return;
    await _engine.init();
    await _loadFromDisk();
    _isLoaded = true;
  }

  Future<void> _loadFromDisk() async {
    try {
      final data = await _engine.readAtomic('student_profiles.json');
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        _studentProfiles.clear();
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is Map) {
              final uidKey = key.toString();
              final map = Map<String, dynamic>.from(value);
              final recordUid = map['uid'] as String? ?? uidKey;
              if (recordUid == uidKey && uidKey.isNotEmpty) {
                _studentProfiles[uidKey] =
                    StudentProfileRecord.fromMap(map, fallbackUid: uidKey);
              }
            }
          });
        } else if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final uid = map['uid'] as String? ?? '';
              if (uid.isNotEmpty) {
                _studentProfiles[uid] = StudentProfileRecord.fromMap(map);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading student profiles from disk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    final map = <String, dynamic>{};
    _studentProfiles.forEach((uid, profile) {
      if (uid.isNotEmpty && profile.uid == uid) {
        map[uid] = _engine.sanitizeMapForDisk(profile.toMap());
      }
    });
    await _engine.writeAtomic('student_profiles.json', jsonEncode(map));
  }

  Future<StudentProfileRecord?> getStudentProfile(String uid) async {
    await init();
    if (uid.isEmpty) return null;
    final profile = _studentProfiles[uid];
    if (profile == null) return null;
    if (profile.uid != uid) {
      // Protection against cross-account or wrong UID collision
      return null;
    }
    return profile;
  }

  Future<void> saveStudentProfile(StudentProfileRecord profile) async {
    await init();
    if (profile.uid.isEmpty) return;
    _studentProfiles[profile.uid] = profile;
    await _saveToDisk();
  }

  Future<void> removeStudentProfile(String uid) async {
    await init();
    if (uid.isEmpty) return;
    _studentProfiles.remove(uid);
    await _saveToDisk();
  }

  Future<List<StudentProfileRecord>> getAllStudentProfiles() async {
    await init();
    return _studentProfiles.values.toList();
  }

  void clearMemoryCache() {
    _studentProfiles.clear();
    _isLoaded = false;
  }
}
