import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/offline/storage_engine.dart';
import '../question_model.dart';

/// Feature store managing local persistence and retrieval for Practice Questions.
class QuestionStore {
  static final QuestionStore _instance = QuestionStore._internal();
  factory QuestionStore({StorageEngine? engine}) {
    if (engine != null) {
      return QuestionStore._withEngine(engine);
    }
    return _instance;
  }
  QuestionStore._internal() : _engine = StorageEngine.instance;
  QuestionStore._withEngine(this._engine);

  final StorageEngine _engine;
  final Map<String, Question> _questions = {};
  bool _isLoaded = false;

  Future<void> init({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) return;
    await _engine.init();
    await _loadFromDisk();
    _isLoaded = true;
  }

  Future<void> _loadFromDisk() async {
    try {
      final data = await _engine.readAtomic('questions.json');
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          _questions.clear();
          for (final item in decoded) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final id = map['id'] as String? ?? '';
              if (id.isNotEmpty) {
                _questions[id] = Question.fromMap(id, map);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading questions from disk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    final list = _questions.values
        .map((q) => _engine.sanitizeMapForDisk({'id': q.id, ...q.toMap()}))
        .toList();
    await _engine.writeAtomic('questions.json', jsonEncode(list));
  }

  Future<void> saveQuestions(List<Question> questions) async {
    await init();
    for (final q in questions) {
      _questions[q.id] = q;
    }
    await _saveToDisk();
  }

  Future<void> removeQuestionsByIds(List<String> questionIds) async {
    await init();
    for (final id in questionIds) {
      _questions.remove(id);
    }
    await _saveToDisk();
  }

  Future<List<Question>> getOfflineQuestions({
    required String grade,
    required String stream,
    required String subject,
    required int unitNumber,
    int? examYear,
  }) async {
    await init();
    final cleanGrade = grade.trim().toLowerCase();
    final cleanSubject = subject.trim().toLowerCase();
    final cleanStream = stream.trim().toLowerCase();

    return _questions.values.where((q) {
      final qGrade = q.grade.trim().toLowerCase();
      final qSubject = q.subject.trim().toLowerCase();
      final qStream = q.stream.trim().toLowerCase();

      final gradeMatches = qGrade == cleanGrade ||
          qGrade.replaceAll(RegExp(r'[^0-9]'), '') ==
              cleanGrade.replaceAll(RegExp(r'[^0-9]'), '');
      if (!gradeMatches) return false;
      if (qSubject != cleanSubject) return false;
      if (unitNumber > 0 && q.unitNumber != unitNumber) return false;
      if (examYear != null && examYear > 0 && q.examYear != examYear) return false;

      final isSocial = cleanStream.contains('social');
      final qIsSocial = qStream.contains('social');
      if (isSocial != qIsSocial && qStream.isNotEmpty) return false;

      return true;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getOfflineUnits({
    required String grade,
    required String stream,
    required String subject,
  }) async {
    await init();
    final questions = await getOfflineQuestions(
      grade: grade,
      stream: stream,
      subject: subject,
      unitNumber: 0,
    );

    final Map<int, String> units = {};
    for (final q in questions) {
      if (q.unitNumber > 0) {
        if (!units.containsKey(q.unitNumber) ||
            (units[q.unitNumber]!.isEmpty && q.unitName.isNotEmpty)) {
          units[q.unitNumber] = q.unitName;
        }
      }
    }

    final result = units.entries.map((entry) {
      return {'number': entry.key, 'name': entry.value};
    }).toList();

    result.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return result;
  }

  Future<List<Question>> getOfflineQuestionsForSubject({
    required String stream,
    required String subject,
    String? grade,
  }) async {
    await init();
    final cleanStream = stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';
    final cleanSubject = subject.trim().toLowerCase();
    final cleanGrade = grade?.trim().toLowerCase();

    return _questions.values.where((q) {
      final qStream = q.stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';
      final qSub = q.subject.trim().toLowerCase();
      if (qStream != cleanStream) return false;
      if (qSub != cleanSubject) return false;
      if (cleanGrade != null && cleanGrade.isNotEmpty) {
        final qGrade = q.grade.trim().toLowerCase();
        final gradeMatches = qGrade == cleanGrade ||
            qGrade.replaceAll(RegExp(r'[^0-9]'), '') == cleanGrade.replaceAll(RegExp(r'[^0-9]'), '');
        if (!gradeMatches) return false;
      }
      return true;
    }).toList();
  }

  void clearMemoryCache() {
    _questions.clear();
    _isLoaded = false;
  }
}
