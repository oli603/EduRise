import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedStream = "Natural Science";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              const Text(
                "Welcome to EduRise",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                "Choose your stream to personalize "
                "your learning experience.",
              ),

              const SizedBox(height: 40),

              Expanded(
                child: Column(
                  children: [
                    _buildScienceCard(
                      title: "Natural Science",
                      subjects:
                          "Math • Physics • Chemistry • Biology • SAT • English",
                      selected: _selectedStream == "Natural Science",
                      onTap: () {
                        setState(() {
                          _selectedStream = "Natural Science";
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    _buildScienceCard(
                      title: "Social Science",
                      subjects:
                          "Math • History • Geography • Economics • SAT • English",
                      selected: _selectedStream == "Social Science",
                      onTap: () {
                        setState(() {
                          _selectedStream = "Social Science";
                        });
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: "Continue",
                  onPressed: () {
                    context.go(
                      '/auth?stream=${Uri.encodeComponent(_selectedStream)}',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScienceCard({
    required String title,
    required String subjects,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              subjects,
              style: TextStyle(
                color: selected ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
