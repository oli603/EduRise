import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  // STUDENT: STREAM NOTIFICATIONS
  // ============================================================

  Stream<List<AppNotification>> streamMyNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _notificationsCollection
        .where('userId', whereIn: [user.uid, 'all'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
          .toList();
    });
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
    final snapshot = await _notificationsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
        .toList();
  }
}
