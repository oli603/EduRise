import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/offline/storage_engine.dart';
import '../challenge_model.dart';

/// Feature store managing local persistence and sync queuing for Daily Challenges.
class ChallengeStore {
  static final ChallengeStore _instance = ChallengeStore._internal();
  factory ChallengeStore({StorageEngine? engine}) {
    if (engine != null) {
      return ChallengeStore._withEngine(engine);
    }
    return _instance;
  }
  ChallengeStore._internal() : _engine = StorageEngine.instance;
  ChallengeStore._withEngine(this._engine);

  final StorageEngine _engine;
  final Map<String, Challenge> _challenges = {};
  final List<Map<String, dynamic>> _pendingChallengeOps = [];
  bool _isLoaded = false;

  Future<void> init({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) return;
    await _engine.init();
    await _loadFromDisk();
    _isLoaded = true;
  }

  Future<void> _loadFromDisk() async {
    try {
      final challengesData = await _engine.readAtomic('challenges.json');
      if (challengesData != null && challengesData.isNotEmpty) {
        final decoded = jsonDecode(challengesData);
        if (decoded is List) {
          _challenges.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final id = item['id'] as String? ?? '';
              if (id.isNotEmpty) {
                _challenges[id] = Challenge.fromMap(id, item);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading challenges from disk: $e');
    }

    try {
      final opsData = await _engine.readAtomic('pending_challenge_ops.json');
      if (opsData != null && opsData.isNotEmpty) {
        final decoded = jsonDecode(opsData);
        if (decoded is List) {
          _pendingChallengeOps.clear();
          for (final item in decoded) {
            if (item is Map) {
              _pendingChallengeOps.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading pending challenge ops from disk: $e');
    }
  }

  Future<void> _saveChallengesToDisk() async {
    final list = _challenges.values
        .map((c) => _engine.sanitizeMapForDisk({'id': c.id, ...c.toMap()}))
        .toList();
    await _engine.writeAtomic('challenges.json', jsonEncode(list));
  }

  Future<void> _savePendingOpsToDisk() async {
    final list = _pendingChallengeOps.map((op) => _engine.sanitizeMapForDisk(op)).toList();
    await _engine.writeAtomic('pending_challenge_ops.json', jsonEncode(list));
  }

  Future<List<Challenge>> getLocalChallenges({required String userId}) async {
    await init();
    final list = _challenges.values
        .where((c) => userId.isEmpty || c.userId == userId)
        .toList();
    list.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    return list;
  }

  Future<void> saveChallengeLocally(Challenge challenge) async {
    await init();
    _challenges[challenge.id] = challenge;
    await _saveChallengesToDisk();
  }

  Future<void> markChallengeProgressLocally(
    String challengeId, {
    bool? isCompleted,
    int? currentCount,
  }) async {
    await init();
    final existing = _challenges[challengeId];
    if (existing != null) {
      final updated = existing.copyWith(
        isCompleted: isCompleted ?? existing.isCompleted,
        currentCount: currentCount ?? existing.currentCount,
      );
      _challenges[challengeId] = updated;
      await _saveChallengesToDisk();
    }
  }

  Future<void> deleteChallengeLocally(String challengeId) async {
    await init();
    _challenges.remove(challengeId);
    await _saveChallengesToDisk();
  }

  Future<void> syncChallengesFromRemote(List<Challenge> remoteChallenges) async {
    await init();
    for (final ch in remoteChallenges) {
      _challenges[ch.id] = ch;
    }
    await _saveChallengesToDisk();
  }

  Future<void> queuePendingChallengeOp(Map<String, dynamic> op) async {
    await init();
    _pendingChallengeOps.add(op);
    await _savePendingOpsToDisk();
  }

  Future<List<Map<String, dynamic>>> getPendingChallengeOps() async {
    await init();
    return List<Map<String, dynamic>>.from(_pendingChallengeOps);
  }

  Future<void> clearPendingChallengeOp(String opId) async {
    await init();
    _pendingChallengeOps.removeWhere((op) => op['opId'] == opId);
    await _savePendingOpsToDisk();
  }

  void clearMemoryCache() {
    _challenges.clear();
    _pendingChallengeOps.clear();
    _isLoaded = false;
  }
}
