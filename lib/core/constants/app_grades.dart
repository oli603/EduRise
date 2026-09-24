/// Canonical grades for the Ethiopian secondary curriculum in EduRise.
class EduRiseGrades {
  EduRiseGrades._();

  static const String grade9 = 'Grade 9';
  static const String grade10 = 'Grade 10';
  static const String grade11 = 'Grade 11';
  static const String grade12 = 'Grade 12';

  /// All supported secondary education grades in EduRise.
  static const List<String> all = [
    grade9,
    grade10,
    grade11,
    grade12,
  ];

  /// Canonicalizes an arbitrary grade string to one of the standard Grade constants.
  /// Falls back to [grade12] if unrecognizable.
  static String canonicalize(String? input) {
    if (input == null || input.trim().isEmpty) return grade12;
    final trimmed = input.trim();
    if (trimmed.contains('10')) return grade10;
    if (trimmed.contains('11')) return grade11;
    if (trimmed.contains('12')) return grade12;
    if (trimmed.contains('9')) return grade9;
    return grade12;
  }

  /// Checks if the input grade represents a recognized EduRise secondary grade (9, 10, 11, 12).
  static bool isValid(String? input) {
    if (input == null || input.trim().isEmpty) return false;
    final trimmed = input.trim().toLowerCase();
    if (trimmed.contains('10') ||
        trimmed.contains('11') ||
        trimmed.contains('12') ||
        (trimmed.contains('9') && !trimmed.contains('8') && !trimmed.contains('7'))) {
      return true;
    }
    return false;
  }
}
