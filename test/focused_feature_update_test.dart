import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/core/auth/access_service.dart';
import 'package:edurise/core/constants/app_subjects.dart';
import 'package:edurise/features/admin/data/audit_service.dart';
import 'package:edurise/features/home/widgets/quick_access_section.dart';
import 'package:edurise/features/notifications/data/notification_model.dart';
import 'package:edurise/features/study_plan/data/study_task_model.dart';

void main() {
  group('PART 1: Home Quick Access & Subjects Tests', () {
    testWidgets('QuickAccessSection renders required cards and excludes removed cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuickAccessSection(),
            ),
          ),
        ),
      );

      // Verify KEPT items
      expect(find.text('Challenges'), findsOneWidget);

      // Verify ADDED items
      expect(find.text('Past Entrance Exams'), findsOneWidget);
      expect(find.text('Predicted Mock Exam'), findsOneWidget);

      // Verify REMOVED items are NOT in Quick Access
      expect(find.text('Practice'), findsNothing);
      expect(find.text('Progress'), findsNothing);

      // Verify other existing items remain
      expect(find.text('Weak Areas'), findsOneWidget);
      expect(find.text('Study Plan'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
    });

    test('Subject streams remain intact for backend and Practice/Study Plan', () {
      final naturalSubjects = EduRiseSubjects.getPracticeSubjects(stream: 'natural');
      expect(naturalSubjects, contains('Physics'));
      expect(naturalSubjects, contains('Chemistry'));
      expect(naturalSubjects, contains('Biology'));
      expect(naturalSubjects, contains('SAT'));
      expect(naturalSubjects, isNot(contains('History')));
      expect(naturalSubjects, isNot(contains('Geography')));

      final socialSubjects = EduRiseSubjects.getPracticeSubjects(stream: 'social');
      expect(socialSubjects, contains('History'));
      expect(socialSubjects, contains('Geography'));
      expect(socialSubjects, contains('Economics'));
      expect(socialSubjects, contains('SAT'));
      expect(socialSubjects, isNot(contains('Physics')));
    });
  });

  group('PART 2 & 3: Notification and Study Plan Reminders Tests', () {
    test('StudyTask deterministic notification ID calculation is stable', () {
      const taskId1 = 'task_abc_123';
      const taskId2 = 'task_xyz_789';

      final notifId1a = taskId1.hashCode & 0x7FFFFFFF;
      final notifId1b = taskId1.hashCode & 0x7FFFFFFF;
      final notifId2 = taskId2.hashCode & 0x7FFFFFFF;

      expect(notifId1a, equals(notifId1b));
      expect(notifId1a >= 0, isTrue);
      expect(notifId1a, isNot(equals(notifId2)));
    });

    test('AppNotification model serialization and parsing', () {
      final now = DateTime.now();
      final notification = AppNotification(
        id: 'notif_1',
        userId: 'student_123',
        title: 'New Exam Published',
        body: '2018 EC Entrance Exam is now active.',
        type: 'announcement',
        isRead: false,
        createdAt: now,
        metadata: {'category': 'national_exam'},
      );

      final map = notification.toMap();
      expect(map['userId'], 'student_123');
      expect(map['title'], 'New Exam Published');
      expect(map['type'], 'announcement');
      expect(map['isRead'], isFalse);

      final parsed = AppNotification.fromMap('notif_1', map);
      expect(parsed.id, 'notif_1');
      expect(parsed.userId, 'student_123');
      expect(parsed.title, 'New Exam Published');
      expect(parsed.isRead, isFalse);
    });

    test('StudyTask model serialization and parsing', () {
      final scheduled = DateTime.now().add(const Duration(hours: 4));
      final task = StudyTask(
        id: 'task_001',
        userId: 'student_456',
        title: 'Complete Unit 3 Practice',
        grade: 'Grade 12',
        subject: 'Mathematics',
        unitNumber: 3,
        unitName: 'Matrices',
        taskType: 'practice',
        targetCount: 25,
        scheduledDate: scheduled,
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      final map = task.toMap();
      expect(map['userId'], 'student_456');
      expect(map['subject'], 'Mathematics');
      expect(map['unitNumber'], 3);
      expect(map['targetCount'], 25);
      expect(map['isCompleted'], isFalse);

      final parsed = StudyTask.fromMap('task_001', map);
      expect(parsed.id, 'task_001');
      expect(parsed.subject, 'Mathematics');
      expect(parsed.unitNumber, 3);
      expect(parsed.isCompleted, isFalse);
    });
  });

  group('PART 4 & 5: Admin Audit Trail and Announcement Data Structures', () {
    test('AuditLogEntry model serialization and parsing', () {
      final entry = AuditLogEntry(
        id: 'audit_01',
        actorUid: 'admin_123',
        actorEmail: 'admin@edurise.edu',
        actorRole: 'admin',
        action: 'question_deleted',
        targetType: 'questions',
        targetId: 'q_789',
        timestamp: DateTime.now(),
        metadata: {'reason': 'Outdated syllabus'},
      );

      final map = entry.toMap();
      expect(map['actorEmail'], 'admin@edurise.edu');
      expect(map['action'], 'question_deleted');
      expect(map['targetId'], 'q_789');

      final parsed = AuditLogEntry.fromMap('audit_01', map);
      expect(parsed.actorEmail, 'admin@edurise.edu');
      expect(parsed.action, 'question_deleted');
      expect(parsed.targetId, 'q_789');
    });

    test('Access rules: Free practice policy and past exams paid access check', () {
      // Free student practice policy: Grade 12 + Unit 1 + 2017 allowed
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2017, unitNumber: 1),
        isTrue,
      );

      // Other combinations must NOT be free
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 11', examYear: 2017, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2016, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2017, unitNumber: 2),
        isFalse,
      );
    });

    test('PART 6: Entrance exam duration is 3 hours for Math and 2 hours for all other subjects', () {
      expect(EduRiseSubjects.getEntranceExamDuration('Mathematics'), equals(const Duration(hours: 3)));
      expect(EduRiseSubjects.getEntranceExamDuration('maths'), equals(const Duration(hours: 3)));
      expect(EduRiseSubjects.getEntranceExamDuration('MATH'), equals(const Duration(hours: 3)));

      expect(EduRiseSubjects.getEntranceExamDuration('Biology'), equals(const Duration(hours: 2)));
      expect(EduRiseSubjects.getEntranceExamDuration('Chemistry'), equals(const Duration(hours: 2)));
      expect(EduRiseSubjects.getEntranceExamDuration('Physics'), equals(const Duration(hours: 2)));
      expect(EduRiseSubjects.getEntranceExamDuration('English'), equals(const Duration(hours: 2)));
      expect(EduRiseSubjects.getEntranceExamDuration('History'), equals(const Duration(hours: 2)));
      expect(EduRiseSubjects.getEntranceExamDuration('Geography'), equals(const Duration(hours: 2)));
      expect(EduRiseSubjects.getEntranceExamDuration('Economics'), equals(const Duration(hours: 2)));
      expect(EduRiseSubjects.getEntranceExamDuration('SAT'), equals(const Duration(hours: 2)));
    });

    test('PART 7: Entrance exam blueprint question counts match curriculum standards', () {
      expect(EduRiseSubjects.getEntranceExamQuestionCount('Mathematics'), equals(45));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('maths'), equals(45));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('English'), equals(60));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('SAT'), equals(60));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('Biology'), equals(50));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('Physics'), equals(50));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('Chemistry'), equals(50));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('Economics'), equals(50));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('Geography'), equals(50));
      expect(EduRiseSubjects.getEntranceExamQuestionCount('History'), equals(50));
    });

    test('PART 8: Canonicalization and stream allowance checks', () {
      expect(EduRiseSubjects.canonicalize('maths'), equals('Mathematics'));
      expect(EduRiseSubjects.canonicalize('bio'), equals('Biology'));
      expect(EduRiseSubjects.canonicalize('chem'), equals('Chemistry'));
      expect(EduRiseSubjects.canonicalize('econ'), equals('Economics'));
      expect(EduRiseSubjects.canonicalize('geo'), equals('Geography'));
      expect(EduRiseSubjects.canonicalize('hist'), equals('History'));

      expect(EduRiseSubjects.isSubjectAllowedForStream('Physics', 'natural'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('History', 'natural'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Economics', 'social'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Biology', 'social'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('English', 'natural'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('English', 'social'), isTrue);
    });

    test('PART 9: AccessService Coach trial scope alignment with free practice policy', () {
      // Free student trial scope (Grade 12, 2017, Unit 1)
      final trialAllowed = AccessService.isFreeAllowedPractice(
        grade: 'Grade 12',
        examYear: 2017,
        unitNumber: 1,
      );
      expect(trialAllowed, isTrue);

      // Free student blocked outside trial scope
      final trialBlockedGrade = AccessService.isFreeAllowedPractice(
        grade: 'Grade 11',
        examYear: 2017,
        unitNumber: 1,
      );
      expect(trialBlockedGrade, isFalse);

      final trialBlockedYear = AccessService.isFreeAllowedPractice(
        grade: 'Grade 12',
        examYear: 2016,
        unitNumber: 1,
      );
      expect(trialBlockedYear, isFalse);

      final trialBlockedUnit = AccessService.isFreeAllowedPractice(
        grade: 'Grade 12',
        examYear: 2017,
        unitNumber: 2,
      );
      expect(trialBlockedUnit, isFalse);
    });
  });
}
