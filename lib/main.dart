import 'package:edurise/core/routes/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GoogleSignIn.instance.initialize();

  runApp(const EduRiseApp());
}

class EduRiseApp extends StatelessWidget {
  const EduRiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "EduRise",
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      routerConfig: AppRouter.router,
    );
  }
}
