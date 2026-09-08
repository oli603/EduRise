/// Centralized subjects reflecting the Ethiopian New Curriculum
/// for Grades 9–12 and EduRise stream structures.
class EduRiseSubjects {
  // Upper secondary (Grades 11 & 12) Natural Science Stream
  static const List<String> naturalStream = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
  ];

  // Upper secondary (Grades 11 & 12) Social Science Stream
  static const List<String> socialStream = [
    'Mathematics',
    'Economics',
    'Geography',
    'History',
    'English',
  ];

  // Entrance Exam subjects (includes SAT / Scholastic Aptitude Test)
  static const List<String> naturalEntranceExam = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'SAT',
  ];

  static const List<String> socialEntranceExam = [
    'Mathematics',
    'History',
    'Geography',
    'Economics',
    'English',
    'SAT',
  ];

  // Lower secondary (Grades 9 & 10) common foundational curriculum
  static const List<String> foundationGrades9And10 = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Geography',
    'History',
    'Economics',
  ];

  /// Get practice subjects appropriate for the student's stream and optional grade.
  static List<String> getPracticeSubjects({
    required String stream,
    String? grade,
  }) {
    final canonical = stream.toLowerCase().trim();
    final isSocial = canonical.contains('social');

    // For Grade 9 & 10, foundational subjects are available with stream emphasis
    if (grade != null && (grade.contains('9') || grade.contains('10'))) {
      if (isSocial) {
        return const [
          'Mathematics',
          'Economics',
          'Geography',
          'History',
          'English',
        ];
      }
      return const [
        'Mathematics',
        'Physics',
        'Chemistry',
        'Biology',
        'English',
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
    final isSocial = stream.toLowerCase().contains('social');

    if (isHigherGrade) {
      return isSocial ? socialStream : naturalStream;
    }

    // For Grades 9 & 10, foundational curriculum
    return foundationGrades9And10;
  }

  /// Get subjects for entrance exams
  static List<String> getEntranceExamSubjects({required String stream}) {
    final isSocial = stream.toLowerCase().contains('social');
    return isSocial ? socialEntranceExam : naturalEntranceExam;
  }
}
