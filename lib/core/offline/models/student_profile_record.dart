import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a locally cached student profile record.
class StudentProfileRecord {
  final String uid;
  final String name;
  final String? email;
  final String grade;
  final String stream;
  final bool isPaid;
  final String accessStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final String? activePaymentId;
  final String? activeDeviceId;
  final DateTime cachedAt;

  const StudentProfileRecord({
    required this.uid,
    required this.name,
    this.email,
    required this.grade,
    required this.stream,
    this.isPaid = false,
    this.accessStatus = 'locked',
    this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.activePaymentId,
    this.activeDeviceId,
    required this.cachedAt,
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  factory StudentProfileRecord.fromMap(Map<String, dynamic> map, {String? fallbackUid}) {
    final uid = (map['uid'] as String?) ?? fallbackUid ?? '';
    return StudentProfileRecord(
      uid: uid,
      name: (map['name'] as String?)?.trim() ?? '',
      email: map['email'] as String?,
      grade: (map['grade'] as String?) ?? '',
      stream: (map['stream'] as String?) ?? '',
      isPaid: map['isPaid'] as bool? ?? false,
      accessStatus: map['accessStatus'] as String? ?? 'locked',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      paidAt: _parseDate(map['paidAt']),
      activePaymentId: map['activePaymentId'] as String?,
      activeDeviceId: map['activeDeviceId'] as String?,
      cachedAt: _parseDate(map['cachedAt']) ?? DateTime.now(),
    );
  }

  factory StudentProfileRecord.fromFirestore(String uid, Map<String, dynamic> data) {
    return StudentProfileRecord(
      uid: uid,
      name: (data['name'] as String?)?.trim() ?? '',
      email: data['email'] as String?,
      grade: (data['grade'] as String?) ?? '',
      stream: (data['stream'] as String?) ?? '',
      isPaid: data['isPaid'] as bool? ?? false,
      accessStatus: data['accessStatus'] as String? ?? 'locked',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      paidAt: _parseDate(data['paidAt']),
      activePaymentId: data['activePaymentId'] as String?,
      activeDeviceId: data['activeDeviceId'] as String?,
      cachedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'grade': grade,
      'stream': stream,
      'isPaid': isPaid,
      'accessStatus': accessStatus,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'activePaymentId': activePaymentId,
      'activeDeviceId': activeDeviceId,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }

  StudentProfileRecord copyWith({
    String? uid,
    String? name,
    String? email,
    String? grade,
    String? stream,
    bool? isPaid,
    String? accessStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
    String? activePaymentId,
    String? activeDeviceId,
    DateTime? cachedAt,
  }) {
    return StudentProfileRecord(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      grade: grade ?? this.grade,
      stream: stream ?? this.stream,
      isPaid: isPaid ?? this.isPaid,
      accessStatus: accessStatus ?? this.accessStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      activePaymentId: activePaymentId ?? this.activePaymentId,
      activeDeviceId: activeDeviceId ?? this.activeDeviceId,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentProfileRecord &&
        other.uid == uid &&
        other.name == name &&
        other.email == email &&
        other.grade == grade &&
        other.stream == stream &&
        other.isPaid == isPaid &&
        other.accessStatus == accessStatus &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.paidAt == paidAt &&
        other.activePaymentId == activePaymentId &&
        other.activeDeviceId == activeDeviceId;
  }

  @override
  int get hashCode => Object.hash(
        uid,
        name,
        email,
        grade,
        stream,
        isPaid,
        accessStatus,
        createdAt,
        updatedAt,
        paidAt,
        activePaymentId,
        activeDeviceId,
      );

  @override
  String toString() =>
      'StudentProfileRecord(uid: $uid, name: $name, email: $email, grade: $grade, stream: $stream, isPaid: $isPaid, accessStatus: $accessStatus, cachedAt: $cachedAt)';
}
