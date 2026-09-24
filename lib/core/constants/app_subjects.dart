/// Centralized subjects reflecting the Ethiopian New Curriculum
/// for Grades 9–12 and EduRise stream structures.
class EduRiseSubjects {
  // Canonical Subject Name Constants
  static const String mathematics = 'Mathematics';
  static const String physics = 'Physics';
  static const String chemistry = 'Chemistry';
  static const String biology = 'Biology';
  static const String english = 'English';
  static const String satSubject = 'SAT';
  static const String history = 'History';
  static const String geography = 'Geography';
  static const String economics = 'Economics';
  static const String civics = 'Civics';

  /// Canonicalizes arbitrary subject strings (e.g. "Math", "maths", "Aptitude", "geog")
  /// to the single authoritative EduRise subject name.
  static String canonicalize(String? input) {
    if (input == null || input.trim().isEmpty) return 'General';
    final trimmed = input.trim();
    final lower = trimmed.toLowerCase();

    if (lower == 'math' || lower == 'maths' || lower == 'mathematics') return mathematics;
    if (lower == 'phys' || lower == 'physics') return physics;
    if (lower == 'chem' || lower == 'chemistry') return chemistry;
    if (lower == 'bio' || lower == 'biology') return biology;
    if (lower == 'eng' || lower == 'english') return english;
    if (lower == 'sat' || lower == 'aptitude' || lower == 'scholastic aptitude test' || lower == 'scholastic aptitude') return satSubject;
    if (lower == 'hist' || lower == 'history') return history;
    if (lower == 'geo' || lower == 'geog' || lower == 'geography') return geography;
    if (lower == 'econ' || lower == 'economics') return economics;
    if (lower == 'civ' || lower == 'civics' || lower == 'citizenship') return civics;

    return trimmed;
  }

  // Upper secondary (Grades 11 & 12) Natural Science Stream
  static const List<String> naturalStream = [
    mathematics,
    physics,
    chemistry,
    biology,
    english,
    satSubject,
  ];

  // Upper secondary (Grades 11 & 12) Social Science Stream
  static const List<String> socialStream = [
    mathematics,
    history,
    geography,
    economics,
    english,
    satSubject,
  ];

  // Entrance Exam subjects (includes SAT / Scholastic Aptitude Test)
  static const List<String> naturalEntranceExam = [
    mathematics,
    physics,
    chemistry,
    biology,
    english,
    satSubject,
  ];

  static const List<String> socialEntranceExam = [
    mathematics,
    history,
    geography,
    economics,
    english,
    satSubject,
  ];

  // Lower secondary (Grades 9 & 10) common foundational curriculum
  static const List<String> foundationGrades9And10 = [
    mathematics,
    physics,
    chemistry,
    biology,
    english,
    geography,
    history,
    economics,
    satSubject,
  ];

  /// Canonical internal storage value for stream: strictly 'natural' or 'social'.
  static String canonicalizeStream(String? stream) {
    if (stream == null || stream.trim().isEmpty) return 'natural';
    final lower = stream.trim().toLowerCase();
    if (lower.contains('social')) return 'social';
    return 'natural';
  }

  /// Canonical human-readable display value for stream.
  static String displayStream(String? stream) {
    return isSocialStream(stream) ? 'Social Science' : 'Natural Science';
  }

  /// Safe helper to detect social stream
  static bool isSocialStream(String? stream) {
    if (stream == null) return false;
    final canonical = stream.toLowerCase().trim();
    return canonical.contains('social');
  }

  /// Checks if a subject is permitted for the given stream.
  static bool isSubjectAllowedForStream(String subject, String stream) {
    final canonSubject = canonicalize(subject);
    final isSocial = isSocialStream(stream);
    final allowedList = isSocial ? socialStream : naturalStream;
    return allowedList.contains(canonSubject) || canonSubject == 'General';
  }

  /// Get practice subjects appropriate for the student's stream and optional grade.
  static List<String> getPracticeSubjects({
    required String stream,
    String? grade,
  }) {
    final isSocial = isSocialStream(stream);

    // For Grade 9 & 10, foundational subjects are available with stream emphasis + SAT
    if (grade != null && (grade.contains('9') || grade.contains('10'))) {
      if (isSocial) {
        return const [
          mathematics,
          history,
          geography,
          economics,
          english,
          satSubject,
        ];
      }
      return const [
        mathematics,
        physics,
        chemistry,
        biology,
        english,
        satSubject,
      ];
    }

    if (isSocial) {
      return socialStream;
    }
    return naturalStream;
  }

  /// Get subjects for the Profile Subjects display bottom sheet
  static List<String> getProfileSubjects({
    required String stream,
    required String grade,
  }) {
    final isHigherGrade = grade.contains('11') || grade.contains('12');
    final isSocial = isSocialStream(stream);

    if (isHigherGrade) {
      return isSocial ? socialStream : naturalStream;
    }

    // For Grades 9 & 10, foundational curriculum with stream emphasis + SAT
    return getPracticeSubjects(stream: stream, grade: grade);
  }

  /// Get subjects for entrance exams
  static List<String> getEntranceExamSubjects({required String stream}) {
    final isSocial = isSocialStream(stream);
    return isSocial ? socialEntranceExam : naturalEntranceExam;
  }

  /// Get subjects for Challenges
  static List<String> getChallengeSubjects({required String stream}) {
    return isSocialStream(stream) ? socialStream : naturalStream;
  }

  /// Get subjects for Study Plan
  static List<String> getStudyPlanSubjects({required String stream}) {
    return isSocialStream(stream) ? socialStream : naturalStream;
  }

  /// Get subjects for Home screen cards
  static List<String> getHomeSubjects({required String stream}) {
    return isSocialStream(stream) ? socialStream : naturalStream;
  }

  /// Get authoritative entrance exam question count for a subject.
  /// Mathematics: 45 questions
  /// English: 60 questions
  /// SAT / Aptitude: 60 questions
  /// All other natural & social sciences: 50 questions
  static int getEntranceExamQuestionCount(String subject) {
    final canonical = canonicalize(subject);
    if (canonical == mathematics) return 45;
    if (canonical == english || canonical == satSubject) return 60;
    return 50;
  }

  /// Get entrance exam duration for a subject.
  /// Mathematics = 3 hours (180 minutes), all other subjects = 2 hours (120 minutes).
  static Duration getEntranceExamDuration(String subject) {
    final canonical = canonicalize(subject);
    if (canonical == mathematics) {
      return const Duration(hours: 3);
    }
    return const Duration(hours: 2);
  }
}
