import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  // ============================================================
  // SEND TARGETED NOTIFICATION
  // ============================================================

  Future<String> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'announcement',
    Map<String, dynamic>? metadata,
  }) async {
    final docRef = _notificationsCollection.doc();

    final notification = AppNotification(
      id: docRef.id,
      userId: userId,
      title: title.trim(),
      body: body.trim(),
      type: type,
      isRead: false,
      createdAt: null,
      metadata: metadata,
    );

    await docRef.set(notification.toMap());
    return docRef.id;
  }

  // ============================================================
  // BROADCAST ANNOUNCEMENT
  // ============================================================

  Future<String> broadcastAnnouncement({
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    return sendNotification(
      userId: 'all',
      title: title,
      body: body,
      type: 'announcement',
      metadata: metadata,
    );
  }

  // ============================================================
  // STUDENT: STREAM NOTIFICATIONS (RESILIENT WITH INDEX FALLBACK)
  // ============================================================

  Stream<List<AppNotification>> streamMyNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('NOTIFICATION DEBUG: streamMyNotifications called with null currentUser');
      return Stream.value([]);
    }

    final userId = user.uid;
    debugPrint('NOTIFICATION DEBUG: Starting notification stream for student UID: $userId');

    late final StreamController<List<AppNotification>> controller;
    StreamSubscription? primarySub;
    StreamSubscription? fallbackSub;

    controller = StreamController<List<AppNotification>>(
      onListen: () {
        // Attempt ordered query (uses composite index userId ASC, createdAt DESC if deployed)
        final orderedQuery = _notificationsCollection
            .where('userId', whereIn: [userId, 'all'])
            .orderBy('createdAt', descending: true)
            .limit(50);

        primarySub = orderedQuery.snapshots().listen(
          (snapshot) {
            final list = _parseSnapshot(
              snapshot,
              queryDescription: 'Primary (Ordered)',
              userId: userId,
            );
            if (!controller.isClosed) {
              controller.add(list);
            }
          },
          onError: (error) {
            debugPrint('NOTIFICATION STREAM PRIMARY ERROR: $error');
            // If primary fails due to missing composite index or precondition error,
            // fall back to single-field index query + in-memory sort to ensure students always see notifications.
            if (fallbackSub == null && !controller.isClosed) {
              debugPrint('NOTIFICATION: Falling back to single-field query with in-memory descending sort');
              final fallbackQuery = _notificationsCollection
                  .where('userId', whereIn: [userId, 'all'])
                  .limit(50);

              fallbackSub = fallbackQuery.snapshots().listen(
                (fallbackSnapshot) {
                  final list = _parseSnapshot(
                    fallbackSnapshot,
                    queryDescription: 'Fallback (Single-field index)',
                    userId: userId,
                  );
                  if (!controller.isClosed) {
                    controller.add(list);
                  }
                },
                onError: (fallbackError) {
                  debugPrint('NOTIFICATION STREAM FALLBACK ERROR: $fallbackError');
                  if (!controller.isClosed) {
                    controller.addError(fallbackError);
                  }
                },
              );
            }
          },
        );
      },
      onCancel: () {
        primarySub?.cancel();
        fallbackSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Safely parses snapshot documents into AppNotifications, ignoring single corrupted docs.
  List<AppNotification> _parseSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required String queryDescription,
    required String userId,
  }) {
    debugPrint(
      'NOTIFICATION DEBUG: $queryDescription | user: $userId | returned docs: ${snapshot.docs.length}',
    );

    final notifications = <AppNotification>[];
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final item = AppNotification.fromMap(doc.id, data);
        notifications.add(item);
      } catch (err, stack) {
        debugPrint('NOTIFICATION PARSE ERROR for doc ${doc.id}: $err\n$stack');
        // Do not crash the entire list if one document has an anomaly
      }
    }

    // Ensure sorted by createdAt descending
    notifications.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return notifications;
  }

  // ============================================================
  // STUDENT: MARK AS READ
  // ============================================================

  Future<void> markAsRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({'isRead': true});
  }

  // ============================================================
  // ADMIN: GET RECENT NOTIFICATIONS / ANNOUNCEMENTS
  // ============================================================

  Future<List<AppNotification>> getAdminRecentNotifications({int limit = 50}) async {
    try {
      final snapshot = await _notificationsCollection
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return _parseSnapshot(
        snapshot,
        queryDescription: 'Admin Recent Notifications',
        userId: _auth.currentUser?.uid ?? 'admin',
      );
    } catch (e) {
      debugPrint('Admin recent notifications ordered query failed: $e. Falling back to unordered.');
      final snapshot = await _notificationsCollection
          .limit(limit)
          .get();

      return _parseSnapshot(
        snapshot,
        queryDescription: 'Admin Recent Notifications (Fallback)',
        userId: _auth.currentUser?.uid ?? 'admin',
      );
    }
  }
}
