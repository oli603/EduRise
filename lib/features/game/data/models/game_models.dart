import 'dart:convert';

/// Record representing a single level's state, completion, and stars within a subject.
class GameLevelRecord {
  final int levelNumber;
  final bool isUnlocked;
  final bool isPassed;
  final int bestScore; // 0 to 5
  final int bestStars; // 0 to 3
  final int attemptsCount;
  final DateTime? lastPlayedAt;
  final List<String> lastQuestionIds;

  const GameLevelRecord({
    required this.levelNumber,
    this.isUnlocked = false,
    this.isPassed = false,
    this.bestScore = 0,
    this.bestStars = 0,
    this.attemptsCount = 0,
    this.lastPlayedAt,
    this.lastQuestionIds = const [],
  });

  GameLevelRecord copyWith({
    int? levelNumber,
    bool? isUnlocked,
    bool? isPassed,
    int? bestScore,
    int? bestStars,
    int? attemptsCount,
    DateTime? lastPlayedAt,
    List<String>? lastQuestionIds,
  }) {
    return GameLevelRecord(
      levelNumber: levelNumber ?? this.levelNumber,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isPassed: isPassed ?? this.isPassed,
      bestScore: bestScore ?? this.bestScore,
      bestStars: bestStars ?? this.bestStars,
      attemptsCount: attemptsCount ?? this.attemptsCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastQuestionIds: lastQuestionIds ?? this.lastQuestionIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'levelNumber': levelNumber,
      'isUnlocked': isUnlocked,
      'isPassed': isPassed,
      'bestScore': bestScore,
      'bestStars': bestStars,
      'attemptsCount': attemptsCount,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'lastQuestionIds': lastQuestionIds,
    };
  }

