import 'package:edurise/core/offline/connectivity_service.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/core/offline/sync_service.dart';
import 'package:edurise/core/routes/app_router.dart';
import 'package:edurise/features/notifications/data/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/localization/app_localizations.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase Core (Prerequisite for Firebase services)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 2. Initialize essential local services concurrently in parallel
  await Future.wait([
    AppSettingsController.instance.initialize(),
    OfflineStorageService().init(),
    NotificationService().initialize(),
  ]);

  // 3. Initialize on-demand auth providers non-blocking
  GoogleSignIn.instance.initialize(
    serverClientId: '935368980876-e77v60qedbufrhp0kj0ee0suaqujdmk1.apps.googleusercontent.com',
  ).catchError((e) {
    debugPrint('GoogleSignIn initialization: $e');
  });

  // 4. Start connectivity monitoring and background synchronization listener
  final connectivity = ConnectivityService();
  connectivity.startMonitoring();
  connectivity.onConnectivityChanged.listen((isOnline) {
    if (isOnline) {
      SyncService().syncAll();
    }
  });

  runApp(const EduRiseApp());
}

class EduRiseApp extends StatelessWidget {
  const EduRiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: "EduRise",
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (locale, supportedLocales) {
            for (final supported in supportedLocales) {
              if (supported.languageCode == locale?.languageCode) {
                return supported;
              }
            }
            return const Locale('en');
          },
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
