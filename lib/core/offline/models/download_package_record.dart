/// Represents a downloaded educational package metadata record.
class DownloadPackageRecord {
  final String id;
  final String userId;
  final String packageType; // 'book', 'practice', 'past_exam'
  final String title;
  final String? grade;
  final String? stream;
  final String subject;
  final int? unitNumber;
  final String? unitName;
  final int? examYear;
  final int version;
  final int itemCount;
  final int sizeBytes;
  final DateTime downloadedAt;
  final String status; // 'downloaded', 'failed', 'updateAvailable'
  final Map<String, dynamic> extraData;

  const DownloadPackageRecord({
    required this.id,
    this.userId = '',
    required this.packageType,
    required this.title,
    this.grade,
    this.stream,
    required this.subject,
    this.unitNumber,
    this.unitName,
    this.examYear,
    this.version = 1,
    this.itemCount = 0,
    this.sizeBytes = 0,
    required this.downloadedAt,
    this.status = 'downloaded',
    this.extraData = const {},
  });

  factory DownloadPackageRecord.fromMap(Map<String, dynamic> map, {String fallbackUserId = ''}) {
    return DownloadPackageRecord(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? fallbackUserId,
      packageType: map['packageType'] as String? ?? 'practice',
      title: map['title'] as String? ?? '',
      grade: map['grade'] as String?,
      stream: map['stream'] as String?,
      subject: map['subject'] as String? ?? '',
      unitNumber: (map['unitNumber'] as num?)?.toInt(),
      unitName: map['unitName'] as String?,
      examYear: (map['examYear'] as num?)?.toInt(),
      version: (map['version'] as num?)?.toInt() ?? 1,
      itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      downloadedAt: map['downloadedAt'] != null
          ? DateTime.tryParse(map['downloadedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: map['status'] as String? ?? 'downloaded',
      extraData: map['extraData'] is Map
          ? Map<String, dynamic>.from(map['extraData'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'packageType': packageType,
      'title': title,
      'grade': grade,
      'stream': stream,
      'subject': subject,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'examYear': examYear,
      'version': version,
      'itemCount': itemCount,
      'sizeBytes': sizeBytes,
      'downloadedAt': downloadedAt.toIso8601String(),
      'status': status,
      'extraData': extraData,
    };
  }

  DownloadPackageRecord copyWith({
    String? id,
    String? userId,
    String? packageType,
    String? title,
    String? grade,
    String? stream,
    String? subject,
    int? unitNumber,
    String? unitName,
    int? examYear,
    int? version,
    int? itemCount,
    int? sizeBytes,
    DateTime? downloadedAt,
    String? status,
    Map<String, dynamic>? extraData,
  }) {
    return DownloadPackageRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      packageType: packageType ?? this.packageType,
      title: title ?? this.title,
      grade: grade ?? this.grade,
      stream: stream ?? this.stream,
      subject: subject ?? this.subject,
      unitNumber: unitNumber ?? this.unitNumber,
      unitName: unitName ?? this.unitName,
      examYear: examYear ?? this.examYear,
      version: version ?? this.version,
      itemCount: itemCount ?? this.itemCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      status: status ?? this.status,
      extraData: extraData ?? this.extraData,
    );
  }
}
