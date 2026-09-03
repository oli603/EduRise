import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/localization/app_localizations.dart';
import 'package:edurise/core/widgets/edurise_text_field.dart';
import 'package:edurise/features/profile/presentation/widgets/profile_settings_modals.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestAppWithLocale({
  required Locale locale,
  required Widget child,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BUG 1 Verification: MaterialLocalizations for all 3 languages', () {
    testWidgets('TextField finds MaterialLocalizations in English', (tester) async {
      await tester.pumpWidget(
        buildTestAppWithLocale(
          locale: const Locale('en'),
          child: const TextField(
            decoration: InputDecoration(labelText: 'Email Address'),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TextField finds MaterialLocalizations in Amharic (am)', (tester) async {
      await tester.pumpWidget(
        buildTestAppWithLocale(
          locale: const Locale('am'),
          child: const TextField(
            decoration: InputDecoration(labelText: 'ኢሜይል'),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TextField finds MaterialLocalizations in Afaan Oromoo (om)', (tester) async {
      await tester.pumpWidget(
        buildTestAppWithLocale(
          locale: const Locale('om'),
          child: const TextField(
            decoration: InputDecoration(labelText: 'Imeelii'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EduRiseTextField finds MaterialLocalizations across all 3 languages', (tester) async {
      for (final loc in [const Locale('en'), const Locale('am'), const Locale('om')]) {
        await tester.pumpWidget(
          buildTestAppWithLocale(
            locale: loc,
            child: Scaffold(
              body: EduRiseTextField(
                label: 'Test Input',
                hint: 'Enter text',
                controller: TextEditingController(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('BUG 2 Verification: Notifications Sheet layout without overflow', () {
    testWidgets('showNotificationSettingsSheet opens on small screen without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 592);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestAppWithLocale(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ProfileSettingsModals.showNotificationSettingsSheet(context),
                child: const Text('Open Notifications'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsNWidgets(3));
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('Payment & Verification Alerts'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('showNotificationSettingsSheet in Amharic with longer strings does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 592);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestAppWithLocale(
          locale: const Locale('am'),
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ProfileSettingsModals.showNotificationSettingsSheet(context),
                child: const Text('Open Notifications'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsNWidgets(3));
      expect(find.text('የግፊት ማሳወቂያዎች'), findsOneWidget);
      expect(find.text('አጠቃላይ ማስታወቂያዎች'), findsOneWidget);
      expect(find.text('የክፍያና ማረጋገጫ ማሳወቂያዎች'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
