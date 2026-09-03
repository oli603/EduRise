import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/localization/app_localizations.dart';
import 'package:edurise/core/settings/app_settings_controller.dart';
import 'package:edurise/features/about/presentation/about_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Localization & Language Unit Tests', () {
    test('AppLanguage.fromCode parses correctly with safe fallback', () {
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode('EN'), AppLanguage.english);
      expect(AppLanguage.fromCode('am'), AppLanguage.amharic);
      expect(AppLanguage.fromCode('AM'), AppLanguage.amharic);
      expect(AppLanguage.fromCode('om'), AppLanguage.afaanOromoo);
      expect(AppLanguage.fromCode('OM'), AppLanguage.afaanOromoo);
      expect(AppLanguage.fromCode(null), AppLanguage.english);
      expect(AppLanguage.fromCode('fr'), AppLanguage.english);
    });

    test('AppLocalizations translates strings in all three supported languages', () {
      const enLoc = AppLocalizations(Locale('en'));
      const amLoc = AppLocalizations(Locale('am'));
      const omLoc = AppLocalizations(Locale('om'));

      // English
      expect(enLoc.profile, 'Profile');
      expect(enLoc.settings, 'Settings');
      expect(enLoc.personalInfo, 'Personal Information');
      expect(enLoc.subscriptionPayment, 'Subscription & Payment');
      expect(enLoc.grade, 'Grade');
      expect(enLoc.subjects, 'Subjects');
      expect(enLoc.statusActive, 'Active (Paid Access)');

      // Amharic (አማርኛ)
      expect(amLoc.profile, 'መገለጫ');
      expect(amLoc.settings, 'ቅንብሮች');
      expect(amLoc.personalInfo, 'የግል መረጃ');
      expect(amLoc.subscriptionPayment, 'የአባልነት ክፍያ');
      expect(amLoc.grade, 'ክፍል');
      expect(amLoc.subjects, 'የትምህርት አይነቶች');
      expect(amLoc.statusActive, 'ንቁ (የተከፈለበት)');

      // Afaan Oromoo
      expect(omLoc.profile, 'Piroofayilii');
      expect(omLoc.settings, 'Qindaa’inoota');
      expect(omLoc.personalInfo, 'Oodeeffannoo Dhuunfaa');
      expect(omLoc.subscriptionPayment, 'Kaffaltii & Tajaajila');
      expect(omLoc.grade, 'Kutaa');
      expect(omLoc.subjects, 'Gosa Barnootaa');
      expect(omLoc.statusActive, 'Hojjachaa Jira (Kaffalame)');
    });

    test('AppLocalizations falls back to English for unknown keys', () {
      const amLoc = AppLocalizations(Locale('am'));
      expect(amLoc.translate('non_existent_key'), 'non_existent_key');
    });
  });

  group('AppSettingsController Tests', () {
    test('Initializes defaults and allows updating preferences', () async {
      final controller = AppSettingsController.instance;
      await controller.initialize();

      expect(controller.isInitialized, isTrue);
      expect(controller.pushNotifications, isTrue);
      expect(controller.announcements, isTrue);
      expect(controller.paymentAlerts, isTrue);

      // Theme toggle
      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);

      await controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, ThemeMode.light);

      // Language toggle
      await controller.setLanguage(AppLanguage.amharic);
      expect(controller.locale.languageCode, 'am');
      expect(controller.currentLanguage, AppLanguage.amharic);

      await controller.setLanguage(AppLanguage.afaanOromoo);
      expect(controller.locale.languageCode, 'om');
      expect(controller.currentLanguage, AppLanguage.afaanOromoo);

      // Reset to English
      await controller.setLanguage(AppLanguage.english);
      expect(controller.locale.languageCode, 'en');

      // Notification flags
      await controller.updateNotificationPreferences(push: false, announcements: true, paymentAlerts: true);
      expect(controller.pushNotifications, isFalse);
      expect(controller.announcements, isTrue);
    });
  });

  group('AboutEduRiseScreen Widget Test', () {
    testWidgets('Renders all required About EduRise sections, offerings, and version', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AboutEduRiseScreen(),
        ),
      );

      // App Title & Tagline
      expect(find.text('EduRise'), findsWidgets);
      expect(find.text('Learn • Practice • Grow'), findsOneWidget);

      // About description
      expect(find.text('About EduRise'), findsWidgets);
      expect(
        find.text(
          'EduRise is a learning platform designed to help Ethiopian students learn, practice, prepare for examinations, and track their academic progress.',
        ),
        findsOneWidget,
      );

      // What EduRise Offers
      expect(find.text('What EduRise Offers'), findsOneWidget);
      expect(find.text('Learning Materials'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('Study Plan'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Exam Preparation'), findsOneWidget);

      // Our Goal
      expect(find.text('Our Goal'), findsOneWidget);
      expect(
        find.text(
          'To make quality learning resources, practice, and academic preparation more accessible to Ethiopian students.',
        ),
        findsOneWidget,
      );

      // Version & Copyright
      expect(find.text('Version 1.0.0+1'), findsOneWidget);
      expect(find.text('© 2026 EduRise. All rights reserved.'), findsOneWidget);
    });
  });
}
