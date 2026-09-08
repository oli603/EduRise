import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:edurise/features/admin/data/admin_service.dart';
import 'package:edurise/features/home/widgets/greeting_section.dart';
import 'package:edurise/features/home/widgets/quick_access_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = _getStudentProfile();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getStudentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    try {
      return await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();
    } catch (e) {
      debugPrint('HomeScreen student profile fetch error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          // ==================================================
          // LOADING
          // ==================================================
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ==================================================
          // ERROR STATE
          // ==================================================
          if (snapshot.hasError) {
            if (AdminService.isAuthorizedAdmin) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  GreetingSection(
                    studentName: AdminService.isFounder
                        ? 'Founder (Admin Preview)'
                        : 'Admin (Preview)',
                  ),
                  const SizedBox(height: 30),
                  const QuickAccessSection(),
                  const SizedBox(height: 30),
                ],
              );
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 56, color: Colors.amber),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load your profile.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please check your connection or complete your profile setup.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _loadProfile();
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => context.go('/profile-setup'),
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Text('Set Up Profile'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          // ==================================================
          // PROFILE NOT FOUND STATE
          // ==================================================
          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            if (AdminService.isAuthorizedAdmin) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  GreetingSection(
                    studentName: AdminService.isFounder
                        ? 'Founder (Admin Preview)'
                        : 'Admin (Preview)',
                  ),
                  const SizedBox(height: 30),
                  const QuickAccessSection(),
                  const SizedBox(height: 30),
                ],
              );
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 64, color: Colors.indigo),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to EduRise!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please complete your personalization to start practicing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/profile-setup'),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Complete Profile Setup'),
                    ),
                  ],
                ),
              ),
            );
          }

          // ==================================================
          // STUDENT DATA & NORMAL DASHBOARD
          // ==================================================
          final data = doc.data();
          final studentName = data?['name'] as String? ??
              data?['fullName'] as String? ??
              'Student';

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
