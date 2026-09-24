import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_service.dart';
import '../../../core/constants/app_grades.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/edurise_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../profile/data/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.stream = ''});

  final String stream;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  final ProfileService _profileService = ProfileService();

  String? _selectedGrade;
  String? _selectedStream;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    String initialName = '';
    try {
      initialName = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    } catch (_) {
      initialName = '';
    }
    _nameController = TextEditingController(text: initialName);

    // Initialize stream selection from onboarding query param if provided
    if (widget.stream.isNotEmpty) {
      _selectedStream = EduRiseSubjects.canonicalizeStream(widget.stream);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _sanitizeErrorMessage(dynamic error) {
    final str = error.toString();
    if (str.contains('registered for') && str.contains('cannot change your stream')) {
      return str.replaceAll('Exception: ', '').replaceAll('🔥 PROFILE SAVE ERROR: ', '').trim();
    }
    if (str.contains('network-request-failed') ||
        str.contains('unavailable') ||
        str.contains('deadline-exceeded') ||
        str.contains('TimeoutException')) {
      return 'Connection timed out. Please check your internet connection and try again.';
    }
    if (str.contains('permission-denied')) {
      return 'Permission denied. Please verify your sign-in session and try again.';
    }
    if (str.contains('No authenticated user')) {
      return 'You are not signed in. Please sign in to save your profile.';
    }
    return 'Unable to save profile. Please check your connection and try again.';
  }

  Future<void> _continue() async {
    // 1. Validate name input
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Validate grade selection
    if (_selectedGrade == null || !EduRiseGrades.isValid(_selectedGrade)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your grade.")),
      );
      return;
    }

    // 3. Validate stream selection
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

      // Authoritative post-auth routing
      final destination =
          await RoleService.resolvePostAuthRoute(forceRefresh: true);

      if (!mounted) return;

      context.go(destination);
    } catch (e) {
      debugPrint("🔥 PROFILE SAVE ERROR: $e");

      if (!mounted) return;

      final userFriendlyMessage = _sanitizeErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyMessage),
          backgroundColor: AppColors.error,
        ),
      );
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
                  "Tell us a little about yourself so we can create a better learning experience for you.",
                  style: AppTextStyles.body.copyWith(color: Colors.black54),
                ),

                const SizedBox(height: 40),

                // --------------------------------------------------
                // FULL NAME (SINGLE FIELD WITH ERGONOMICS)
                // --------------------------------------------------
                EduRiseTextField(
                  controller: _nameController,
                  label: "Full Name",
                  hint: "Enter your full name",
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  enabled: !_isLoading,
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

                // --------------------------------------------------
                // GRADE SELECTION (CANONICAL GRADES)
                // --------------------------------------------------
                const Text(
                  "Which grade are you in?",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                ...EduRiseGrades.all.map((grade) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildChoiceCard(
                      title: grade,
                      selected: _selectedGrade == grade,
                      onTap: _isLoading
                          ? () {}
                          : () {
                              setState(() {
                                _selectedGrade = grade;
                              });
                            },
                    ),
                  );
                }),

                const SizedBox(height: 18),

                // --------------------------------------------------
                // STREAM (SELECTABLE DROPDOWN)
                // --------------------------------------------------
                const Text(
                  "Stream",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _selectedStream,
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
                  onChanged: _isLoading
                      ? null
                      : (value) {
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
