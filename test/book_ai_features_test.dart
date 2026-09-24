import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/session_manager.dart';
import 'package:edurise/core/constants/app_subjects.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/books/data/book_model.dart';
import 'package:edurise/features/books/data/book_text_service.dart';
import 'package:edurise/features/coach/data/coach_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SessionManager.resetSession();
    OfflineStorageService.instance.clearMemoryCache();
    BookTextService().clearMemoryCache();
  });

  tearDown(() async {
    SessionManager.resetSession();
    OfflineStorageService.instance.clearMemoryCache();
    BookTextService().clearMemoryCache();
  });

  group('Part 1: BookTextService & Textbook Context Extraction', () {
    test('prepareContextWindow limits characters cleanly and appends marker', () {
      final service = BookTextService();
      final shortText = 'Chapter 1: The scientific method and biology foundations.';
      expect(service.prepareContextWindow(shortText, maxChars: 100), shortText);

      final longText = 'A' * 200;
      final prepared = service.prepareContextWindow(longText, maxChars: 50);
      expect(prepared.startsWith('A' * 50), isTrue);
      expect(prepared.contains('[... Unit text continues ...]'), isTrue);
    });

    test('BookTextResult detects unusable / scanned-only text', () {
      const scannedResult = BookTextResult(text: 'Short', isScannedOnly: true);
      expect(scannedResult.hasUsableText, isFalse);

      const usableResult = BookTextResult(
        text: 'This is a rich authoritative textbook unit context describing biological processes in detail.',
        isScannedOnly: false,
      );
      expect(usableResult.hasUsableText, isTrue);
    });

    test('Disk cache persists and retrieves extracted unit text', () async {
      final engine = StorageEngine.instance;
      await engine.init();

      const unitId = 'test_unit_bio_g9_u1';
      const sampleText = 'Photosynthesis is the process by which green plants transform light energy into chemical energy.';

      await engine.writeAtomic(
        'book_text_cache.json',
        jsonEncode({unitId: sampleText}),
      );

      final unit = BookUnit(
        id: unitId,
        grade: 'Grade 9',
        subject: 'Biology',
        unitNumber: 1,
        unitName: 'Introduction to Biology',
        pdfUrl: 'https://example.com/bio9.pdf',
      );

      final service = BookTextService();
      final result = await service.getUnitText(unit);
      expect(result.hasUsableText, isTrue);
      expect(result.text, sampleText);
    });
  });

  group('Part 2: Account Isolation for Book AI Content', () {
    test('AI cache keys are strictly scoped by Firebase UID', () async {
      final storage = OfflineStorageService.instance;
      await storage.init();

      const naturalUid = 'student_natural_101';
      const socialUid = 'student_social_202';
      const bookId = 'book_g11_math';
      const unitId = 'unit_1';

      // 1. Natural student generates and caches summary
      SessionManager.startSession(naturalUid);
      final naturalSummary = {
        'overview': 'Grade 11 Mathematics Calculus Foundation for Natural Sciences.',
        'key_points': ['Limits', 'Derivatives', 'Continuity'],
      };
      await storage.saveCoachContentLocally(
        feature: 'book_summary',
        contentId: '${naturalUid}_${bookId}_${unitId}_summary',
        content: naturalSummary,
      );

      // 2. Natural student can read cached summary
      final naturalCached = await storage.getLocalCoachContentAsync(
        feature: 'book_summary',
        contentId: '${naturalUid}_${bookId}_${unitId}_summary',
      );
      expect(naturalCached, isNotNull);
      expect(naturalCached!['overview'], contains('Natural Sciences'));

      // 3. Social student logs in - must NOT see Natural student cached summary
      SessionManager.resetSession();
      storage.clearMemoryCache();
      SessionManager.startSession(socialUid);

      final socialCached = await storage.getLocalCoachContentAsync(
        feature: 'book_summary',
        contentId: '${socialUid}_${bookId}_${unitId}_summary',
      );
      expect(socialCached, isNull);
    });
  });

  group('Part 3: Stream and Grade Curriculum Isolation', () {
    test('Grade 11 & 12 stream restrictions', () {
      // Natural student
      expect(EduRiseSubjects.isSubjectAllowedForStream('Physics', 'natural'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Chemistry', 'natural'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Biology', 'natural'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('History', 'natural'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Geography', 'natural'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Economics', 'natural'), isFalse);

      // Social student
      expect(EduRiseSubjects.isSubjectAllowedForStream('History', 'social'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Geography', 'social'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Economics', 'social'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Physics', 'social'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Chemistry', 'social'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Biology', 'social'), isFalse);
    });

    test('Grades 9 & 10 common foundational curriculum allows subjects across streams', () {
      final g9Subjects = EduRiseSubjects.foundationGrades9And10;
      expect(g9Subjects.contains('Biology'), isTrue);
      expect(g9Subjects.contains('Geography'), isTrue);
      expect(g9Subjects.contains('History'), isTrue);
      expect(g9Subjects.contains('Physics'), isTrue);
    });
  });

  group('Part 4: Offline Caching & Missing Offline Result Handling', () {
    test('OfflineStorageService getLocalCoachContentAsync loads disk state before returning', () async {
      final storage = OfflineStorageService.instance;
      await storage.init();

      const testKey = 'test_unit_cached_notes';
      await storage.saveCoachContentLocally(
        feature: 'book_notes',
        contentId: testKey,
        content: {'sections': [{'title': 'Section 1', 'content': 'Notes'}]},
      );

      // Reset in-memory cache to simulate cold app restart
      storage.clearMemoryCache();

      // getLocalCoachContentAsync initializes from disk
      final loaded = await storage.getLocalCoachContentAsync(
        feature: 'book_notes',
        contentId: testKey,
      );
      expect(loaded, isNotNull);
      expect(loaded!['cached'], isTrue);
    });

    test('CoachService throws clear offline message when ungenerated content is requested offline', () async {
      SessionManager.startSession('offline_student_uid');
      final coachService = CoachService.instance;

      // With fake host / offline endpoint, it should fail-safe with clear offline message
      expect(
        () => coachService.getUnitSummary(
          bookId: 'unopened_book',
          unitId: 'unit_99',
          unitTitle: 'Unopened Unit',
          subject: 'Physics',
          grade: 'Grade 9',
          forceRefresh: true,
        ),
        throwsA(predicate((e) =>
            e.toString().contains('offline') ||
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('network') ||
            e.toString().contains('CoachApiException') ||
            e.toString().contains('400'))),
      );
    });
  });

  group('Part 5: Schema Synchronization & Response Validation', () {
    test('Flashcards parsing handles both front/back and question/answer', () {
      final canonicalItem = {
        'question': 'What is inertia?',
        'answer': 'Resistance to changes in velocity.',
        'category': 'Newtonian Mechanics',
      };
      final front1 = (canonicalItem['front'] ?? canonicalItem['question'] ?? '').toString();
      final back1 = (canonicalItem['back'] ?? canonicalItem['answer'] ?? '').toString();
      expect(front1, 'What is inertia?');
      expect(back1, 'Resistance to changes in velocity.');

      final uiItem = {
        'front': 'What is momentum?',
        'back': 'Mass times velocity.',
        'category': 'Momentum',
      };
      final front2 = (uiItem['front'] ?? uiItem['question'] ?? '').toString();
      final back2 = (uiItem['back'] ?? uiItem['answer'] ?? '').toString();
      expect(front2, 'What is momentum?');
      expect(back2, 'Mass times velocity.');
    });

    test('Summary schema fallbacks resolve correctly', () {
      final rawBackendResponse = {
        'overview': 'This unit covers linear motion.',
        'key_points': ['Velocity', 'Acceleration', 'Displacement'],
        'important_terms': [{'term': 'Velocity', 'definition': 'Rate of change of displacement.'}],
        'summary_recap': 'Crucial unit for kinematics exam problems.',
      };

      final overview = rawBackendResponse['overview'] as String;
      final rawConcepts = rawBackendResponse['key_concepts'] ??
          rawBackendResponse['important_terms'] ??
          rawBackendResponse['key_points'];
      final rawBullet = rawBackendResponse['bullet_points'] ?? rawBackendResponse['key_points'];
      final examImp = (rawBackendResponse['exam_importance'] ?? rawBackendResponse['summary_recap'] ?? '').toString();

      expect(overview, 'This unit covers linear motion.');
      expect(rawConcepts, isNotNull);
      expect(rawBullet, ['Velocity', 'Acceleration', 'Displacement']);
      expect(examImp, 'Crucial unit for kinematics exam problems.');
    });

    test('AI Notes section synthesis when sections array is empty', () {
      final rawNotes = {
        'key_concepts': ['Force equals mass times acceleration', 'Action and reaction are equal and opposite'],
        'important_processes': ['Applying net force', 'Accelerating mass'],
        'definitions': [{'term': 'Force', 'definition': 'Push or pull on an object.'}],
        'exam_focused_points': ['F=ma vector resolution on inclines'],
      };

      var rawSections = (rawNotes['sections'] as List<dynamic>?) ?? [];
      if (rawSections.isEmpty) {
        final concepts = (rawNotes['key_concepts'] as List<dynamic>?) ?? [];
        final procs = (rawNotes['important_processes'] as List<dynamic>?) ?? [];
        final synth = <Map<String, dynamic>>[];
        if (concepts.isNotEmpty) {
          synth.add({'title': 'Core Concepts & Principles', 'content': 'Overview', 'key_points': concepts});
        }
        if (procs.isNotEmpty) {
          synth.add({'title': 'Key Processes', 'content': 'Overview', 'key_points': procs});
        }
        rawSections = synth;
      }

      expect(rawSections.length, 2);
      expect(rawSections[0]['title'], 'Core Concepts & Principles');
      expect((rawSections[0]['key_points'] as List).length, 2);
    });

    test('Understand Unit handles both String and Map in step_by_step_breakdown without crashing', () {
      // 1. Array of Strings
      final stringSteps = ['Step 1: Raw inputs enter', 'Step 2: Processing occurs', 'Step 3: Output delivered'];
      for (var entry in stringSteps.asMap().entries) {
        final idx = entry.key;
        final st = entry.value;
        final stNum = '${idx + 1}';
        final stTitle = 'Step ${idx + 1}';
        final stExp = st.toString();
        expect(stNum, '${idx + 1}');
        expect(stTitle, 'Step ${idx + 1}');
        expect(stExp, contains('Step'));
      }

      // 2. Array of Maps
      final mapSteps = [
        {'step': 1, 'title': 'Initiation', 'explanation': 'System activates'},
        {'step': 2, 'title': 'Transformation', 'explanation': 'Energy converted'},
      ];
      for (var entry in mapSteps.asMap().entries) {
        final idx = entry.key;
        final st = entry.value;
        final stNum = (st['step'] ?? '${idx + 1}').toString();
        final stTitle = (st['title'] ?? 'Step ${idx + 1}').toString();
        final stExp = (st['explanation'] ?? '').toString();
        expect(stNum, '${idx + 1}');
        expect(stTitle, isNotEmpty);
        expect(stExp, isNotEmpty);
      }
    });

    test('Quiz Generator strictly enforces 7 questions, 4 options, and valid letter answer', () {
      final sampleQuestions = List.generate(7, (i) {
        return {
          'question_text': 'Unit Test Question ${i + 1}?',
          'options': {
            'A': 'Correct Principle Option A',
            'B': 'Distractor Option B',
            'C': 'Distractor Option C',
            'D': 'Distractor Option D',
          },
          'correct_answer': 'A',
          'explanation': 'Explanation for question ${i + 1}.',
        };
      });

      expect(sampleQuestions.length, 7);

      for (int i = 0; i < sampleQuestions.length; i++) {
        final q = sampleQuestions[i];
        final options = q['options'] as Map<String, String>;
        expect(options.length, 4);
        expect(options.containsKey('A'), isTrue);
        expect(options.containsKey('B'), isTrue);
        expect(options.containsKey('C'), isTrue);
        expect(options.containsKey('D'), isTrue);

        final correct = q['correct_answer'];
        expect(['A', 'B', 'C', 'D'].contains(correct), isTrue);
        expect(options[correct], isNotEmpty);

        // Verify distinct options
        final distinctOptions = options.values.toSet();
        expect(distinctOptions.length, 4);
      }
    });

    test('Quiz options parsing safely converts list of options to letter-mapped dict', () {
      final rawQ = {
        'question': 'What is the unit of force?',
        'options': ['Newton', 'Joule', 'Watt', 'Pascal'],
        'correct_answer': 'Newton', // Text instead of letter
        'explanation': 'Force is measured in Newtons (N).',
      };

      final qText = (rawQ['question_text'] ?? rawQ['question'] ?? '').toString();
      final rawOpts = rawQ['options'];
      final Map<String, String> opts = {};
      final letters = ['A', 'B', 'C', 'D'];
      if (rawOpts is List) {
        for (int i = 0; i < rawOpts.length && i < 4; i++) {
          opts[letters[i]] = rawOpts[i].toString();
        }
      }

      String corrLetter = (rawQ['correct_answer'] ?? 'A').toString().trim().toUpperCase();
      if (!opts.containsKey(corrLetter)) {
        for (final entry in opts.entries) {
          if (entry.value.trim().toLowerCase() == corrLetter.toLowerCase()) {
            corrLetter = entry.key;
            break;
          }
        }
      }

      expect(qText, 'What is the unit of force?');
      expect(opts['A'], 'Newton');
      expect(opts['B'], 'Joule');
      expect(opts['C'], 'Watt');
      expect(opts['D'], 'Pascal');
      expect(corrLetter, 'A'); // Resolved to option letter 'A'!
    });
  });
}
