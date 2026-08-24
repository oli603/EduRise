import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // =====================================================
          // PROFILE HEADER
          // =====================================================
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 48,
                  child: Icon(Icons.person_rounded, size: 50),
                ),

                const SizedBox(height: 16),

                const Text(
                  'EduRise Student',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                Text(
                  'Student',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // =====================================================
          // ACCOUNT
          // =====================================================
          const Text(
            'Account',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Personal Information'),
              subtitle: const Text('Manage your profile information'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                // We will connect this later.
              },
            ),
          ),

          const SizedBox(height: 24),

          // =====================================================
          // LEARNING
          // =====================================================
          const Text(
            'Learning',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Grade'),
                  subtitle: const Text('Your current grade'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    // We will connect this later.
                  },
                ),

                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Subjects'),
                  subtitle: const Text('Manage your learning subjects'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    // We will connect this later.
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // =====================================================
          // PREFERENCES
          // =====================================================
          const Text(
            'Preferences',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    // We will connect this later.
                  },
                ),

                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Appearance'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    // We will connect this later.
                  },
                ),

                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Language'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    // We will connect this later.
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // =====================================================
          // SIGN OUT
          // =====================================================
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                // We will connect Firebase sign-out later.
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
