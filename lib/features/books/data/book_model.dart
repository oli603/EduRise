class BookUnit {
  final String id;
  final String grade;
  final String subject;
  final int unitNumber;
  final String unitName;
  final String pdfUrl;
  final DateTime? createdAt;

  const BookUnit({
    required this.id,
    required this.grade,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
    required this.pdfUrl,
    this.createdAt,
  });

  factory BookUnit.fromMap(String id, Map<String, dynamic> data) {
    return BookUnit(
      id: id,
      grade: data['grade'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      unitNumber: data['unitNumber'] as int? ?? 0,
      unitName: data['unitName'] as String? ?? '',
      pdfUrl: data['pdfUrl'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'grade': grade,
      'subject': subject,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'pdfUrl': pdfUrl,
      'createdAt': createdAt,
    };
  }
}
