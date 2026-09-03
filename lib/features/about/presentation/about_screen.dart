import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AboutEduRiseScreen extends StatelessWidget {
  const AboutEduRiseScreen({super.key});

  static const String appVersion = '1.0.0+1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About EduRise',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Banner & Tagline
          Center(
            child: Column(
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'EduRise',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Learn • Practice • Grow',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // About Description Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About EduRise',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'EduRise is a learning platform designed to help Ethiopian students learn, practice, prepare for examinations, and track their academic progress.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // What EduRise Offers
          const Text(
            'What EduRise Offers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildFeatureTile(
            icon: Icons.menu_book_rounded,
            title: 'Learning Materials',
            description: 'Access organized educational resources to support your studies.',
          ),
          const SizedBox(height: 10),
          _buildFeatureTile(
            icon: Icons.quiz_rounded,
            title: 'Practice',
            description: 'Practice questions and evaluate your academic performance.',
          ),
          const SizedBox(height: 10),
          _buildFeatureTile(
            icon: Icons.calendar_month_rounded,
            title: 'Study Plan',
            description: 'Organize your learning and build consistent study habits.',
          ),
          const SizedBox(height: 10),
          _buildFeatureTile(
            icon: Icons.trending_up_rounded,
            title: 'Progress',
            description: 'Understand your performance and identify areas that need improvement.',
          ),
          const SizedBox(height: 10),
          _buildFeatureTile(
            icon: Icons.history_edu_rounded,
            title: 'Exam Preparation',
            description: 'Prepare more effectively for important national examinations.',
          ),
          const SizedBox(height: 24),

          // Our Goal
          Card(
            elevation: 0,
            color: AppColors.primary.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_rounded, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Our Goal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'To make quality learning resources, practice, and academic preparation more accessible to Ethiopian students.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Version & Copyright
          Center(
            child: Column(
              children: [
                Text(
                  'Version $appVersion',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  '© 2026 EduRise. All rights reserved.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
