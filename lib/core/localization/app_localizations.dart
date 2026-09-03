import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

enum AppLanguage {
  english('en', 'English', 'English'),
  amharic('am', 'Amharic', 'አማርኛ'),
  afaanOromoo('om', 'Afaan Oromoo', 'Afaan Oromoo');

  final String code;
  final String englishName;
  final String nativeName;

  const AppLanguage(this.code, this.englishName, this.nativeName);

  static AppLanguage fromCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'am':
        return AppLanguage.amharic;
      case 'om':
        return AppLanguage.afaanOromoo;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }

  Locale get locale => Locale(code);
}

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('am'),
    Locale('om'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    FallbackMaterialLocalizationsDelegate(),
    FallbackCupertinoLocalizationsDelegate(),
    FallbackWidgetsLocalizationsDelegate(),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      // General / Navigation
      'app_name': 'EduRise',
      'profile': 'Profile',
      'settings': 'Settings',
      'about_edurise': 'About EduRise',
      'account': 'Account',
      'learning': 'Learning',
      'preferences': 'Preferences',
      'support': 'Support',
      'about': 'About',
      'sign_out': 'Sign Out',
      'save': 'Save',
      'cancel': 'Cancel',
      'close': 'Close',

      // Profile - Account
      'personal_info': 'Personal Information',
      'manage_personal_info': 'Manage your profile information',
      'subscription_payment': 'Subscription & Payment',
      'subscription_payment_sub': 'View status or submit verification receipt',
      'edit_profile': 'Edit Profile',
      'full_name': 'Full Name',
      'stream': 'Stream',
      'natural_science': 'Natural Science',
      'social_science': 'Social Science',

      // Profile - Learning
      'grade': 'Grade',
      'current_grade': 'Your current grade',
      'subjects': 'Subjects',
      'manage_subjects': 'Manage your learning subjects',
      'select_grade': 'Select Grade',

      // Preferences
      'notifications': 'Notifications',
      'appearance': 'Appearance',
      'language': 'Language',
      'theme_system': 'System Default',
      'theme_light': 'Light Mode',
      'theme_dark': 'Dark Mode',
      'push_notifications': 'Push Notifications',
      'announcements': 'Announcements',
      'payment_alerts': 'Payment & Verification Alerts',

      // Status
      'status_active': 'Active (Paid Access)',
      'status_pending': 'Verification Pending',
      'status_free': 'Free / Locked',

      // Support & About
      'help_support': 'Help & Support',
      'report_problem': 'Report a Problem',
      'privacy_policy': 'Privacy Policy',
      'terms_service': 'Terms of Service',
      'version': 'Version',
    },
    'am': {
      // General / Navigation
      'app_name': 'ኤዱራይዝ',
      'profile': 'መገለጫ',
      'settings': 'ቅንብሮች',
      'about_edurise': 'ስለ ኤዱራይዝ',
      'account': 'መለያ',
      'learning': 'ትምህርት',
      'preferences': 'ምርጫዎች',
      'support': 'እርዳታና ድጋፍ',
      'about': 'ስለ እኛ',
      'sign_out': 'ውጣ',
      'save': 'አስቀምጥ',
      'cancel': 'ሰርዝ',
      'close': 'ዝጋ',

      // Profile - Account
      'personal_info': 'የግል መረጃ',
      'manage_personal_info': 'የግል መረጃዎን ያስተዳድሩ',
      'subscription_payment': 'የአባልነት ክፍያ',
      'subscription_payment_sub': 'የክፍያ ሁኔታ ይመልከቱ ወይም ደረሰኝ ያስገቡ',
      'edit_profile': 'መገለጫ አርትዕ',
      'full_name': 'ሙሉ ስም',
      'stream': 'የትምህርት ዘርፍ',
      'natural_science': 'የተፈጥሮ ሳይንስ',
      'social_science': 'የማህበራዊ ሳይንስ',

      // Profile - Learning
      'grade': 'ክፍል',
      'current_grade': 'የአሁኑ የትምህርት ክፍልዎ',
      'subjects': 'የትምህርት አይነቶች',
      'manage_subjects': 'የትምህርት አይነቶችዎን ይመልከቱ',
      'select_grade': 'ክፍል ይምረጡ',

      // Preferences
      'notifications': 'ማሳወቂያዎች',
      'appearance': 'መልክና ገጽታ',
      'language': 'ቋንቋ',
      'theme_system': 'የስርዓቱ ברירת',
      'theme_light': 'ነጭ ገጽታ',
      'theme_dark': 'ጥቁር ገጽታ',
      'push_notifications': 'የግፊት ማሳወቂያዎች',
      'announcements': 'አጠቃላይ ማስታወቂያዎች',
      'payment_alerts': 'የክፍያና ማረጋገጫ ማሳወቂያዎች',

      // Status
      'status_active': 'ንቁ (የተከፈለበት)',
      'status_pending': 'በማረጋገጥ ላይ ያለ',
      'status_free': 'ነፃ / የተቆለፈ',

      // Support & About
      'help_support': 'እርዳታና ድጋፍ',
      'report_problem': 'ችግር ያመልክቱ',
      'privacy_policy': 'የግላዊነት መመሪያ',
      'terms_service': 'የአገልግሎት ውሎች',
      'version': 'ስሪት',
    },
    'om': {
      // General / Navigation
      'app_name': 'EduRise',
      'profile': 'Piroofayilii',
      'settings': 'Qindaa’inoota',
      'about_edurise': 'Waa’ee EduRise',
      'account': 'Akkaawuntii',
      'learning': 'Barnoota',
      'preferences': 'Filannoowwan',
      'support': 'Gargaarsa',
      'about': 'Waa’ee Keenya',
      'sign_out': 'Bahi',
      'save': 'Olkaawi',
      'cancel': 'Dhiisi',
      'close': 'Cufi',

      // Profile - Account
      'personal_info': 'Oodeeffannoo Dhuunfaa',
      'manage_personal_info': 'Oodeeffannoo piroofayilii keessan sirreessaa',
      'subscription_payment': 'Kaffaltii & Tajaajila',
      'subscription_payment_sub': 'Haala kaffaltii ilaalaa yookiin nagahee galchaa',
      'edit_profile': 'Piroofayilii Sirreessi',
      'full_name': 'Maqaa Guutuu',
      'stream': 'Gosa Barnootaa',
      'natural_science': 'Saayinsii Uumamaa',
      'social_science': 'Saayinsii Hawaasaa',

      // Profile - Learning
      'grade': 'Kutaa',
      'current_grade': 'Kutaa barnoota keessanii',
      'subjects': 'Gosa Barnootaa',
      'manage_subjects': 'Gosa barnoota keessanii qindeessaa',
      'select_grade': 'Kutaa Filadhaa',

      // Preferences
      'notifications': 'Beeksisa',
      'appearance': 'Bifa Appilikeeshinii',
      'language': 'Afaan',
      'theme_system': 'Sirna Moobaayilaa',
      'theme_light': 'Ifaa',
      'theme_dark': 'Dukkanaawaa',
      'push_notifications': 'Beeksisa Battalaa',
      'announcements': 'Beeksisa Waliigalaa',
      'payment_alerts': 'Beeksisa Kaffaltii',

      // Status
      'status_active': 'Hojjachaa Jira (Kaffalame)',
      'status_pending': 'Mirkanaa’uu Eegaa Jira',
      'status_free': 'Bilaasha / Cufameera',

      // Support & About
      'help_support': 'Gargaarsa & Deeggarsa',
      'report_problem': 'Rakkoo Gabaasaa',
      'privacy_policy': 'Imaammata Dhuunfaa',
      'terms_service': 'Waliigaltee Tajaajilaa',
      'version': 'Gosa (Version)',
    },
  };

  String translate(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  String get appName => translate('app_name');
  String get profile => translate('profile');
  String get settings => translate('settings');
  String get aboutEduRise => translate('about_edurise');
  String get account => translate('account');
  String get learning => translate('learning');
  String get preferences => translate('preferences');
  String get support => translate('support');
  String get about => translate('about');
  String get signOut => translate('sign_out');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get close => translate('close');

  String get personalInfo => translate('personal_info');
  String get managePersonalInfo => translate('manage_personal_info');
  String get subscriptionPayment => translate('subscription_payment');
  String get subscriptionPaymentSub => translate('subscription_payment_sub');
  String get editProfile => translate('edit_profile');
  String get fullName => translate('full_name');
  String get stream => translate('stream');
  String get naturalScience => translate('natural_science');
  String get socialScience => translate('social_science');

  String get grade => translate('grade');
  String get currentGrade => translate('current_grade');
  String get subjects => translate('subjects');
  String get manageSubjects => translate('manage_subjects');
  String get selectGrade => translate('select_grade');

  String get notifications => translate('notifications');
  String get appearance => translate('appearance');
  String get language => translate('language');
  String get themeSystem => translate('theme_system');
  String get themeLight => translate('theme_light');
  String get themeDark => translate('theme_dark');
  String get pushNotifications => translate('push_notifications');
  String get announcements => translate('announcements');
  String get paymentAlerts => translate('payment_alerts');

  String get statusActive => translate('status_active');
  String get statusPending => translate('status_pending');
  String get statusFree => translate('status_free');

  String get helpSupport => translate('help_support');
  String get reportProblem => translate('report_problem');
  String get privacyPolicy => translate('privacy_policy');
  String get termsService => translate('terms_service');
  String get version => translate('version');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'am', 'om'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return const DefaultMaterialLocalizations();
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    return const DefaultCupertinoLocalizations();
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}

class FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) async {
    return const DefaultWidgetsLocalizations();
  }

  @override
  bool shouldReload(FallbackWidgetsLocalizationsDelegate old) => false;
}
