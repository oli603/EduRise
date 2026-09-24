import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_service.dart';

class AuditLogEntry {
  final String id;
  final String actorUid;
  final String actorEmail;
  final String actorRole;
  final String action;
  final String targetType;
  final String targetId;
  final DateTime? timestamp;
  final Map<String, dynamic>? metadata;

  const AuditLogEntry({
    required this.id,
    required this.actorUid,
    required this.actorEmail,
    required this.actorRole,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.timestamp,
    this.metadata,
  });

  factory AuditLogEntry.fromMap(String id, Map<String, dynamic> data) {
    return AuditLogEntry(
      id: id,
      actorUid: data['actorUid'] as String? ?? '',
      actorEmail: data['actorEmail'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? 'admin',
      action: data['action'] as String? ?? '',
      targetType: data['targetType'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorUid': actorUid,
      'actorEmail': actorEmail,
      'actorRole': actorRole,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
      'metadata': metadata,
    };
  }
}

class AuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _logsCollection =>
      _firestore.collection('audit_logs');

  static Future<void> logAction({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      final role = await AdminService.getCurrentRole();

      await _logsCollection.add({
        'actorUid': user?.uid ?? 'system',
        'actorEmail': user?.email ?? 'system',
        'actorRole': role.value,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (_) {
      // Non-blocking fallback for audit logging errors
    }
  }

  static Future<List<AuditLogEntry>> getAuditLogs({
    int limit = 50,
    String? actionFilter,
  }) async {
    Query<Map<String, dynamic>> query = _logsCollection.orderBy('timestamp', descending: true);

    if (actionFilter != null && actionFilter.isNotEmpty && actionFilter != 'all') {
      query = query.where('action', isEqualTo: actionFilter);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => AuditLogEntry.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Delete a single audit log entry.
  static Future<void> deleteAuditLog(String logId) async {
    await _logsCollection.doc(logId).delete();
  }

  /// Delete multiple selected audit logs by their IDs.
  static Future<int> deleteSelectedAuditLogs(List<String> logIds) async {
    if (logIds.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final id in logIds) {
      batch.delete(_logsCollection.doc(id));
    }
    await batch.commit();
    return logIds.length;
  }

  /// Delete all audit log entries.
  static Future<int> deleteAllAuditLogs() async {
    final snapshot = await _logsCollection.get();
    if (snapshot.docs.isEmpty) return 0;

    // Batch delete in chunks of 500 (Firestore batch limit)
    const chunkSize = 450;
    for (var i = 0; i < snapshot.docs.length; i += chunkSize) {
      final end = (i + chunkSize < snapshot.docs.length) ? i + chunkSize : snapshot.docs.length;
      final chunk = snapshot.docs.sublist(i, end);
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    return snapshot.docs.length;
  }
}
