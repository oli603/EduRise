import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_navigation.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: const Text(
          'EduRise',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // ========================================================
      // CURRENT STUDENT SCREEN
      // ========================================================
      body: navigationShell,

      // ========================================================
      // DRAWER
      // ========================================================
      drawer: _buildDrawer(context),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: AppNavigation.destinations.map((destination) {
          return NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // DRAWER
  // ============================================================

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ==================================================
            // HEADER
            // ==================================================
            _buildDrawerHeader(context),

            const Divider(),

            // ==================================================
            // MAIN NAVIGATION
            // ==================================================
            ListTile(
              leading: const Icon(Icons.history_edu_outlined),
              title: const Text('Past Entrance Exams'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/admin/past-exams/upload');
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pop();

                navigationShell.goBranch(0, initialLocation: true);
              },
            ),

            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Books'),
              onTap: () {
                Navigator.of(context).pop();

                context.push('/books');
              },
            ),

            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Study Plan'),
              onTap: () {
                Navigator.of(context).pop();

                context.push('/study-plan');
              },
            ),

            // ==================================================
            // EXAMS
            // ==================================================
            ListTile(
              leading: const Icon(Icons.history_edu_outlined),
              title: const Text('Past Entrance Exams'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/past-entrance-exams');
              },
            ),

            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: const Text('Predicted Mock Exam'),
              onTap: () {
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Predicted Mock Exam will be available soon.',
                    ),
                  ),
                );
              },
            ),

            // ==================================================
            // DOWNLOADS
            // ==================================================
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Downloads'),
              onTap: () {
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Downloads will be available soon.'),
                  ),
                );
              },
            ),

            const Divider(),

            // ==================================================
            // SETTINGS
            // ==================================================
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings will be available soon.'),
                  ),
                );
              },
            ),

            // ==================================================
            // ABOUT
            // ==================================================
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About EduRise'),
              onTap: () {
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('About EduRise will be available soon.'),
                  ),
                );
              },
            ),

            const Divider(),

            // ==================================================
            // SIGN OUT
            // ==================================================
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.of(context).pop();

                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DRAWER HEADER
  // ============================================================

  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CircleAvatar(radius: 28, child: Icon(Icons.school_rounded, size: 30)),

          SizedBox(height: 12),

          Text(
            'EduRise',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 4),

          Text(
            'Student',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
