import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/offline/storage_engine.dart';
import '../study_task_model.dart';

/// Feature store managing local persistence and sync queuing for Study Tasks.
class StudyTaskStore {
  static final StudyTaskStore _instance = StudyTaskStore._internal();
  factory StudyTaskStore({StorageEngine? engine}) {
    if (engine != null) {
      return StudyTaskStore._withEngine(engine);
    }
    return _instance;
  }
  StudyTaskStore._internal() : _engine = StorageEngine.instance;
  StudyTaskStore._withEngine(this._engine);

  final StorageEngine _engine;
  final Map<String, StudyTask> _studyTasks = {};
  final List<Map<String, dynamic>> _pendingTaskOps = [];
  bool _isLoaded = false;

  Future<void> init({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) return;
    await _engine.init();
    await _loadFromDisk();
    _isLoaded = true;
  }

  Future<void> _loadFromDisk() async {
    try {
      final tasksData = await _engine.readAtomic('study_tasks.json');
      if (tasksData != null && tasksData.isNotEmpty) {
        final decoded = jsonDecode(tasksData);
        if (decoded is List) {
          _studyTasks.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final id = item['id'] as String? ?? '';
              if (id.isNotEmpty) {
                _studyTasks[id] = StudyTask.fromMap(id, item);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading study tasks from disk: $e');
    }

    try {
      final opsData = await _engine.readAtomic('pending_task_ops.json');
      if (opsData != null && opsData.isNotEmpty) {
        final decoded = jsonDecode(opsData);
        if (decoded is List) {
          _pendingTaskOps.clear();
          for (final item in decoded) {
            if (item is Map) {
              _pendingTaskOps.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading pending task ops from disk: $e');
    }
  }

  Future<void> _saveTasksToDisk() async {
    final list = _studyTasks.values
        .map((t) => _engine.sanitizeMapForDisk({'id': t.id, ...t.toMap()}))
        .toList();
    await _engine.writeAtomic('study_tasks.json', jsonEncode(list));
  }

  Future<void> _savePendingOpsToDisk() async {
    final list = _pendingTaskOps.map((op) => _engine.sanitizeMapForDisk(op)).toList();
    await _engine.writeAtomic('pending_task_ops.json', jsonEncode(list));
  }

  Future<List<StudyTask>> getLocalStudyTasks({required String userId}) async {
    await init();
    final tasks = _studyTasks.values
        .where((t) => userId.isEmpty || t.userId == userId)
        .toList();
    tasks.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return tasks;
  }

  Future<void> saveStudyTaskLocally(StudyTask task) async {
    await init();
    _studyTasks[task.id] = task;
    await _saveTasksToDisk();
  }

  Future<void> deleteStudyTaskLocally(String taskId) async {
    await init();
    _studyTasks.remove(taskId);
    await _saveTasksToDisk();
  }

  Future<void> syncStudyTasksFromRemote(List<StudyTask> remoteTasks) async {
    await init();
    for (final task in remoteTasks) {
      _studyTasks[task.id] = task;
    }
    await _saveTasksToDisk();
  }

  Future<void> queuePendingStudyTaskOp(Map<String, dynamic> op) async {
    await init();
    _pendingTaskOps.add(op);
    await _savePendingOpsToDisk();
  }

  Future<List<Map<String, dynamic>>> getPendingStudyTaskOps() async {
    await init();
    return List<Map<String, dynamic>>.from(_pendingTaskOps);
  }

  Future<void> clearPendingStudyTaskOp(String opId) async {
    await init();
    _pendingTaskOps.removeWhere((op) => op['opId'] == opId);
    await _savePendingOpsToDisk();
  }

  void clearMemoryCache() {
    _studyTasks.clear();
    _pendingTaskOps.clear();
    _isLoaded = false;
  }
}
