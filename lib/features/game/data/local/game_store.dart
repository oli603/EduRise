import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/offline/storage_engine.dart';
import '../models/game_models.dart';

/// Feature store managing local game progression and session state.
///
/// Ensures strict per-user account isolation by prefixing progress and
/// active session keys with the student's Firebase UID.
class GameStore {
  static final GameStore _instance = GameStore._internal();
  factory GameStore({StorageEngine? engine}) {
    if (engine != null) {
      return GameStore._withEngine(engine);
    }
    return _instance;
  }
  GameStore._internal() : _engine = StorageEngine.instance;
  GameStore._withEngine(this._engine);

  final StorageEngine _engine;
  final Map<String, GameProgressSummary> _gameProgress = {};
  final Map<String, ActiveGameLevelState> _activeLevelsByUid = {};
  bool _isLoaded = false;

  Future<void> init({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) return;
    await _engine.init();
    await _loadFromDisk();
    _isLoaded = true;
  }

  String _getGameProgressKey(String? userId, String stream, String subject) {
    final str = stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';
    final sub = subject.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    if (userId != null && userId.trim().isNotEmpty) {
      return '${userId.trim()}_${str}_$sub';
    }
    return '${str}_$sub';
  }

  Future<void> _loadFromDisk() async {
    try {
      final data = await _engine.readAtomic('game_progress.json');
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        _gameProgress.clear();
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final summary = GameProgressSummary.fromMap(map);
              final uid = map['userId'] as String?;
              final key = _getGameProgressKey(uid, summary.stream, summary.subject);
              _gameProgress[key] = summary;
            }
          }
        } else if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map) {
              final summary = GameProgressSummary.fromMap(Map<String, dynamic>.from(v));
              _gameProgress[k.toString()] = summary;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading game progress from disk: $e');
    }

    try {
      final data = await _engine.readAtomic('active_game_level.json');
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        _activeLevelsByUid.clear();
        if (decoded is Map) {
          if (decoded.containsKey('subject') && decoded.containsKey('stream')) {
            // Legacy single active level format
            final state = ActiveGameLevelState.fromMap(Map<String, dynamic>.from(decoded));
            _activeLevelsByUid['default'] = state;
          } else {
            // Multi-user dictionary format: uid -> ActiveGameLevelState
            decoded.forEach((k, v) {
              if (v is Map) {
                _activeLevelsByUid[k.toString()] =
                    ActiveGameLevelState.fromMap(Map<String, dynamic>.from(v));
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading active game level from disk: $e');
    }
  }

  Future<void> _saveProgressToDisk() async {
    final list = _gameProgress.entries.map((entry) {
      final map = entry.value.toMap();
      // Extract userId from key if present
      final parts = entry.key.split('_');
      if (parts.length >= 3) {
        map['userId'] = parts[0];
      }
      return _engine.sanitizeMapForDisk(map);
    }).toList();
    await _engine.writeAtomic('game_progress.json', jsonEncode(list));
  }

  Future<void> _saveActiveLevelsToDisk() async {
    final map = <String, dynamic>{};
    _activeLevelsByUid.forEach((uid, state) {
      map[uid] = _engine.sanitizeMapForDisk(state.toMap());
    });
    await _engine.writeAtomic('active_game_level.json', jsonEncode(map));
  }

  Future<GameProgressSummary> getGameProgress({
    String? userId,
    required String stream,
    required String subject,
  }) async {
    await init();
    final canonicalStream = stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';
    final key = _getGameProgressKey(userId, canonicalStream, subject);

    if (_gameProgress.containsKey(key)) {
      return _gameProgress[key]!;
    }

    // Default initial progress (Level 1 unlocked, 0 stars)
    final newSummary = GameProgressSummary(
      subject: subject,
      stream: canonicalStream,
      levels: {
        1: const GameLevelRecord(levelNumber: 1, isUnlocked: true),
      },
    );
    _gameProgress[key] = newSummary;
    return newSummary;
  }

  Future<void> saveGameProgress(
    GameProgressSummary summary, {
    String? userId,
  }) async {
    await init();
    final key = _getGameProgressKey(userId, summary.stream, summary.subject);
    _gameProgress[key] = summary;
    await _saveProgressToDisk();
  }

  Future<ActiveGameLevelState?> getActiveGameLevel({String? userId}) async {
    await init();
    final uid = userId?.trim().isNotEmpty == true ? userId!.trim() : 'default';
    return _activeLevelsByUid[uid];
  }

  Future<void> saveActiveGameLevel(
    ActiveGameLevelState state, {
    String? userId,
  }) async {
    await init();
    final uid = userId?.trim().isNotEmpty == true ? userId!.trim() : 'default';
    _activeLevelsByUid[uid] = state;
    await _saveActiveLevelsToDisk();
  }

  Future<void> clearActiveGameLevel({String? userId}) async {
    await init();
    final uid = userId?.trim().isNotEmpty == true ? userId!.trim() : 'default';
    _activeLevelsByUid.remove(uid);
    await _saveActiveLevelsToDisk();
  }

  void clearMemoryCache() {
    _gameProgress.clear();
    _activeLevelsByUid.clear();
    _isLoaded = false;
  }
}
