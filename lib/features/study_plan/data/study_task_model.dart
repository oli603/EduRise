import 'package:cloud_firestore/cloud_firestore.dart';

class StudyTask {
  final String id;
  final String userId;
  final String title;

  final String grade;
  final String subject;

  final int? unitNumber;
  final String? unitName;

  final String taskType;
  final int? targetCount;

  final DateTime scheduledDate;
  final bool isCompleted;
  final DateTime? createdAt;

  const StudyTask({
    required this.id,
    required this.userId,
    required this.title,
    required this.grade,
    required this.subject,
    this.unitNumber,
    this.unitName,
    required this.taskType,
    this.targetCount,
    required this.scheduledDate,
    required this.isCompleted,
    this.createdAt,
  });

  factory StudyTask.fromMap(String id, Map<String, dynamic> data) {
    return StudyTask(
      id: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      grade: data['grade'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      unitNumber: data['unitNumber'] as int?,
      unitName: data['unitName'] as String?,
      taskType: data['taskType'] as String? ?? 'practice',
      targetCount: data['targetCount'] as int?,
      scheduledDate: _readDate(data['scheduledDate']) ?? DateTime.now(),
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: _readDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'grade': grade,
      'subject': subject,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'taskType': taskType,
      'targetCount': targetCount,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'isCompleted': isCompleted,
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

    return null;
  }

  StudyTask copyWith({
    String? id,
    String? userId,
    String? title,
    String? grade,
    String? subject,
    int? unitNumber,
    String? unitName,
    String? taskType,
    int? targetCount,
    DateTime? scheduledDate,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return StudyTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      unitNumber: unitNumber ?? this.unitNumber,
      unitName: unitName ?? this.unitName,
      taskType: taskType ?? this.taskType,
      targetCount: targetCount ?? this.targetCount,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
