import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/edurise_text_field.dart';
import 'package:edurise/features/profile_setup/data/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.stream = ''});

  final String stream;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final ProfileService _profileService = ProfileService();

  String? _selectedGrade;
  String? _selectedStream;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.stream.isNotEmpty) {
      final normalized = widget.stream.toLowerCase();
      if (normalized.contains('social')) {
        _selectedStream = 'social';
      } else if (normalized.contains('natural')) {
        _selectedStream = 'natural';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    // Validate form inputs (name and stream)
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
    if (_selectedStream == null || _selectedStream!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your stream.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save complete student profile
      await _profileService.saveProfile(
        name: _nameController.text.trim(),
        grade: _selectedGrade!,
        stream: _selectedStream!,
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

                // --------------------------------------------------
                // FULL NAME (SINGLE FIELD WITH LABEL)
                // --------------------------------------------------
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
                  title: "Grade 9",
                  selected: _selectedGrade == "Grade 9",
                  onTap: () {
                    setState(() {
                      _selectedGrade = "Grade 9";
                    });
                  },
                ),

                const SizedBox(height: 12),

                _buildChoiceCard(
                  title: "Grade 10",
                  selected: _selectedGrade == "Grade 10",
                  onTap: () {
                    setState(() {
                      _selectedGrade = "Grade 10";
                    });
                  },
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
                // STREAM (SELECTABLE DROPDOWN)
                // --------------------------------------------------
                const Text(
                  "Stream",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedStream,
                  decoration: InputDecoration(
                    hintText: "Select Stream",
                    prefixIcon: const Icon(Icons.school_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'natural',
                      child: Text('Natural'),
                    ),
                    DropdownMenuItem(
                      value: 'social',
                      child: Text('Social'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStream = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please select your stream.";
                    }
                    return null;
                  },
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
