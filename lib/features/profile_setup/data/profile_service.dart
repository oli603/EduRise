import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // CHECK IF PROFILE EXISTS
  // ============================================================

  Future<bool> profileExists() async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final document = await _firestore
        .collection('students')
        .doc(user.uid)
        .get();

    return document.exists;
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> saveProfile({
    required String name,
    required String grade,
    required String stream,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    await _firestore.collection('students').doc(user.uid).set({
      'name': name.trim(),
      'email': user.email,
      'grade': grade,
      'stream': stream,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
