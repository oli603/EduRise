import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/challenge_model.dart';
import '../data/challenge_service.dart';

class AddChallengeScreen extends StatefulWidget {
  const AddChallengeScreen({super.key});

  @override
  State<AddChallengeScreen> createState() => _AddChallengeScreenState();
}

class _AddChallengeScreenState extends State<AddChallengeScreen> {
  final _formKey = GlobalKey<FormState>();

  final ChallengeService _challengeService = ChallengeService();

  // ------------------------------------------------------------
  // CONTROLLERS
  // ------------------------------------------------------------

  final TextEditingController _unitNumberController = TextEditingController();

  final TextEditingController _unitNameController = TextEditingController();

  final TextEditingController _targetController = TextEditingController();

  final TextEditingController _rewardXpController = TextEditingController();

  // ------------------------------------------------------------
  // DEFAULT VALUES
  // ------------------------------------------------------------

  String _grade = 'Grade 12';

  String _subject = 'Mathematics';

  DateTime _scheduledDate = DateTime.now();

  bool _isSaving = false;

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------

  @override
  void dispose() {
    _unitNumberController.dispose();
    _unitNameController.dispose();
    _targetController.dispose();
    _rewardXpController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // SELECT DATE
  // ------------------------------------------------------------

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _scheduledDate = selectedDate;
    });
  }

  // ------------------------------------------------------------
  // SAVE CHALLENGE
  // ------------------------------------------------------------

  Future<void> _saveChallenge() async {
    // Validate form first.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check authentication.
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first.')));

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // --------------------------------------------------------
      // CONVERT INPUTS
      // --------------------------------------------------------

      final unitNumber = int.parse(_unitNumberController.text.trim());

      final targetCount = int.parse(_targetController.text.trim());

      final rewardXp = int.parse(_rewardXpController.text.trim());

      final unitName = _unitNameController.text.trim();

      // --------------------------------------------------------
      // CREATE CHALLENGE
      // --------------------------------------------------------

      final challenge = Challenge(
        id: '',
        userId: user.uid,

        title: 'Master $unitName',

        description:
            'Practice $unitName questions and improve your $_subject performance.',

        challengeType: 'practice',

        grade: _grade,

        subject: _subject,

        // IMPORTANT:
        // These two were missing before.
        unitNumber: unitNumber,

        unitName: unitName,

        targetCount: targetCount,

        currentCount: 0,

        scheduledDate: DateTime(
          _scheduledDate.year,
          _scheduledDate.month,
          _scheduledDate.day,
        ),

        isCompleted: false,

        rewardXp: rewardXp,

        createdAt: null,
      );

      // --------------------------------------------------------
      // SAVE TO FIRESTORE
      // --------------------------------------------------------

      await _challengeService.addChallenge(challenge);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge created successfully.')),
      );

      // Go back to previous screen.
      context.pop(true);
    } catch (e) {
      debugPrint('ADD CHALLENGE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create challenge: $e')));
    }
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Challenge',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: Form(
        key: _formKey,

        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),

          children: [
            // ====================================================
            // HEADER
            // ====================================================
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),

              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),

              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 40,
                  ),

                  SizedBox(height: 12),

                  Text(
                    'Create Practice Challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    'Choose the unit and target EduRise should use for this challenge.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ====================================================
            // GRADE
            // ====================================================
            DropdownButtonFormField<String>(
              initialValue: _grade,

              decoration: const InputDecoration(
                labelText: 'Grade',
                prefixIcon: Icon(Icons.school_outlined),
              ),

              items: const [
                DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
                DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10')),
                DropdownMenuItem(value: 'Grade 11', child: Text('Grade 11')),
                DropdownMenuItem(value: 'Grade 12', child: Text('Grade 12')),
              ],

              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _grade = value;
                });
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ====================================================
            // SUBJECT
            // ====================================================
            DropdownButtonFormField<String>(
              initialValue: _subject,

              decoration: const InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'Mathematics',
                  child: Text('Mathematics'),
                ),
                DropdownMenuItem(value: 'Physics', child: Text('Physics')),
                DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry')),
                DropdownMenuItem(value: 'Biology', child: Text('Biology')),
                DropdownMenuItem(value: 'English', child: Text('English')),
              ],

              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _subject = value;
                });
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ====================================================
            // UNIT NUMBER
            // ====================================================
            TextFormField(
              controller: _unitNumberController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: 'Unit Number',
                hintText: 'Example: 3',
                prefixIcon: Icon(Icons.format_list_numbered_rounded),
              ),

              onChanged: (_) {
                setState(() {});
              },

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the unit number.';
                }

                final number = int.tryParse(value.trim());

                if (number == null || number <= 0) {
                  return 'Enter a valid unit number.';
                }

                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ====================================================
            // UNIT NAME
            // ====================================================
            TextFormField(
              controller: _unitNameController,

              decoration: const InputDecoration(
                labelText: 'Unit Name',
                hintText: 'Example: Functions',
                prefixIcon: Icon(Icons.menu_book_rounded),
              ),

              onChanged: (_) {
                setState(() {});
              },

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the unit name.';
                }

                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ====================================================
            // TARGET QUESTIONS
            // ====================================================
            TextFormField(
              controller: _targetController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: 'Target Questions',
                hintText: 'Example: 10',
                prefixIcon: Icon(Icons.track_changes_rounded),
              ),

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a target.';
                }

                final number = int.tryParse(value.trim());

                if (number == null || number <= 0) {
                  return 'Enter a number greater than 0.';
                }

                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ====================================================
            // REWARD XP
            // ====================================================
            TextFormField(
              controller: _rewardXpController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: 'Reward XP',
                hintText: 'Example: 100',
                prefixIcon: Icon(Icons.auto_awesome_rounded),
              ),

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter reward XP.';
                }

                final number = int.tryParse(value.trim());

                if (number == null || number < 0) {
                  return 'Enter a valid XP amount.';
                }

                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ====================================================
            // DATE
            // ====================================================
            Card(
              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),

                side: const BorderSide(color: AppColors.border),
              ),

              child: ListTile(
                leading: Container(
                  height: 42,
                  width: 42,

                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: AppColors.primary.withOpacity(0.10),

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                  ),
                ),

                title: const Text(
                  'Challenge date',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                subtitle: Text(
                  '${_scheduledDate.day}/'
                  '${_scheduledDate.month}/'
                  '${_scheduledDate.year}',
                ),

                trailing: TextButton(
                  onPressed: _selectDate,
                  child: const Text('Change'),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ====================================================
            // CHALLENGE PREVIEW
            // ====================================================
            Container(
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Challenge Preview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _unitNameController.text.trim().isEmpty
                        ? 'Master your unit'
                        : 'Master ${_unitNameController.text.trim()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _unitNumberController.text.trim().isEmpty
                        ? 'Unit • $_grade • $_subject'
                        : 'Unit ${_unitNumberController.text.trim()} • $_grade • $_subject',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _targetController.text.trim().isEmpty
                        ? 'Target: — questions'
                        : 'Target: ${_targetController.text.trim()} questions',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _rewardXpController.text.trim().isEmpty
                        ? 'Reward: — XP'
                        : 'Reward: ${_rewardXpController.text.trim()} XP',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ====================================================
            // CREATE BUTTON
            // ====================================================
            SizedBox(
              height: 56,

              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveChallenge,

                icon: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_task_rounded),

                label: Text(
                  _isSaving ? 'Creating Challenge...' : 'Create Challenge',
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