  factory GameLevelRecord.fromMap(Map<String, dynamic> map) {
    return GameLevelRecord(
      levelNumber: (map['levelNumber'] as num?)?.toInt() ?? 1,
      isUnlocked: map['isUnlocked'] == true,
      isPassed: map['isPassed'] == true,
      bestScore: (map['bestScore'] as num?)?.toInt() ?? 0,
      bestStars: (map['bestStars'] as num?)?.toInt() ?? 0,
      attemptsCount: (map['attemptsCount'] as num?)?.toInt() ?? 0,
      lastPlayedAt: map['lastPlayedAt'] != null
          ? DateTime.tryParse(map['lastPlayedAt'] as String)
          : null,
      lastQuestionIds: (map['lastQuestionIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Active session state for a level currently in progress.
/// Preserves exact 5 questions, current index, chosen answers, and score across app restarts.
class ActiveGameLevelState {
  final String subject;
  final String stream;
  final int levelNumber;
  final List<String> questionIds; // Exactly 5 question IDs
  final int currentIndex; // 0 to 4
  final Map<int, String> answers; // question index -> chosen answer text
  final int score;
  final bool isCompleted;
  final DateTime startedAt;

  const ActiveGameLevelState({
    required this.subject,
    required this.stream,
    required this.levelNumber,
    required this.questionIds,
    this.currentIndex = 0,
    this.answers = const {},
    this.score = 0,
    this.isCompleted = false,
    required this.startedAt,
  });

  ActiveGameLevelState copyWith({
    String? subject,
    String? stream,
    int? levelNumber,
    List<String>? questionIds,
    int? currentIndex,
    Map<int, String>? answers,
    int? score,
    bool? isCompleted,
    DateTime? startedAt,
  }) {
    return ActiveGameLevelState(
      subject: subject ?? this.subject,
      stream: stream ?? this.stream,
      levelNumber: levelNumber ?? this.levelNumber,
      questionIds: questionIds ?? this.questionIds,
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      score: score ?? this.score,
      isCompleted: isCompleted ?? this.isCompleted,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'stream': stream,
      'levelNumber': levelNumber,
      'questionIds': questionIds,
      'currentIndex': currentIndex,
      'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
      'score': score,
      'isCompleted': isCompleted,
      'startedAt': startedAt.toIso8601String(),
    };
  }

  factory ActiveGameLevelState.fromMap(Map<String, dynamic> map) {
    final rawAnswers = map['answers'] as Map?;
    final Map<int, String> parsedAnswers = {};
    if (rawAnswers != null) {
      for (final entry in rawAnswers.entries) {
        final key = int.tryParse(entry.key.toString());
        if (key != null && entry.value != null) {
          parsedAnswers[key] = entry.value.toString();
        }
      }
    }

    return ActiveGameLevelState(
      subject: map['subject'] as String? ?? '',
      stream: map['stream'] as String? ?? '',
      levelNumber: (map['levelNumber'] as num?)?.toInt() ?? 1,
      questionIds: (map['questionIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      currentIndex: (map['currentIndex'] as num?)?.toInt() ?? 0,
      answers: parsedAnswers,
      score: (map['score'] as num?)?.toInt() ?? 0,
      isCompleted: map['isCompleted'] == true,
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ActiveGameLevelState.fromJson(String source) =>
      ActiveGameLevelState.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Aggregated game progress for a specific stream and subject.
class GameProgressSummary {
  final String subject;
  final String stream;
  final Map<int, GameLevelRecord> levels;
  final List<String> recentQuestionHistory;

  const GameProgressSummary({
    required this.subject,
    required this.stream,
    required this.levels,
    this.recentQuestionHistory = const [],
  });

  int get totalStarsEarned =>
      levels.values.fold<int>(0, (sum, lvl) => sum + lvl.bestStars);

  int get totalStars => totalStarsEarned;

  int get totalLevelsPassed =>
      levels.values.where((lvl) => lvl.isPassed).length;

  int get passedLevelsCount => totalLevelsPassed;

  int get totalLevelsUnlocked =>
      levels.values.where((lvl) => lvl.isUnlocked).length;

  int get unlockedLevelsCount => totalLevelsUnlocked;

  int get highestUnlockedLevel {
    if (levels.isEmpty) return 1;
    int maxLevel = 1;
    for (final lvl in levels.values) {
      if (lvl.isUnlocked && lvl.levelNumber > maxLevel) {
        maxLevel = lvl.levelNumber;
      }
    }
    return maxLevel;
  }

  GameLevelRecord getLevel(int levelNumber) {
    if (levels.containsKey(levelNumber)) {
      return levels[levelNumber]!;
    }
    // Default level 1 is unlocked, level 2+ locked
    return GameLevelRecord(
      levelNumber: levelNumber,
      isUnlocked: levelNumber == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'stream': stream,
      'levels': levels.map((k, v) => MapEntry(k.toString(), v.toMap())),
      'recentQuestionHistory': recentQuestionHistory,
    };
  }

  factory GameProgressSummary.fromMap(Map<String, dynamic> map) {
    final subject = map['subject'] as String? ?? '';
    final stream = map['stream'] as String? ?? '';
    final rawLevels = map['levels'] as Map?;
    final Map<int, GameLevelRecord> parsedLevels = {};

    if (rawLevels != null) {
      for (final entry in rawLevels.entries) {
        final key = int.tryParse(entry.key.toString());
        if (key != null && entry.value is Map) {
          parsedLevels[key] = GameLevelRecord.fromMap(Map<String, dynamic>.from(entry.value as Map));
        }
      }
    }

    // Always ensure Level 1 exists and is unlocked
    if (!parsedLevels.containsKey(1)) {
      parsedLevels[1] = const GameLevelRecord(levelNumber: 1, isUnlocked: true);
    }

    return GameProgressSummary(
      subject: subject,
      stream: stream,
      levels: parsedLevels,
      recentQuestionHistory:
          (map['recentQuestionHistory'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  String toJson() => jsonEncode(toMap());
  factory GameProgressSummary.fromJson(String source) =>
      GameProgressSummary.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
