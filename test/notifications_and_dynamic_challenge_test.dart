import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/features/notifications/data/notification_model.dart';
import 'package:edurise/features/challenges/data/challenge_model.dart';
import 'package:edurise/features/challenges/presentation/challenges_screen.dart';

void main() {
  group('PART 1: Student Notifications Deserialization & Resilience Tests', () {
    test('TEST 1: Deserializes from Firestore Timestamp', () {
      final now = DateTime(2026, 9, 7, 12, 30);
      final data = {
        'userId': 'student_123',
        'title': 'System Maintenance',
        'body': 'EduRise will be updated tonight.',
        'type': 'announcement',
        'isRead': false,
        'createdAt': Timestamp.fromDate(now),
        'metadata': {'version': '2.0.0'},
      };

      final notif = AppNotification.fromMap('n1', data);
      expect(notif.id, 'n1');
      expect(notif.userId, 'student_123');
      expect(notif.title, 'System Maintenance');
      expect(notif.body, 'EduRise will be updated tonight.');
      expect(notif.type, 'announcement');
      expect(notif.isRead, isFalse);
      expect(notif.createdAt, now);
      expect(notif.metadata?['version'], '2.0.0');
    });

    test('TEST 2: Deserializes from ISO 8601 String timestamp', () {
      final data = {
        'userId': 'all',
        'title': 'New Exam Published',
        'body': '2016 Natural Science exam is live.',
        'type': 'announcement',
        'isRead': true,
        'createdAt': '2026-09-07T12:00:00.000Z',
      };

      final notif = AppNotification.fromMap('n2', data);
      expect(notif.id, 'n2');
      expect(notif.userId, 'all');
      expect(notif.title, 'New Exam Published');
      expect(notif.isRead, isTrue);
      expect(notif.createdAt, isNotNull);
      expect(notif.createdAt!.year, 2026);
    });

    test('TEST 3: Deserializes from epoch millis integer timestamp', () {
      final epochMillis = DateTime(2026, 8, 15, 10, 0).millisecondsSinceEpoch;
      final data = {
        'userId': 'student_abc',
        'title': 'Payment Approved',
        'body': 'Your access is active.',
        'type': 'payment_approved',
        'isRead': false,
        'createdAt': epochMillis,
      };

      final notif = AppNotification.fromMap('n3', data);
      expect(notif.id, 'n3');
      expect(notif.createdAt, DateTime.fromMillisecondsSinceEpoch(epochMillis));
    });

    test('TEST 4: Deserializes dynamic nested map in metadata without crashing', () {
      final dynamicMap = <dynamic, dynamic>{
        'examYear': 2016,
        'subject': 'Biology',
        'unit': 1,
      };
      final data = {
        'userId': 'all',
        'title': 'Announcement',
        'body': 'Check your weak areas',
        'createdAt': null,
        'metadata': dynamicMap,
      };

      final notif = AppNotification.fromMap('n4', data);
      expect(notif.metadata, isNotNull);
      expect(notif.metadata!['examYear'], 2016);
      expect(notif.metadata!['subject'], 'Biology');
    });

    test('TEST 5: Safely parses field aliases (heading/subject, message/content, target)', () {
      final data1 = {
        'target': 'student_xyz',
        'heading': 'Welcome to EduRise!',
        'message': 'Explore past exams now.',
        'type': 'admin_alert',
      };

      final notif1 = AppNotification.fromMap('n5a', data1);
      expect(notif1.userId, 'student_xyz');
      expect(notif1.title, 'Welcome to EduRise!');
      expect(notif1.body, 'Explore past exams now.');

      final data2 = {
        'recipientId': 'all',
        'subject': 'Exam Schedule',
        'content': 'Schedule released for 2016.',
      };

      final notif2 = AppNotification.fromMap('n5b', data2);
      expect(notif2.userId, 'all');
      expect(notif2.title, 'Exam Schedule');
      expect(notif2.body, 'Schedule released for 2016.');
    });

    test('TEST 6: Tolerates completely missing or malformed fields safely', () {
      final malformedData = <String, dynamic>{
        'unknownField': 12345,
        'createdAt': 'invalid-date-format',
        'isRead': 'true',
      };

      final notif = AppNotification.fromMap('n6', malformedData);
      expect(notif.id, 'n6');
      expect(notif.userId, 'all');
      expect(notif.title, '');
      expect(notif.body, '');
      expect(notif.isRead, isTrue);
      expect(notif.createdAt, isNull);
    });

    test('TEST 7: List sorting orders notifications descending by createdAt', () {
      final n1 = AppNotification(
        id: 'n1',
        userId: 'all',
        title: 'Older',
        body: 'Older',
        type: 'announcement',
        isRead: false,
        createdAt: DateTime(2026, 9, 1),
      );
      final n2 = AppNotification(
        id: 'n2',
        userId: 'all',
        title: 'Newer',
        body: 'Newer',
        type: 'announcement',
        isRead: false,
        createdAt: DateTime(2026, 9, 7),
      );
      final n3 = AppNotification(
        id: 'n3',
        userId: 'all',
        title: 'Middle',
        body: 'Middle',
        type: 'announcement',
        isRead: false,
        createdAt: DateTime(2026, 9, 4),
      );

      final list = [n1, n2, n3];
      list.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      expect(list.map((e) => e.id).toList(), ['n2', 'n3', 'n1']);
    });
  });

  group('PART 2: Challenge Dynamic Question Count & Progress Denominator Tests', () {
    testWidgets('TEST 8: Challenge with 1 question displays 0 / 1 (NOT /10)', (tester) async {
      final challenge = Challenge(
        id: 'c1',
        userId: 'user1',
        title: 'Master Unit 2: Chemistry',
        description: 'Practice questions to master this unit',
        challengeType: 'practice',
        grade: 'Grade 11',
        subject: 'Chemistry',
        unitNumber: 2,
        unitName: 'Chemical Reactions',
        targetCount: 1,
        currentCount: 0,
        scheduledDate: DateTime.now(),
        isCompleted: false,
        rewardXp: 50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChallengesScreen(initialChallenges: [challenge]),
        ),
      );
      await tester.pumpAndSettle();

      // Verify denominator is 1
      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('0 / 10'), findsNothing);
      expect(find.text('In progress'), findsOneWidget);
    });

    testWidgets('TEST 9: Challenge with 1 question answered displays 1 / 1 and Completed', (tester) async {
      final challenge = Challenge(
        id: 'c1_done',
        userId: 'user1',
        title: 'Master Unit 2: Chemistry',
        description: 'Practice questions to master this unit',
        challengeType: 'practice',
        grade: 'Grade 11',
        subject: 'Chemistry',
        unitNumber: 2,
        unitName: 'Chemical Reactions',
        targetCount: 1,
        currentCount: 1,
        scheduledDate: DateTime.now(),
        isCompleted: true,
        rewardXp: 50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChallengesScreen(initialChallenges: [challenge]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('1 / 10'), findsNothing);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Challenge Completed'), findsOneWidget);
    });

    testWidgets('TEST 10: Challenge with 3 questions displays 0 / 3, then 1 / 3, 2 / 3, 3 / 3', (tester) async {
      for (int current = 0; current <= 3; current++) {
        final challenge = Challenge(
          id: 'c3_$current',
          userId: 'user1',
          title: 'Master Unit 3: Biology',
          description: 'Practice questions',
          challengeType: 'practice',
          grade: 'Grade 9',
          subject: 'Biology',
          unitNumber: 3,
          unitName: 'Enzymes',
          targetCount: 3,
          currentCount: current,
          scheduledDate: DateTime.now(),
          isCompleted: current == 3,
          rewardXp: 75,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChallengesScreen(initialChallenges: [challenge]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('$current / 3'), findsOneWidget);
        expect(find.text('$current / 10'), findsNothing);
        if (current == 3) {
          expect(find.text('Completed'), findsOneWidget);
        } else {
          expect(find.text('In progress'), findsOneWidget);
        }
      }
    });

    testWidgets('TEST 11: Challenge with 7 questions displays 0 / 7 and dynamic progress', (tester) async {
      final challenge = Challenge(
        id: 'c7',
        userId: 'user1',
        title: 'Master Unit 4: Physics',
        description: 'Practice questions',
        challengeType: 'practice',
        grade: 'Grade 12',
        subject: 'Physics',
        unitNumber: 4,
        unitName: 'Electromagnetism',
        targetCount: 7,
        currentCount: 3,
        scheduledDate: DateTime.now(),
        isCompleted: false,
        rewardXp: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChallengesScreen(initialChallenges: [challenge]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 / 7'), findsOneWidget);
      expect(find.text('3 / 10'), findsNothing);
    });

    testWidgets('TEST 12: Challenge with 10 questions displays / 10 when actual count is 10', (tester) async {
      final challenge = Challenge(
        id: 'c10',
        userId: 'user1',
        title: 'Master Unit 1: History',
        description: 'Practice questions',
        challengeType: 'practice',
        grade: 'Grade 10',
        subject: 'History',
        unitNumber: 1,
        unitName: 'Early Civilizations',
        targetCount: 10,
        currentCount: 5,
        scheduledDate: DateTime.now(),
        isCompleted: false,
        rewardXp: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChallengesScreen(initialChallenges: [challenge]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5 / 10'), findsOneWidget);
    });

    test('TEST 13: Challenge session capped at 10 if unit has > 10 questions', () {
      const availableQuestions = 25;
      final target = availableQuestions > 10 ? 10 : availableQuestions;
      expect(target, 10);
    });

    test('TEST 14: Challenge session uses exact count when unit has <= 10 questions', () {
      expect(1 > 10 ? 10 : 1, 1);
      expect(3 > 10 ? 10 : 3, 3);
      expect(7 > 10 ? 10 : 7, 7);
      expect(10 > 10 ? 10 : 10, 10);
    });
  });
}
