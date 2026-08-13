import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:edurise/features/home/widgets/greeting_section.dart';
import 'package:edurise/features/home/widgets/quick_access_section.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _getStudentProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load your profile.'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Student profile not found.'));
            }

            final data = snapshot.data!.data();

            final studentName = data?['name'] as String? ?? 'Student';

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GreetingSection(studentName: studentName),

                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/admin/add-question');
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin: Add Question'),
                  ),

                  const QuickAccessSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
