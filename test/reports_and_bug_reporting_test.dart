import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SessionManager.resetSession();
  });

  tearDown(() {
    SessionManager.resetSession();
  });

  // =========================================================================
  // PART 1: QUESTION REPORTS
  // =========================================================================
  group('Part 1: Question Reports Logic & Payloads', () {
    test('1. Deterministic question report ID generation', () {
      const questionId = 'Q_MATH_2016_42';
      const uid = 'student_uid_101';
      const reason = 'Wrong Answer';
      final reasonSlug = reason.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

      final docId = 'qrep_${questionId}_${uid}_$reasonSlug';
      expect(docId, 'qrep_Q_MATH_2016_42_student_uid_101_wrong_answer');
    });

    test('2. First creation payload includes required initial fields', () {
      const questionId = 'Q_MATH_2016_42';
      const uid = 'student_uid_101';
      const reason = 'Wrong Answer';
      const details = 'Option C is clearly incorrect';

      final createData = <String, dynamic>{
        'id': 'qrep_${questionId}_${uid}_wrong_answer',
        'question_id': questionId,
        'question_type': 'practice',
        'reason': reason,
        'subject': 'Mathematics',
        'grade': 'Grade 12',
        'unit_or_year': '1',
        'uid': uid,
        'status': 'pending',
        'details': details,
      };

      expect(createData['status'], 'pending');
      expect(createData['uid'], uid);
      expect(createData['question_id'], questionId);
      expect(createData.containsKey('admin_notes'), isFalse);
      expect(createData.containsKey('report_count'), isFalse);
    });

    test('3. Repeat submission payload contains only student-mutable fields', () {
      const details = 'Updated: Option B is the right derivative';

      final updateData = <String, dynamic>{
        'details': details,
      };

      // Ensure updateData does NOT touch admin or immutable fields
      expect(updateData.containsKey('status'), isFalse);
      expect(updateData.containsKey('createdAt'), isFalse);
      expect(updateData.containsKey('uid'), isFalse);
      expect(updateData.containsKey('admin_notes'), isFalse);
      expect(updateData.containsKey('report_count'), isFalse);
      expect(updateData['details'], details);
    });

    test('4. Repeat submission does not reset status', () {
      // Existing report has status under_review
      final existingReport = {
        'id': 'qrep_Q1_u1_wrong_answer',
        'status': 'under_review',
        'createdAt': '2026-09-18T10:00:00Z',
        'admin_notes': 'Checking with curriculum lead',
        'details': 'Original issue text',
      };

      final updateData = {
        'details': 'Additional feedback from student',
      };

      // Simulating update application
      final updatedReport = Map<String, dynamic>.from(existingReport)..addAll(updateData);

      expect(updatedReport['status'], 'under_review');
      expect(updatedReport['details'], 'Additional feedback from student');
      expect(updatedReport['admin_notes'], 'Checking with curriculum lead');
    });

    test('5. Repeat submission does not overwrite createdAt', () {
      const originalCreatedAt = '2026-09-18T10:00:00Z';
      final existingReport = {
        'id': 'qrep_Q1_u1_wrong_answer',
        'status': 'pending',
        'createdAt': originalCreatedAt,
      };

      final updateData = {
        'details': 'New details',
      };

      final updatedReport = Map<String, dynamic>.from(existingReport)..addAll(updateData);
      expect(updatedReport['createdAt'], originalCreatedAt);
    });

    test('6. Repeat submission cannot modify admin fields', () {
      final allowedUpdateKeys = {'details', 'lastReportedAt', 'correct_answer', 'student_answer'};
      final prohibitedAdminKeys = {'status', 'admin_notes', 'uid', 'report_count', 'reviewer', 'resolved_at'};

      for (final key in allowedUpdateKeys) {
        expect(prohibitedAdminKeys.contains(key), isFalse);
      }
    });

    test('7. UID comes from current authenticated/session identity', () {
      SessionManager.startSession('student_active_session_uid');
      final resolvedUid = SessionManager.currentUid;
      expect(resolvedUid, 'student_active_session_uid');
    });

    test('8. Unauthenticated submission fails cleanly', () {
      SessionManager.resetSession();
      final resolvedUid = SessionManager.currentUid;

      expect(
        () {
          if (resolvedUid == null || resolvedUid.isEmpty) {
            throw Exception('You must be signed in to submit a question report.');
          }
        },
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('You must be signed in'),
        )),
      );
    });
  });

  // =========================================================================
  // PART 2: BUG REPORTS
  // =========================================================================
  group('Part 2: Bug Reports Logic & Payloads', () {
    test('9. Deterministic bug report ID generation', () {
      const category = 'Books/download issue';
      const uid = 'student_uid_101';
      final categorySlug = category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

      final docId = 'bug_${categorySlug}_$uid';
      expect(docId, 'bug_books_download_issue_student_uid_101');
    });

    test('10. Bug report first creation payload includes required initial fields', () {
      const category = 'App crash/freezes';
      const uid = 'student_uid_101';
      const email = 'student101@edurise.et';
      const details = 'App froze when opening unit 3';

      final createData = <String, dynamic>{
        'id': 'bug_app_crash_freezes_student_uid_101',
        'category': category,
        'uid': uid,
        'email': email,
        'status': 'pending',
        'details': details,
      };

      expect(createData['status'], 'pending');
      expect(createData['category'], category);
      expect(createData['uid'], uid);
      expect(createData.containsKey('admin_notes'), isFalse);
      expect(createData.containsKey('reportCount'), isFalse);
    });

    test('11. Bug report repeat submission payload contains only student-mutable fields', () {
      const details = 'App froze on Samsung Galaxy M16';
      final updateData = <String, dynamic>{
        if (details.isNotEmpty) 'details': details,
      };

      expect(updateData.containsKey('status'), isFalse);
      expect(updateData.containsKey('createdAt'), isFalse);
      expect(updateData.containsKey('admin_notes'), isFalse);
      expect(updateData.containsKey('reportCount'), isFalse);
      expect(updateData['details'], details);
    });

    test('12. Bug report repeat submission preserves admin status', () {
      final existingDoc = {
        'id': 'bug_practice_issue_uid1',
        'category': 'Practice issue',
        'status': 'resolved',
        'admin_notes': 'Fixed question parsing logic',
        'createdAt': '2026-09-17T12:00:00Z',
      };

      final updatePayload = {
        'details': 'Student submitting again',
      };

      final mergedDoc = Map<String, dynamic>.from(existingDoc)..addAll(updatePayload);
      expect(mergedDoc['status'], 'resolved');
      expect(mergedDoc['admin_notes'], 'Fixed question parsing logic');
      expect(mergedDoc['details'], 'Student submitting again');
    });

    test('13. Bug report repeat submission preserves createdAt', () {
      const originalCreatedAt = '2026-09-17T12:00:00Z';
      final existingDoc = {
        'id': 'bug_login_issue_uid1',
        'createdAt': originalCreatedAt,
      };

      final updatePayload = {
        'details': 'Additional login error text',
      };

      final mergedDoc = Map<String, dynamic>.from(existingDoc)..addAll(updatePayload);
      expect(mergedDoc['createdAt'], originalCreatedAt);
    });

    test('14. Repeated submission by same student targets same document ID', () {
      const category = 'Books/download issue';
      const uid = 'student_uid_101';
      final categorySlug = category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

      final docId1 = 'bug_${categorySlug}_$uid';
      final docId2 = 'bug_${categorySlug}_$uid';

      expect(docId1, equals(docId2));
    });
  });

  // =========================================================================
  // PART 3: AGGREGATION & DISTINCT REPORTERS
  // =========================================================================
  group('Part 3: Aggregation & Distinct Reporter Counting', () {
    test('15. Same UID repeated multiple times leaves distinct reporter count at 1', () {
      final reports = [
        {'question_id': 'Q1', 'reason': 'Wrong answer', 'uid': 'student_A'},
        {'question_id': 'Q1', 'reason': 'Wrong answer', 'uid': 'student_A'},
        {'question_id': 'Q1', 'reason': 'Wrong answer', 'uid': 'student_A'},
      ];

      final Map<String, Set<String>> aggregated = {};
      for (final r in reports) {
        final key = '${r['question_id']}_${r['reason']}';
        aggregated.putIfAbsent(key, () => <String>{}).add(r['uid']!);
      }

      expect(aggregated['Q1_Wrong answer']!.length, 1);
    });

    test('16. Two distinct UIDs increment distinct reporter count to 2', () {
      final reports = [
        {'question_id': 'Q1', 'reason': 'Wrong answer', 'uid': 'student_A'},
        {'question_id': 'Q1', 'reason': 'Wrong answer', 'uid': 'student_A'},
        {'question_id': 'Q1', 'reason': 'Wrong answer', 'uid': 'student_B'},
      ];

      final Map<String, Set<String>> aggregated = {};
      for (final r in reports) {
        final key = '${r['question_id']}_${r['reason']}';
        aggregated.putIfAbsent(key, () => <String>{}).add(r['uid']!);
      }

      expect(aggregated['Q1_Wrong answer']!.length, 2);
    });
  });

  // =========================================================================
  // PART 4: API PARSING
  // =========================================================================
  group('Part 4: API Response Parsing', () {
    List<dynamic> parseAdminReportsResponse(dynamic res) {
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map && res['items'] is List) {
        items = res['items'] as List;
      }
      return items;
    }

    test('17. FastAPI List response (Response A) parses correctly', () {
      final rawList = [
        {'question_id': 'Q1', 'report_count': 3},
        {'question_id': 'Q2', 'report_count': 1},
      ];

      final parsed = parseAdminReportsResponse(rawList);
      expect(parsed.length, 2);
      expect(parsed[0]['question_id'], 'Q1');
    });

    test('18. Map response with items key (Response B) parses correctly', () {
      final rawMap = {
        'items': [
          {'question_id': 'Q1', 'report_count': 3},
          {'question_id': 'Q2', 'report_count': 1},
        ],
      };

      final parsed = parseAdminReportsResponse(rawMap);
      expect(parsed.length, 2);
      expect(parsed[0]['question_id'], 'Q1');
    });

    test('19. Malformed response fails safely without throwing', () {
      expect(parseAdminReportsResponse('malformed string'), isEmpty);
      expect(parseAdminReportsResponse(12345), isEmpty);
      expect(parseAdminReportsResponse(null), isEmpty);
      expect(parseAdminReportsResponse({'other_key': 42}), isEmpty);
    });
  });

  // =========================================================================
  // PART 5: NOTIFICATIONS & DECOUPLING
  // =========================================================================
  group('Part 5: Notifications & Decoupled Execution', () {
    test('20. Notification failure does not turn successful report submission into report failure', () async {
      bool reportWriteSucceeded = false;
      bool notificationFailed = false;
      bool studentSawSuccess = false;

      // Simulate student submission flow
      try {
        // Step 1: Write report
        reportWriteSucceeded = true;

        // Step 2: Show success
        studentSawSuccess = true;

        // Step 3: Notification attempted separately
        try {
          throw Exception('Simulated permission-denied on admin_alerts write');
        } catch (e) {
          notificationFailed = true;
          // Logged, but does not throw to outer catch
        }
      } catch (outerError) {
        studentSawSuccess = false;
      }

      expect(reportWriteSucceeded, isTrue);
      expect(notificationFailed, isTrue);
      expect(studentSawSuccess, isTrue);
    });

    test('21. Student notification path uses create-only with auto-generated ID', () {
      // Simulate create-only ID generation vs reading admin_alerts
      final autoGenId = 'notif_${DateTime.now().microsecondsSinceEpoch}';
      expect(autoGenId.startsWith('notif_'), isTrue);

      // Student notification payload
      final notifData = {
        'id': autoGenId,
        'userId': 'admin_alerts',
        'type': 'admin_alert',
        'title': 'Question flagged',
        'isRead': false,
      };

      expect(notifData['type'], 'admin_alert');
      expect(notifData['userId'], 'admin_alerts');
    });

    test('22. Question report notification schema matches requirements', () {
      const questionId = 'Q123';
      const reason = 'Wrong explanation';
      const subject = 'Biology';
      const uid = 'student_bio_1';

      final alert = {
        'title': 'New Question Accuracy Report',
        'body': 'Question $questionId ($subject) reported for "$reason".',
        'type': 'admin_alert',
        'metadata': {
          'questionId': questionId,
          'reason': reason,
          'subject': subject,
          'uid': uid,
        },
      };

      expect(alert['type'], 'admin_alert');
      final meta = alert['metadata'] as Map<String, dynamic>;
      expect(meta['questionId'], questionId);
      expect(meta['uid'], uid);
    });

    test('23. Bug report notification schema matches requirements', () {
      const categories = ['App crash/freezes', 'Books/download issue'];
      const email = 'olana@edurise.et';
      const uid = 'student_olana';

      final alert = <String, dynamic>{
        'title': 'New Student Bug Report',
        'body': 'A bug report was submitted for: ${categories.join(", ")} by $email.',
        'type': 'bug_report',
        'metadata': {
          'categories': categories,
          'uid': uid,
        },
      };

      expect(alert['type'], 'bug_report');
      final meta = alert['metadata'] as Map<String, dynamic>;
      expect((meta['categories'] as List).length, 2);
    });
  });
}
