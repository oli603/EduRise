import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static const String founderEmail = 'olanamengistu2@gmail.com';
  static const String adminEmail = 'tamiratboja@gmail.com';

  static String? get currentUserEmail {
    return FirebaseAuth.instance.currentUser?.email?.toLowerCase();
  }

  static bool get isFounder {
    return currentUserEmail == founderEmail;
  }

  static bool get isAdmin {
    return currentUserEmail == adminEmail;
  }

  static bool get isAuthorizedAdmin {
    return isFounder || isAdmin;
  }
}
