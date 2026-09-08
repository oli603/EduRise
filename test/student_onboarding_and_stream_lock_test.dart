import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/core/localization/app_localizations.dart';
import 'package:edurise/features/profile_setup/presentation/profile_setup_screen.dart';
import 'package:edurise/features/profile/presentation/widgets/profile_settings_modals.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

void main() {
  group('PART 1: Remove Duplicate Full Name Tests', () {
    testWidgets('TEST 1: ProfileSetupScreen renders EXACTLY ONE "Full Name" label', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfileSetupScreen()),
      );
      await tester.pumpAndSettle();

      // Verify "Full Name" appears EXACTLY ONCE
      final fullNameFinders = find.text('Full Name');
      expect(fullNameFinders, findsOneWidget);

      // Verify there is only one text field for name
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Enter your full name'), findsOneWidget);
    });
  });

  group('PART 2 & 3: Selectable and Required Stream Dropdown Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(800, 1200);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('TEST 2: Stream dropdown exists with ONLY "Natural" and "Social" options', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfileSetupScreen()),
      );
      await tester.pumpAndSettle();

      // Find the Stream dropdown form field
      expect(find.text('Stream'), findsOneWidget);
      expect(find.text('Select Stream'), findsOneWidget);

      // Open the dropdown
      await tester.tap(find.text('Select Stream'));
      await tester.pumpAndSettle();

      // Verify Natural and Social options exist
      expect(find.widgetWithText(DropdownMenuItem<String>, 'Natural'), findsOneWidget);
      expect(find.widgetWithText(DropdownMenuItem<String>, 'Social'), findsOneWidget);

      // Confirm "General", "Other", "Unknown", "All Streams" are NOT present
      expect(find.text('General'), findsNothing);
      expect(find.text('Other'), findsNothing);
      expect(find.text('Unknown'), findsNothing);
      expect(find.text('All Streams'), findsNothing);
    });

    testWidgets('TEST 3: Form requires Stream selection before continuing', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfileSetupScreen()),
      );
      await tester.pumpAndSettle();

      // Enter valid name
      await tester.enterText(find.byType(TextFormField).first, 'Abebe Kebede');
      await tester.pumpAndSettle();

      // Select Grade 12
      await tester.tap(find.text('Grade 12'));
      await tester.pumpAndSettle();

      // Tap Continue without selecting Stream
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Validation message must be shown
      expect(find.text('Please select your stream.'), findsOneWidget);
    });

    testWidgets('TEST 4: Selecting Natural stream clears validation and updates value', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfileSetupScreen()),
      );
      await tester.pumpAndSettle();

      // Open dropdown and select Natural
      await tester.tap(find.text('Select Stream'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownMenuItem<String>, 'Natural').last);
      await tester.pumpAndSettle();

      // "Natural" is now selected in the dropdown
      expect(find.text('Natural'), findsOneWidget);
      expect(find.text('Please select your stream.'), findsNothing);
    });

    testWidgets('TEST 5: Selecting Social stream updates value to Social', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfileSetupScreen()),
      );
      await tester.pumpAndSettle();

      // Open dropdown and select Social
      await tester.tap(find.text('Select Stream'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownMenuItem<String>, 'Social').last);
      await tester.pumpAndSettle();

      expect(find.text('Social'), findsOneWidget);
    });
  });

  group('PART 4 & 5: Stream Lock in UI and Security Logic', () {
    testWidgets('TEST 6: Edit Profile dialog displays Stream as DISABLED / LOCKED', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ProfileSettingsModals.showEditProfileDialog(
                    context,
                    currentName: 'Abebe Kebede',
                    currentStream: 'natural',
                  );
                },
                child: const Text('Open Edit Profile'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Edit Profile'));
      await tester.pumpAndSettle();

      // Find the stream text field
      final streamField = tester.widget<TextFormField>(
        find.ancestor(
          of: find.text('Stream cannot be changed after selection.'),
          matching: find.byType(TextFormField),
        ),
      );

      // Verify the field is explicitly disabled
      expect(streamField.enabled, isFalse);

      // Verify the lock icon is rendered
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Verify there is NO editable dropdown in this dialog
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    test('TEST 7: Stream canonicalization produces strictly natural or social', () {
      String canonicalize(String stream) {
        return stream.toLowerCase().contains('social') ? 'social' : 'natural';
      }

      expect(canonicalize('natural'), 'natural');
      expect(canonicalize('Natural'), 'natural');
      expect(canonicalize('Natural Science'), 'natural');
      expect(canonicalize('social'), 'social');
      expect(canonicalize('Social'), 'social');
      expect(canonicalize('Social Science'), 'social');
    });

    test('TEST 8: Security Rule Logic for Student Stream Update', () {
      // Simulates the security rule evaluation:
      // (request.resource.data.stream == resource.data.stream) ||
      // (!('stream' in resource.data) && request.resource.data.stream in ['natural', 'social'])
      bool evaluateStreamUpdateRule({
        required Map<String, dynamic> existingData,
        required Map<String, dynamic> incomingData,
      }) {
        final existingStream = existingData['stream'];
        final incomingStream = incomingData['stream'];

        // If incoming data does not touch stream or keeps it unchanged:
        if (incomingStream == null || incomingStream == existingStream) {
          return true;
        }

        // If existing document had no stream and is setting for the first time:
        if ((existingStream == null || existingStream == '') &&
            (incomingStream == 'natural' || incomingStream == 'social')) {
          return true;
        }

        // Otherwise, trying to change an already set stream is rejected!
        return false;
      }

      // Case 1: Student updates name, leaves stream unchanged -> ALLOWED
      expect(
        evaluateStreamUpdateRule(
          existingData: {'name': 'Old Name', 'stream': 'natural'},
          incomingData: {'name': 'New Name', 'stream': 'natural'},
        ),
        isTrue,
      );

      // Case 2: Student tries to change natural -> social -> REJECTED
      expect(
        evaluateStreamUpdateRule(
          existingData: {'name': 'Abebe', 'stream': 'natural'},
          incomingData: {'name': 'Abebe', 'stream': 'social'},
        ),
        isFalse,
      );

      // Case 3: Student tries to change social -> natural -> REJECTED
      expect(
        evaluateStreamUpdateRule(
          existingData: {'name': 'Abebe', 'stream': 'social'},
          incomingData: {'name': 'Abebe', 'stream': 'natural'},
        ),
        isFalse,
      );

      // Case 4: Student tries to set unauthorized stream 'general' -> REJECTED
      expect(
        evaluateStreamUpdateRule(
          existingData: {'name': 'Abebe', 'stream': ''},
          incomingData: {'name': 'Abebe', 'stream': 'general'},
        ),
        isFalse,
      );

      // Case 5: New student establishing stream for the first time -> ALLOWED
      expect(
        evaluateStreamUpdateRule(
          existingData: {'name': 'Abebe', 'stream': ''},
          incomingData: {'name': 'Abebe', 'stream': 'natural'},
        ),
        isTrue,
      );
      expect(
        evaluateStreamUpdateRule(
          existingData: {'name': 'Abebe'},
          incomingData: {'name': 'Abebe', 'stream': 'social'},
        ),
        isTrue,
      );
    });
  });
}
