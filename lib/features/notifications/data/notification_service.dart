import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/routes/app_router.dart';
import 'notification_model.dart';

/// Top-level background handler for FCM messages when app is closed or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Track notifications already shown in foreground to prevent duplicate popups
  final Set<String> _shownNotificationIds = {};
  bool _isInitialSnapshot = true;

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  // ============================================================
  // INITIALIZATION: FCM & LOCAL NOTIFICATIONS
  // ============================================================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Timezone database for scheduled local notifications
      tz.initializeTimeZones();
      try {
        final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
        debugPrint('NotificationService: Local timezone set to $currentTimeZone');
      } catch (tzError) {
        debugPrint('NotificationService: Error setting local timezone: $tzError');
      }

      // 2. Initialize Flutter Local Notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationPayload(payload);
          }
        },
      );

      // 3. Create Android notification channels
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // High-importance channel for Admin Announcements & Alerts
        const announcementChannel = AndroidNotificationChannel(
          'edurise_announcements',
          'EduRise Announcements',
          description: 'Official announcements, alerts, and platform notices',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );

        // High-importance channel for Study Plan Reminders
        const studyPlanChannel = AndroidNotificationChannel(
          'edurise_study_plan',
          'EduRise Study Plan',
          description: 'Scheduled study reminders and task alerts',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );

        await androidPlugin.createNotificationChannel(announcementChannel);
        await androidPlugin.createNotificationChannel(studyPlanChannel);

        // Request notification permission on Android 13+
        await androidPlugin.requestNotificationsPermission();

        // Request exact alarms permission on Android 12+ (API 31+)
        await androidPlugin.requestExactAlarmsPermission();
      }

      // 4. Request FCM permission in background (non-blocking)
      _messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      ).catchError((_) => null as dynamic);

      // 5. Handle foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      // 6. Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleRemoteMessageTap(message);
      });

      // 7. Handle notification tap on cold-start (app terminated) asynchronously
      _messaging.getInitialMessage().then((initialMessage) {
        if (initialMessage != null) {
          _handleRemoteMessageTap(initialMessage);
        }
      }).catchError((_) {});

      // 8. Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        syncUserToken(token: newToken);
      });

      // 9. Sync token for currently authenticated user in background (non-blocking)
      unawaited(syncUserToken());

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
    }
  }

  // ============================================================
  // FOREGROUND NOTIFICATION DISPLAY
  // ============================================================

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'EduRise Announcement';
    final body = notification?.body ?? message.data['body'] ?? '';

    const androidDetails = AndroidNotificationDetails(
      'edurise_announcements',
      'EduRise Announcements',
      channelDescription: 'Official announcements, alerts, and platform notices',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    final id = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: '/notifications',
    );
  }

  // ============================================================
  // NOTIFICATION TAP ROUTING
  // ============================================================

  void _handleNotificationPayload(String payload) {
    debugPrint('NOTIFICATION TAP PAYLOAD: $payload');
    if (payload == '/study-plan') {
      AppRouter.router.push('/study-plan');
    } else if (payload.startsWith('/notifications')) {
      AppRouter.router.push('/notifications');
    }
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    debugPrint('REMOTE MESSAGE TAP: ${message.data}');
    final route = message.data['route'] as String? ?? '/notifications';
    AppRouter.router.push(route);
  }

  // ============================================================
  // TOKEN MANAGEMENT (MULTI-DEVICE & LOGOUT SUPPORT)
  // ============================================================

  Future<void> syncUserToken({String? token}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final currentToken = token ??
          await _messaging.getToken().timeout(const Duration(seconds: 3)).catchError((_) => null);
      if (currentToken == null || currentToken.isEmpty) return;

      // Store in user document (using arrayUnion to support multiple devices without overwriting)
      await _firestore.collection('students').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([currentToken]),
        'lastTokenSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));

      // Subscribe student to announcements topic
      await _messaging
          .subscribeToTopic('announcements')
          .timeout(const Duration(seconds: 3))
          .catchError((_) {});
      debugPrint('FCM Token synchronized for student ${user.uid}');
    } catch (e) {
      debugPrint('Failed to sync FCM token: $e');
    }
  }

  Future<void> clearUserToken() async {
    try {
      final user = _auth.currentUser;
      final currentToken = await _messaging
          .getToken()
          .timeout(const Duration(seconds: 2))
          .catchError((_) => null);

      if (user != null && currentToken != null) {
        await _firestore.collection('students').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayRemove([currentToken]),
        }).timeout(const Duration(seconds: 2)).catchError((_) {});
      }

      await _messaging
          .unsubscribeFromTopic('announcements')
          .timeout(const Duration(seconds: 2))
          .catchError((_) {});
      debugPrint('FCM Token cleared for student');
    } catch (e) {
      debugPrint('Error clearing FCM token on logout: $e');
    }
  }

  /// Resets in-memory notification tracking state on logout / account switch.
  void resetSessionState() {
    _shownNotificationIds.clear();
    _isInitialSnapshot = true;
    debugPrint('NotificationService: Reset in-memory session notification state.');
  }

  // ============================================================
  // STUDY PLAN: SCHEDULED LOCAL REMINDERS
  // ============================================================

  Future<void> scheduleStudyTaskReminder({
    required String taskId,
    required String subject,
    required String title,
    required DateTime scheduledDate,
    bool isCompleted = false,
  }) async {
    final notificationId = taskId.hashCode & 0x7FFFFFFF;

    // If completed or date in past, cancel reminder
    if (isCompleted || scheduledDate.isBefore(DateTime.now())) {
      await cancelStudyTaskReminder(taskId);
      return;
    }

    try {
      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'edurise_study_plan',
        'EduRise Study Plan',
        channelDescription: 'Scheduled study reminders and task alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications.zonedSchedule(
        notificationId,
        'Study Plan Reminder: $subject',
        title.isNotEmpty ? title : 'Time for your scheduled study session!',
        tzScheduled,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '/study-plan',
      );

      debugPrint('Scheduled Study Plan reminder for task $taskId at $tzScheduled');
    } catch (e) {
      debugPrint('Error scheduling Study Plan reminder: $e');
    }
  }

  Future<void> cancelStudyTaskReminder(String taskId) async {
    try {
      final notificationId = taskId.hashCode & 0x7FFFFFFF;
      await _localNotifications.cancel(notificationId);
      debugPrint('Cancelled Study Plan reminder for task $taskId (ID: $notificationId)');
    } catch (e) {
      debugPrint('Error cancelling Study Plan reminder: $e');
    }
  }

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

  /// Sends an idempotent admin alert notification using a deterministic document ID.
  /// Guarantees that retries, network flakiness, or UI rebuilds NEVER produce duplicate alerts.
  Future<String> sendAdminNotificationOnce({
    required String idempotencyKey,
    required String title,
    required String body,
    String type = 'admin_alert',
    Map<String, dynamic>? metadata,
  }) async {
    final cleanKey = idempotencyKey.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final docId = 'alert_$cleanKey';
    final docRef = _notificationsCollection.doc(docId);

    try {
      final existing = await docRef.get();
      if (existing.exists) {
        debugPrint('NotificationService: Alert $docId already exists (idempotency skipped)');
        return docId;
      }
    } catch (_) {
      // If read fails (e.g. non-admin student lacks read permission), proceed safely
    }

    final notification = AppNotification(
      id: docId,
      userId: 'admin_alerts',
      title: title.trim(),
      body: body.trim(),
      type: type,
      isRead: false,
      createdAt: null,
      metadata: metadata,
    );

    try {
      await docRef.set(notification.toMap(), SetOptions(merge: true));
      debugPrint('NotificationService: Created idempotent alert $docId');
    } catch (e) {
      debugPrint('NotificationService: sendAdminNotificationOnce write skipped or unauthorized: $e');
    }
    return docId;
  }

  /// Sends an admin alert notification created by an authenticated student.
  /// Uses an authorized CREATE-ONLY path with a unique document ID so that
  /// the student never attempts an unauthorized read or update on admin-owned notifications.
  Future<String?> sendStudentAdminAlert({
    required String title,
    required String body,
    String type = 'admin_alert',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef = _notificationsCollection.doc();
      final notification = AppNotification(
        id: docRef.id,
        userId: 'admin_alerts',
        title: title.trim(),
        body: body.trim(),
        type: type,
        isRead: false,
        createdAt: null,
        metadata: metadata,
      );

      await docRef.set(notification.toMap());
      debugPrint('NotificationService: Created student admin alert ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('NotificationService: Student admin alert creation failed (non-fatal): $e');
      return null;
    }
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
  // DELETE INDIVIDUAL ANNOUNCEMENT
  // ============================================================

  Future<void> deleteNotification(String notificationId) async {
    await _notificationsCollection.doc(notificationId).delete();
  }

  // ============================================================
  // DELETE ALL ANNOUNCEMENTS / ALERTS
  // ============================================================

  Future<int> deleteAllAnnouncements() async {
    final snapshot = await _notificationsCollection.get();
    if (snapshot.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snapshot.docs.length;
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

  // ============================================================
  // STUDENT: STREAM UNREAD COUNT (REAL-TIME BADGE)
  // ============================================================

  Stream<int> streamUnreadCount() {
    return streamMyNotifications().map(
      (notifications) => notifications.where((n) => !n.isRead).length,
    );
  }

  List<AppNotification> _parseSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required String queryDescription,
    required String userId,
  }) {
    final notifications = <AppNotification>[];
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final item = AppNotification.fromMap(doc.id, data);
        notifications.add(item);
      } catch (err, stack) {
        debugPrint('NOTIFICATION PARSE ERROR for doc ${doc.id}: $err\n$stack');
      }
    }

    if (_isInitialSnapshot) {
      _shownNotificationIds.addAll(notifications.map((n) => n.id));
      _isInitialSnapshot = false;
    } else {
      for (final item in notifications) {
        if (!_shownNotificationIds.contains(item.id)) {
          _shownNotificationIds.add(item.id);
          _showForegroundNotificationFromItem(item);
        }
      }
    }

    notifications.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return notifications;
  }

  Future<void> _showForegroundNotificationFromItem(AppNotification item) async {
    const androidDetails = AndroidNotificationDetails(
      'edurise_announcements',
      'EduRise Announcements',
      channelDescription: 'Official announcements, alerts, and platform notices',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    final id = item.id.hashCode & 0x7FFFFFFF;
    await _localNotifications.show(
      id,
      item.title,
      item.body,
      notificationDetails,
      payload: '/notifications',
    );
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
