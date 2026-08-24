import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:edurise/features/home/widgets/greeting_section.dart';
import 'package:edurise/features/home/widgets/quick_access_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>> _getStudentProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    return FirebaseFirestore.instance
        .collection('students')
        .doc(user.uid)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _getStudentProfile(),

        builder: (context, snapshot) {
          // ==================================================
          // LOADING
          // ==================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ==================================================
          // ERROR
          // ==================================================

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load your profile.'));
          }

          // ==================================================
          // PROFILE NOT FOUND
          // ==================================================

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Student profile not found.'));
          }

          // ==================================================
          // STUDENT DATA
          // ==================================================

          final data = snapshot.data!.data();

          final studentName = data?['name'] as String? ?? 'Student';

          // ==================================================
          // DASHBOARD
          // ==================================================

          return ListView(
            padding: const EdgeInsets.all(24),

            children: [
              // ------------------------------------------------
              // GREETING
              // ------------------------------------------------
              GreetingSection(studentName: studentName),

              const SizedBox(height: 30),

              // ------------------------------------------------
              // QUICK ACCESS
              // ------------------------------------------------
              const QuickAccessSection(),

              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}
