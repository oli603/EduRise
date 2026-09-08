import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId; // Specific student UID or 'all'
  final String title;
  final String body;
  final String type; // 'payment_approved', 'payment_rejected', 'announcement', 'admin_alert'
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
    this.metadata,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    final rawUserId = data['userId'] ?? data['target'] ?? data['recipientId'];
    final rawTitle = data['title'] ?? data['heading'] ?? data['subject'];
    final rawBody = data['body'] ?? data['message'] ?? data['content'] ?? data['description'];
    final rawType = data['type'];
    final rawIsRead = data['isRead'];

    return AppNotification(
      id: id,
      userId: rawUserId?.toString() ?? 'all',
      title: rawTitle?.toString() ?? '',
      body: rawBody?.toString() ?? '',
      type: rawType?.toString() ?? 'announcement',
      isRead: rawIsRead is bool ? rawIsRead : (rawIsRead?.toString().toLowerCase() == 'true'),
      createdAt: _parseDateTime(data['createdAt']),
      metadata: _parseMetadata(data['metadata']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  static Map<String, dynamic>? _parseMetadata(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      try {
        return value.map((k, v) => MapEntry(k.toString(), v));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'metadata': metadata,
    };
  }
}
