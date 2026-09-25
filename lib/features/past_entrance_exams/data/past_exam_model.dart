class PastExamQuestion {
  final String? id;
  final int questionNumber;
  final String questionText;
  final String? imageUrl;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;
  final String explanation;

  const PastExamQuestion({
    this.id,
    required this.questionNumber,
    required this.questionText,
    this.imageUrl,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'questionNumber': questionNumber,
      'questionText': questionText,
      'imageUrl': imageUrl,
      'optionA': optionA,
      'optionB': optionB,
      'optionC': optionC,
      'optionD': optionD,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }

  factory PastExamQuestion.fromMap(Map<String, dynamic> map) {
    // 0. Build normalized key-value lookup (lowercase, stripped of spaces and symbols)
    final normalized = <String, dynamic>{};
    map.forEach((k, v) {
      final cleanKey = k.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      normalized[cleanKey] = v;
    });

    // 1. Resilient question text extraction
    final qText = (normalized['questiontext'] ??
            normalized['question'] ??
            normalized['text'] ??
            normalized['prompt'] ??
            normalized['body'] ??
            normalized['content'] ??
            normalized['desc'] ??
            normalized['description'])
        ?.toString()
        .trim() ??
        '';

    // 2. Resilient options extraction (supports discrete option keys, options array, or choices map)
    List<String>? optionsArray;
    final rawOptions = normalized['options'] ?? normalized['choices'];
    if (rawOptions is List) {
      optionsArray = rawOptions.map((e) => e?.toString() ?? '').toList();
    }

    Map<dynamic, dynamic>? optionsMap;
    if (rawOptions is Map) {
      optionsMap = rawOptions;
    }

    String optA = (normalized['optiona'] ??
            normalized['choicea'] ??
            normalized['a'] ??
            normalized['opta'])
        ?.toString()
        .trim() ??
        '';
    String optB = (normalized['optionb'] ??
            normalized['choiceb'] ??
            normalized['b'] ??
            normalized['optb'])
        ?.toString()
        .trim() ??
        '';
    String optC = (normalized['optionc'] ??
            normalized['choicec'] ??
            normalized['c'] ??
            normalized['optc'])
        ?.toString()
        .trim() ??
        '';
    String optD = (normalized['optiond'] ??
            normalized['choiced'] ??
            normalized['d'] ??
            normalized['optd'])
        ?.toString()
        .trim() ??
        '';

    if (optA.isEmpty && optionsArray != null && optionsArray.isNotEmpty) {
      optA = optionsArray[0].trim();
    }
    if (optB.isEmpty && optionsArray != null && optionsArray.length > 1) {
      optB = optionsArray[1].trim();
    }
    if (optC.isEmpty && optionsArray != null && optionsArray.length > 2) {
      optC = optionsArray[2].trim();
    }
    if (optD.isEmpty && optionsArray != null && optionsArray.length > 3) {
      optD = optionsArray[3].trim();
    }

    if (optA.isEmpty && optionsMap != null) {
      optA = (optionsMap['A'] ?? optionsMap['a'] ?? optionsMap['1'] ?? '')?.toString().trim() ?? '';
    }
    if (optB.isEmpty && optionsMap != null) {
      optB = (optionsMap['B'] ?? optionsMap['b'] ?? optionsMap['2'] ?? '')?.toString().trim() ?? '';
    }
    if (optC.isEmpty && optionsMap != null) {
      optC = (optionsMap['C'] ?? optionsMap['c'] ?? optionsMap['3'] ?? '')?.toString().trim() ?? '';
    }
    if (optD.isEmpty && optionsMap != null) {
      optD = (optionsMap['D'] ?? optionsMap['d'] ?? optionsMap['4'] ?? '')?.toString().trim() ?? '';
    }

    // 3. Resilient question number
    final qNum = int.tryParse(normalized['questionnumber']?.toString() ?? '') ??
        int.tryParse(normalized['number']?.toString() ?? '') ??
        int.tryParse(normalized['index']?.toString() ?? '') ??
        int.tryParse(normalized['qnum']?.toString() ?? '') ??
        0;

    // 4. Resilient image URL
    final imgUrl = (normalized['imageurl'] ??
            normalized['image'] ??
            normalized['questionimageurl'] ??
            normalized['photourl'])
        ?.toString();

    // 5. Resilient correct answer & explanation
    String correct = (normalized['correctanswer'] ??
            normalized['answer'] ??
            normalized['answerletter'] ??
            normalized['correct'] ??
            normalized['ans'])
        ?.toString()
        .trim() ??
        '';

    // Normalize answer string to 'A', 'B', 'C', or 'D'
    final upperCorrect = correct.toUpperCase().trim();
    if (upperCorrect == 'A' || upperCorrect == 'B' || upperCorrect == 'C' || upperCorrect == 'D') {
      correct = upperCorrect;
    } else if (upperCorrect.startsWith('OPTION A') || upperCorrect.startsWith('CHOICE A') || upperCorrect.startsWith('(A)') || (upperCorrect.startsWith('A') && upperCorrect.length <= 4)) {
      correct = 'A';
    } else if (upperCorrect.startsWith('OPTION B') || upperCorrect.startsWith('CHOICE B') || upperCorrect.startsWith('(B)') || (upperCorrect.startsWith('B') && upperCorrect.length <= 4)) {
      correct = 'B';
    } else if (upperCorrect.startsWith('OPTION C') || upperCorrect.startsWith('CHOICE C') || upperCorrect.startsWith('(C)') || (upperCorrect.startsWith('C') && upperCorrect.length <= 4)) {
      correct = 'C';
    } else if (upperCorrect.startsWith('OPTION D') || upperCorrect.startsWith('CHOICE D') || upperCorrect.startsWith('(D)') || (upperCorrect.startsWith('D') && upperCorrect.length <= 4)) {
      correct = 'D';
    } else if (optA.isNotEmpty && upperCorrect == optA.toUpperCase()) {
      correct = 'A';
    } else if (optB.isNotEmpty && upperCorrect == optB.toUpperCase()) {
      correct = 'B';
    } else if (optC.isNotEmpty && upperCorrect == optC.toUpperCase()) {
      correct = 'C';
    } else if (optD.isNotEmpty && upperCorrect == optD.toUpperCase()) {
      correct = 'D';
    }

    final expl = (normalized['explanation'] ??
            normalized['rationale'] ??
            normalized['solution'] ??
            normalized['reason'] ??
            normalized['explanationtext'])
        ?.toString()
        .trim() ??
        '';

    return PastExamQuestion(
      id: normalized['id']?.toString() ?? normalized['questionid']?.toString(),
      questionNumber: qNum,
      questionText: qText,
      imageUrl: (imgUrl != null && imgUrl.isNotEmpty) ? imgUrl : null,
      optionA: optA,
      optionB: optB,
      optionC: optC,
      optionD: optD,
      correctAnswer: correct,
      explanation: expl,
    );
  }

  PastExamQuestion copyWith({
    String? id,
    int? questionNumber,
    String? questionText,
    String? imageUrl,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    String? correctAnswer,
    String? explanation,
  }) {
    return PastExamQuestion(
      id: id ?? this.id,
      questionNumber: questionNumber ?? this.questionNumber,
      questionText: questionText ?? this.questionText,
      imageUrl: imageUrl ?? this.imageUrl,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
    );
  }
}

class PastExam {
  final String id;
  final String year;
  final String stream;
  final String? round;
  final String subject;
  final int durationMinutes;
  final List<PastExamQuestion> questions;

  const PastExam({
    required this.id,
    required this.year,
    required this.stream,
    this.round,
    required this.subject,
    required this.durationMinutes,
    required this.questions,
  });

  String get title => '$year $subject Entrance Exam${round != null && round!.isNotEmpty ? ' ($round)' : ''}';
  int get questionCount => questions.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'stream': stream,
      'round': round,
      'subject': subject,
      'durationMinutes': durationMinutes,
      'questionCount': questions.length,
      'questions': questions.map((question) => question.toMap()).toList(),
    };
  }

  factory PastExam.fromMap(String id, Map<String, dynamic> map) {
    final normalized = <String, dynamic>{};
    map.forEach((k, v) {
      final cleanKey = k.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      normalized[cleanKey] = v;
    });

    final questionData = (normalized['questions'] ?? map['questions']) as List<dynamic>? ?? [];

    final rawDuration = normalized['durationminutes'] ?? normalized['duration'];
    int duration = (rawDuration is num)
        ? rawDuration.toInt()
        : (int.tryParse(rawDuration?.toString() ?? '') ?? 0);
    final subjectStr = (normalized['subject'] ?? map['subject'])?.toString() ?? '';
    if (duration <= 0) {
      final isMath = subjectStr.toLowerCase().contains('math');
      duration = isMath ? 180 : 120;
    }

    return PastExam(
      id: id,
      year: (normalized['year'] ?? map['year'])?.toString() ?? '',
      stream: (normalized['stream'] ?? map['stream'])?.toString() ?? '',
      round: (normalized['round'] ?? map['round'])?.toString(),
      subject: subjectStr,
      durationMinutes: duration,
      questions: questionData
          .whereType<Map>()
          .map(
            (question) =>
                PastExamQuestion.fromMap(Map<String, dynamic>.from(question)),
          )
          .toList(),
    );
  }

  PastExam copyWith({
    String? id,
    String? year,
    String? stream,
    String? round,
    String? subject,
    int? durationMinutes,
    List<PastExamQuestion>? questions,
  }) {
    return PastExam(
      id: id ?? this.id,
      year: year ?? this.year,
      stream: stream ?? this.stream,
      round: round ?? this.round,
      subject: subject ?? this.subject,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      questions: questions ?? this.questions,
    );
  }
}
