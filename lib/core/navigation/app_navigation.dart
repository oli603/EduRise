import 'package:flutter/material.dart';

/// Defines the main destinations of the EduRise student app.
///
/// These are the destinations that appear in the bottom navigation bar.
class AppNavigationDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  const AppNavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}

/// Main student navigation destinations.
class AppNavigation {
  static const List<AppNavigationDestination> destinations = [
    AppNavigationDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: '/home',
    ),
    AppNavigationDestination(
      label: 'Practice',
      icon: Icons.quiz_outlined,
      selectedIcon: Icons.quiz_rounded,
      route: '/practice-selection',
    ),
    AppNavigationDestination(
      label: 'Games',
      icon: Icons.sports_esports_outlined,
      selectedIcon: Icons.sports_esports_rounded,
      route: '/game',
    ),
    AppNavigationDestination(
      label: 'Progress',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      route: '/progress',
    ),
    AppNavigationDestination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      route: '/profile',
    ),
  ];
}
