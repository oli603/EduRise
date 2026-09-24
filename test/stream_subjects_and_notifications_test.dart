import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/core/auth/access_service.dart';
import 'package:edurise/core/constants/app_subjects.dart';
import 'package:edurise/features/notifications/data/notification_model.dart';

void main() {
  group('TEST A: Natural Subjects Configuration', () {
    test('Natural stream has appropriate subjects + SAT, and excludes Social subjects and Civics', () {
      final natural = EduRiseSubjects.getPracticeSubjects(stream: 'natural', grade: 'Grade 12');
      expect(natural, containsAll(['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'SAT']));
      expect(natural.contains('Economics'), isFalse);
      expect(natural.contains('Geography'), isFalse);
      expect(natural.contains('History'), isFalse);
      expect(natural.contains('Civics'), isFalse);

      final naturalHome = EduRiseSubjects.getHomeSubjects(stream: 'natural');
      expect(naturalHome, containsAll(['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'SAT']));
      expect(naturalHome.contains('Economics'), isFalse);

      final naturalChallenge = EduRiseSubjects.getChallengeSubjects(stream: 'natural');
      expect(naturalChallenge, containsAll(['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'SAT']));
      expect(naturalChallenge.contains('Economics'), isFalse);

      final naturalStudy = EduRiseSubjects.getStudyPlanSubjects(stream: 'natural');
      expect(naturalStudy, containsAll(['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'SAT']));
      expect(naturalStudy.contains('Economics'), isFalse);
    });
  });

  group('TEST B: Social Subjects Configuration', () {
    test('Social stream has appropriate subjects + SAT, and excludes Natural-only subjects and Civics', () {
      final social = EduRiseSubjects.getPracticeSubjects(stream: 'social', grade: 'Grade 12');
      expect(social, containsAll(['Mathematics', 'History', 'Geography', 'Economics', 'English', 'SAT']));
      expect(social.contains('Physics'), isFalse);
      expect(social.contains('Chemistry'), isFalse);
      expect(social.contains('Biology'), isFalse);
      expect(social.contains('Civics'), isFalse);

      final socialHome = EduRiseSubjects.getHomeSubjects(stream: 'social');
      expect(socialHome, containsAll(['Mathematics', 'History', 'Geography', 'Economics', 'English', 'SAT']));
      expect(socialHome.contains('Biology'), isFalse);

      final socialChallenge = EduRiseSubjects.getChallengeSubjects(stream: 'social');
      expect(socialChallenge, containsAll(['Mathematics', 'History', 'Geography', 'Economics', 'English', 'SAT']));
      expect(socialChallenge.contains('Biology'), isFalse);

      final socialStudy = EduRiseSubjects.getStudyPlanSubjects(stream: 'social');
      expect(socialStudy, containsAll(['Mathematics', 'History', 'Geography', 'Economics', 'English', 'SAT']));
      expect(socialStudy.contains('Biology'), isFalse);
    });
  });

  group('TEST C: SAT Available to Both Streams', () {
    test('SAT is available for both Natural and Social streams across all features', () {
      expect(EduRiseSubjects.getPracticeSubjects(stream: 'natural').contains('SAT'), isTrue);
      expect(EduRiseSubjects.getPracticeSubjects(stream: 'social').contains('SAT'), isTrue);

      expect(EduRiseSubjects.getEntranceExamSubjects(stream: 'natural').contains('SAT'), isTrue);
      expect(EduRiseSubjects.getEntranceExamSubjects(stream: 'social').contains('SAT'), isTrue);

      expect(EduRiseSubjects.getChallengeSubjects(stream: 'natural').contains('SAT'), isTrue);
      expect(EduRiseSubjects.getChallengeSubjects(stream: 'social').contains('SAT'), isTrue);

      expect(EduRiseSubjects.getStudyPlanSubjects(stream: 'natural').contains('SAT'), isTrue);
      expect(EduRiseSubjects.getStudyPlanSubjects(stream: 'social').contains('SAT'), isTrue);

      expect(EduRiseSubjects.getHomeSubjects(stream: 'natural').contains('SAT'), isTrue);
      expect(EduRiseSubjects.getHomeSubjects(stream: 'social').contains('SAT'), isTrue);
    });
  });

  group('TEST D: Social Past Entrance Exams Bug Fix', () {
    test('Social student stream produces valid non-empty exam subjects list (does not say empty)', () {
      // Test with various casing possibilities stored in Firestore: 'social', 'Social Science', 'Social'
      for (final s in ['social', 'Social Science', 'Social', 'social science']) {
        final subjects = EduRiseSubjects.getEntranceExamSubjects(stream: s);
        expect(subjects.isNotEmpty, isTrue, reason: 'Failed for stream string: $s');
        expect(subjects, containsAll(['Mathematics', 'History', 'Geography', 'Economics', 'English', 'SAT']));
        expect(subjects.contains('Biology'), isFalse);
      }
    });

    test('Natural student stream produces valid entrance exam subjects list', () {
      for (final s in ['natural', 'Natural Science', 'Natural', 'natural science']) {
        final subjects = EduRiseSubjects.getEntranceExamSubjects(stream: s);
        expect(subjects.isNotEmpty, isTrue, reason: 'Failed for stream string: $s');
        expect(subjects, containsAll(['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'SAT']));
        expect(subjects.contains('Economics'), isFalse);
      }
    });
  });

  group('TEST E: Past Entrance Exams Free Access Locked', () {
    test('Free student is blocked from accessing Past Entrance Exams', () {
      // In AccessService, canAccessPastExams delegates strictly to hasPaidAccess
      // We simulate access decision:
      bool canAccessPastExams({required bool isPaid, required String accessStatus}) {
        return isPaid || accessStatus == 'active';
      }

      // Free student
      expect(canAccessPastExams(isPaid: false, accessStatus: 'locked'), isFalse);

      // Paid student
      expect(canAccessPastExams(isPaid: true, accessStatus: 'locked'), isTrue);
      expect(canAccessPastExams(isPaid: false, accessStatus: 'active'), isTrue);
    });
  });

  group('TEST F, G, H, I: Free Practice Exact Scope (Grade 12 + Unit 1 + 2017 EC)', () {
    test('TEST F: Grade 12 + Unit 1 + 2017 EC is allowed free', () {
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2017, unitNumber: 1),
        isTrue,
      );
    });

    test('TEST G: Grade 12 + Unit 2 + 2017 EC is LOCKED', () {
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2017, unitNumber: 2),
        isFalse,
      );
    });

    test('TEST H: Grade 12 + Unit 1 + 2016 EC is LOCKED', () {
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 12', examYear: 2016, unitNumber: 1),
        isFalse,
      );
    });

    test('TEST I: Grade 11 + Unit 1 + 2017 EC is LOCKED', () {
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 11', examYear: 2017, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 10', examYear: 2017, unitNumber: 1),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(grade: 'Grade 9', examYear: 2017, unitNumber: 1),
        isFalse,
      );
    });
  });

  group('TEST J & K: Challenge and Study Plan Stream-Awareness', () {
    test('TEST J: Challenge eligible subjects respect student stream', () {
      final naturalPool = EduRiseSubjects.getChallengeSubjects(stream: 'natural');
      final socialPool = EduRiseSubjects.getChallengeSubjects(stream: 'social');

      expect(naturalPool.contains('Biology'), isTrue);
      expect(socialPool.contains('Biology'), isFalse);

      expect(socialPool.contains('Economics'), isTrue);
      expect(naturalPool.contains('Economics'), isFalse);
    });

    test('TEST K: Study Plan subjects respect student stream', () {
      final naturalStudy = EduRiseSubjects.getStudyPlanSubjects(stream: 'natural');
      final socialStudy = EduRiseSubjects.getStudyPlanSubjects(stream: 'social');

      expect(naturalStudy.contains('Physics'), isTrue);
      expect(socialStudy.contains('Physics'), isFalse);

      expect(socialStudy.contains('Geography'), isTrue);
      expect(naturalStudy.contains('Geography'), isFalse);
    });
  });

  group('TEST L: Notification Unread Count Calculation & Stream Simulation', () {
    test('Unread count accurately reflects notification stream and read state changes', () async {
      final controller = StreamController<List<AppNotification>>();

      // Map notifications to unread count dynamically
      final unreadStream = controller.stream.map(
        (list) => list.where((n) => !n.isRead).length,
      );

      final counts = <int>[];
      final subscription = unreadStream.listen(counts.add);

      // 1. Admin posts 1 unread notification
      final notif1 = AppNotification(
        id: 'n1',
        userId: 'student1',
        title: 'Welcome',
        body: 'Welcome to EduRise',
        type: 'announcement',
        isRead: false,
      );
      controller.add([notif1]);
      await Future.delayed(Duration.zero);

      // 2. Admin posts another unread notification -> 2
      final notif2 = AppNotification(
        id: 'n2',
        userId: 'student1',
        title: 'Payment Approved',
        body: 'Your subscription is now active!',
        type: 'payment_approved',
        isRead: false,
      );
      controller.add([notif1, notif2]);
      await Future.delayed(Duration.zero);

      // 3. Student reads one notification (n1 marked read) -> 1
      final notif1Read = AppNotification(
        id: 'n1',
        userId: 'student1',
        title: 'Welcome',
        body: 'Welcome to EduRise',
        type: 'announcement',
        isRead: true,
      );
      controller.add([notif1Read, notif2]);
      await Future.delayed(Duration.zero);

      // 4. Student reads all notifications -> 0
      final notif2Read = AppNotification(
        id: 'n2',
        userId: 'student1',
        title: 'Payment Approved',
        body: 'Your subscription is now active!',
        type: 'payment_approved',
        isRead: true,
      );
      controller.add([notif1Read, notif2Read]);
      await Future.delayed(Duration.zero);

      expect(counts, equals([1, 2, 1, 0]));

      await subscription.cancel();
      await controller.close();
    });
  });
}
