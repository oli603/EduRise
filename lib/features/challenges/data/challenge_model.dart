import 'package:cloud_firestore/cloud_firestore.dart';

class Challenge {
  final String id;
  final String userId;

  final String title;
  final String description;

  final String challengeType;

  final String grade;
  final String subject;

  // The exact unit this challenge belongs to.
  final int unitNumber;
  final String unitName;

  final int targetCount;
  final int currentCount;

  final DateTime scheduledDate;

  final bool isCompleted;

  final int rewardXp;

  final DateTime? createdAt;

  const Challenge({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.challengeType,
    required this.grade,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
    required this.targetCount,
    required this.currentCount,
    required this.scheduledDate,
    required this.isCompleted,
    required this.rewardXp,
    this.createdAt,
  });

  factory Challenge.fromMap(String id, Map<String, dynamic> data) {
    return Challenge(
      id: id,
      userId: data['userId'] as String? ?? '',

      title: data['title'] as String? ?? '',

      description: data['description'] as String? ?? '',

      challengeType: data['challengeType'] as String? ?? 'daily',

      grade: data['grade'] as String? ?? '',

      subject: data['subject'] as String? ?? '',

      unitNumber: data['unitNumber'] as int? ?? 0,
      unitName: data['unitName'] as String? ?? '',

      targetCount: (data['targetCount'] as num?)?.toInt() ?? 0,

      currentCount: (data['currentCount'] as num?)?.toInt() ?? 0,

      scheduledDate: _readDate(data['scheduledDate']) ?? DateTime.now(),

      isCompleted: data['isCompleted'] as bool? ?? false,

      rewardXp: (data['rewardXp'] as num?)?.toInt() ?? 0,

      createdAt: _readDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,

      'title': title,

      'description': description,

      'challengeType': challengeType,

      'grade': grade,

      'subject': subject,

      'unitNumber': unitNumber,

      'unitName': unitName,

      'targetCount': targetCount,

      'currentCount': currentCount,

      'scheduledDate': Timestamp.fromDate(scheduledDate),

      'isCompleted': isCompleted,

      'rewardXp': rewardXp,

      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  Challenge copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? challengeType,
    String? grade,
    String? subject,
    int? unitNumber,
    String? unitName,
    int? targetCount,
    int? currentCount,
    DateTime? scheduledDate,
    bool? isCompleted,
    int? rewardXp,
    DateTime? createdAt,
  }) {
    return Challenge(
      id: id ?? this.id,
      userId: userId ?? this.userId,

      title: title ?? this.title,

      description: description ?? this.description,

      challengeType: challengeType ?? this.challengeType,

      grade: grade ?? this.grade,

      subject: subject ?? this.subject,

      unitNumber: unitNumber ?? this.unitNumber,

      unitName: unitName ?? this.unitName,

      targetCount: targetCount ?? this.targetCount,

      currentCount: currentCount ?? this.currentCount,

      scheduledDate: scheduledDate ?? this.scheduledDate,

      isCompleted: isCompleted ?? this.isCompleted,

      rewardXp: rewardXp ?? this.rewardXp,

      createdAt: createdAt ?? this.createdAt,
    );
  }
}
