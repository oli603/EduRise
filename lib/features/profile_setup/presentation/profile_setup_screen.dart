import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/edurise_text_field.dart';
import 'package:edurise/features/profile_setup/data/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.stream});

  final String stream;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final ProfileService _profileService = ProfileService();

  String? _selectedGrade;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    // Validate name
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate grade
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your grade.")),
      );

      return;
    }

    // Validate stream
    if (widget.stream.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your stream was not selected.")),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save complete student profile
      await _profileService.saveProfile(
        name: _nameController.text,
        grade: _selectedGrade!,
        stream: widget.stream,
      );

      if (!mounted) return;

      context.go('/home');
    } catch (e) {
      debugPrint("🔥 PROFILE SAVE ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),

                const Text(
                  "Let's personalize EduRise",
                  style: AppTextStyles.heading1,
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  "Tell us a little about yourself so we can "
                  "create a better learning experience for you.",
                  style: AppTextStyles.body.copyWith(color: Colors.black54),
                ),

                const SizedBox(height: 40),

                const Text(
                  "Full Name",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 10),

                EduRiseTextField(
                  controller: _nameController,
                  label: "Full Name",
                  hint: "Enter your full name",
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter your name.";
                    }

                    if (value.trim().length < 3) {
                      return "Name must be at least 3 characters.";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 30),

                const Text(
                  "Which grade are you in?",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                _buildChoiceCard(
                  title: "Grade 11",
                  selected: _selectedGrade == "Grade 11",
                  onTap: () {
                    setState(() {
                      _selectedGrade = "Grade 11";
                    });
                  },
                ),

                const SizedBox(height: 12),

                _buildChoiceCard(
                  title: "Grade 12",
                  selected: _selectedGrade == "Grade 12",
                  onTap: () {
                    setState(() {
                      _selectedGrade = "Grade 12";
                    });
                  },
                ),

                const SizedBox(height: 30),

                // --------------------------------------------------
                // STREAM
                // --------------------------------------------------
                const Text(
                  "Your stream",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      // ignore: deprecated_member_use
                      color: AppColors.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.stream == "Natural Science"
                            ? Icons.science_rounded
                            : Icons.public_rounded,
                        color: AppColors.primary,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Selected Stream",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              widget.stream,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: _isLoading ? "Saving..." : "Continue",
                    onPressed: _isLoading ? null : _continue,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),

            if (selected)
              const Icon(Icons.check_circle_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
