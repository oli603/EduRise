import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/access_service.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/access_locked_dialog.dart';
import '../../practice/data/question_service.dart';
import '../../profile/data/profile_service.dart';
import '../data/challenge_generator.dart';
import '../data/challenge_model.dart';
import '../data/challenge_service.dart';

class ChallengesScreen extends StatefulWidget {
  final List<Challenge>? initialChallenges;

  const ChallengesScreen({super.key, this.initialChallenges});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  late final ChallengeService _challengeService;
  late final ChallengeGenerator _challengeGenerator;
  final ProfileService _profileService = ProfileService();

  late Future<List<Challenge>> _challengesFuture;
  String _studentStream = 'natural';

  @override
  void initState() {
    super.initState();
    if (widget.initialChallenges != null) {
      _challengesFuture = Future.value(widget.initialChallenges);
    } else {
      _challengeService = ChallengeService();
      _challengeGenerator = ChallengeGenerator();
      _loadChallenges();
    }
  }

  @override
  void didUpdateWidget(covariant ChallengesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialChallenges != null &&
        widget.initialChallenges != oldWidget.initialChallenges) {
      _challengesFuture = Future.value(widget.initialChallenges);
    }
  }

  /// Load today's challenges.
  ///
  /// If the student does not have a challenge yet,
  /// EduRise tries to generate one based on practice performance.
  void _loadChallenges() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _challengesFuture = Future.value([]);
      return;
    }

    _challengesFuture = _loadTodayChallenges(user.uid);
  }

  Future<List<Challenge>> _loadTodayChallenges(String userId) async {
    try {
      final profile = await _profileService.getProfile(uid: userId);
      if (profile != null && profile.stream.isNotEmpty) {
        _studentStream = EduRiseSubjects.isSocialStream(profile.stream) ? 'social' : 'natural';
      }
    } catch (_) {}

    final today = DateTime.now();

    // First, check whether today's challenge already exists.
    var challenges = await _challengeService.getChallengesForDate(
      userId: userId,
      date: today,
    );

    // If there is no challenge, let EduRise generate one.
    if (challenges.isEmpty) {
      final generatedChallenge = await _challengeGenerator.generateChallenge();

      // If a challenge was generated, load today's challenges again.
      if (generatedChallenge != null) {
        challenges = await _challengeService.getChallengesForDate(
          userId: userId,
          date: today,
        );
      }
    }

    final syncedChallenges = <Challenge>[];
    final questionService = QuestionService();

    for (final challenge in challenges) {
      if (challenge.challengeType == 'practice' && challenge.subject.isNotEmpty) {
        final stream = QuestionService.normalizeStream(_studentStream, subject: challenge.subject);
        try {
          final questions = await questionService.getQuestions(
            grade: challenge.grade,
            stream: stream,
            subject: challenge.subject,
            unitNumber: challenge.unitNumber,
          );

          final availableCount = questions.length;
          final actualTarget = availableCount > 0
              ? (availableCount > 10 ? 10 : availableCount)
              : (challenge.targetCount > 0 ? challenge.targetCount : 1);

          debugPrint('Challenge available questions: $availableCount');
          debugPrint('Challenge questions loaded: $actualTarget');
          debugPrint('Current index: ${challenge.currentCount}');
          debugPrint('Total questions: $actualTarget');

          if (challenge.targetCount != actualTarget) {
            final updatedChallenge = challenge.copyWith(targetCount: actualTarget);
            await _challengeService.updateTargetCount(
              challengeId: challenge.id,
              targetCount: actualTarget,
            );
            syncedChallenges.add(updatedChallenge);
            continue;
          }
        } catch (e) {
          debugPrint('Error checking question count for challenge: $e');
        }
      }
      syncedChallenges.add(challenge);
    }

    return syncedChallenges;
  }

  /// Refresh today's challenges.
  Future<void> _refreshChallenges() async {
    if (widget.initialChallenges != null) {
      setState(() {
        _challengesFuture = Future.value(widget.initialChallenges);
      });
      return;
    }

    setState(() {
      _loadChallenges();
    });

    await _challengesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Challenges',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _refreshChallenges,
        child: FutureBuilder<List<Challenge>>(
          future: _challengesFuture,
          builder: (context, snapshot) {
            // ------------------------------------------
            // LOADING
            // ------------------------------------------

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // ------------------------------------------
            // ERROR
            // ------------------------------------------

            if (snapshot.hasError) {
              return _ErrorState(
                error: snapshot.error.toString(),
                onRetry: _refreshChallenges,
              );
            }

            // ------------------------------------------
            // DATA
            // ------------------------------------------

            final challenges = snapshot.data ?? [];

            // ------------------------------------------
            // EMPTY
            // ------------------------------------------

            if (challenges.isEmpty) {
              return const _EmptyChallengeState();
            }

            // ------------------------------------------
            // CHALLENGES
            // ------------------------------------------

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const _ChallengeHeader(),

                const SizedBox(height: AppSpacing.lg),

                ...challenges.map(
                  (challenge) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ChallengeCard(
                      challenge: challenge,
                      stream: _studentStream,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// CHALLENGE HEADER
// ============================================================

class _ChallengeHeader extends StatelessWidget {
  const _ChallengeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: Colors.white, size: 42),

          SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Challenges",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Small goals. Real progress.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CHALLENGE CARD
// ============================================================

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final String stream;

  const _ChallengeCard({
    required this.challenge,
    this.stream = 'natural',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final target = challenge.targetCount;

    final progress = target <= 0
        ? 0.0
        : (challenge.currentCount / target).clamp(0.0, 1.0);

    final isCompleted = challenge.isCompleted;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              // ignore: deprecated_member_use
              ? AppColors.success.withOpacity(0.35)
              : colors.border,
        ),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --------------------------------------------------
          // TITLE + ICON
          // --------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: isCompleted
                      // ignore: deprecated_member_use
                      ? AppColors.success.withOpacity(0.10)
                      // ignore: deprecated_member_use
                      : AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.flag_rounded,
                  color: isCompleted ? AppColors.success : AppColors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      challenge.description,
                      style: TextStyle(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // --------------------------------------------------
          // PROGRESS NUMBERS
          // --------------------------------------------------
          Row(
            children: [
              Text(
                '${challenge.currentCount} / ${challenge.targetCount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),

              const Spacer(),

              Text(
                isCompleted ? 'Completed' : 'In progress',
                style: TextStyle(
                  color: isCompleted
                      ? AppColors.success
                      : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // --------------------------------------------------
          // PROGRESS BAR
          // --------------------------------------------------
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? AppColors.success : AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // --------------------------------------------------
          // XP
          // --------------------------------------------------
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: AppColors.warning,
              ),

              const SizedBox(width: 7),

              Text(
                '+${challenge.rewardXp} XP',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),

              const Spacer(),

              if (isCompleted)
                Text(
                  '🎉 Great job!',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: isCompleted
                  ? null
                  : () async {
                      final hasAccess = await AccessService.canAccessChallenges();
                      if (!hasAccess) {
                        if (!context.mounted) return;
                        AccessLockedDialog.show(context, featureName: 'Challenges');
                        return;
                      }

                      // Required debug logs from Part 9
                      debugPrint('=== CHALLENGE START ===');
                      debugPrint('Challenge title: ${challenge.title}');
                      debugPrint('Grade: ${challenge.grade}');
                      debugPrint('Subject: ${challenge.subject}');
                      debugPrint('Unit number: ${challenge.unitNumber}');
                      debugPrint('Unit name: ${challenge.unitName}');
                      debugPrint('Target count: ${challenge.targetCount}');
                      debugPrint('=======================');

                      final normalizedStream = QuestionService.normalizeStream(
                        stream,
                        subject: challenge.subject,
                      );

                      final count = challenge.targetCount > 0 ? challenge.targetCount : 1;

                      if (!context.mounted) return;
                      context.push(

                        '/practice'
                        '?grade=${Uri.encodeComponent(challenge.grade)}'
                        '&stream=${Uri.encodeComponent(normalizedStream)}'
                        '&subject=${Uri.encodeComponent(challenge.subject)}'
                        '&unitNumber=${challenge.unitNumber}'
                        '&unitName=${Uri.encodeComponent(challenge.unitName)}'
                        '&questionCount=$count',
                        extra: {
                          'grade': challenge.grade,
                          'stream': normalizedStream,
                          'subject': challenge.subject,
                          'unitNumber': challenge.unitNumber,
                          'unitName': challenge.unitName,
                          'questionCount': count,
                        },
                      );
                    },
              icon: Icon(
                isCompleted ? Icons.check_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                isCompleted ? 'Challenge Completed' : 'Start Challenge',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyChallengeState extends StatelessWidget {
  const _EmptyChallengeState();

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: 70),

        Icon(
          Icons.emoji_events_outlined,
          size: 80,
          color: colors.textSecondary.withValues(alpha: 0.5),
        ),

        const SizedBox(height: 20),

        Text(
          'No challenges today',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),

        const SizedBox(height: 8),

        Text(
          'Keep practicing and EduRise will create a challenge for you.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 15),
        ),
      ],
    );
  }
}

// ============================================================
// ERROR STATE
// ============================================================

class _ErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: AppColors.error,
              ),

              const SizedBox(height: 16),

              Text(
                'Challenge Loading Error',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  error,
                  style: TextStyle(fontSize: 13, height: 1.5, color: colors.textSecondary),
                ),
              ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
