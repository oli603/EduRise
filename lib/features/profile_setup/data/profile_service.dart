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
  // STREAM CURRENT STUDENT PROFILE
  // ============================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>>? getProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return null;

    return _firestore.collection('students').doc(user.uid).snapshots();
  }

  // ============================================================
  // GET PROFILE DATA (ONCE)
  // ============================================================

  Future<Map<String, dynamic>?> getProfileData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('students').doc(user.uid).get();
    return doc.data();
  }

  // ============================================================
  // SAVE PROFILE (ONBOARDING)
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

  // ============================================================
  // UPDATE PERSONAL INFORMATION
  // ============================================================

  Future<void> updatePersonalInfo({
    required String name,
    required String stream,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _firestore.collection('students').doc(user.uid).update({
      'name': name.trim(),
      'stream': stream.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UPDATE GRADE
  // ============================================================

  Future<void> updateGrade({required String grade}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _firestore.collection('students').doc(user.uid).update({
      'grade': grade.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
