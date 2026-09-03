import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';

class AppSettingsController extends ChangeNotifier {
  static final AppSettingsController instance = AppSettingsController._internal();

  AppSettingsController._internal();

  static const String _keyThemeMode = 'edurise_theme_mode';
  static const String _keyLocale = 'edurise_locale';
  static const String _keyPush = 'edurise_notif_push';
  static const String _keyAnnouncements = 'edurise_notif_announcements';
  static const String _keyPayment = 'edurise_notif_payment';

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');
  bool _pushNotifications = true;
  bool _announcements = true;
  bool _paymentAlerts = true;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get pushNotifications => _pushNotifications;
  bool get announcements => _announcements;
  bool get paymentAlerts => _paymentAlerts;
  bool get isInitialized => _isInitialized;

  AppLanguage get currentLanguage => AppLanguage.fromCode(_locale.languageCode);

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Theme
    final savedTheme = prefs.getString(_keyThemeMode);
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    // Locale
    final savedLocale = prefs.getString(_keyLocale);
    if (savedLocale != null && ['en', 'am', 'om'].contains(savedLocale)) {
      _locale = Locale(savedLocale);
    } else {
      _locale = const Locale('en');
    }

    // Notifications
    _pushNotifications = prefs.getBool(_keyPush) ?? true;
    _announcements = prefs.getBool(_keyAnnouncements) ?? true;
    _paymentAlerts = prefs.getBool(_keyPayment) ?? true;

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_keyThemeMode, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_keyThemeMode, 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString(_keyThemeMode, 'system');
        break;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    final newLocale = language.locale;
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, language.code);
  }

  Future<void> updateNotificationPreferences({
    bool? push,
    bool? announcements,
    bool? paymentAlerts,
  }) async {
    if (push != null) _pushNotifications = push;
    if (announcements != null) _announcements = announcements;
    if (paymentAlerts != null) _paymentAlerts = paymentAlerts;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPush, _pushNotifications);
    await prefs.setBool(_keyAnnouncements, _announcements);
    await prefs.setBool(_keyPayment, _paymentAlerts);

    // Also persist non-sensitive preference to student doc if logged in
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('students').doc(user.uid).set({
          'preferences': {
            'pushNotifications': _pushNotifications,
            'announcements': _announcements,
            'paymentAlerts': _paymentAlerts,
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Skipping Firestore sync for notification preferences: $e');
    }
  }
}
