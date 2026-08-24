import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/challenge_generator.dart';
import '../data/challenge_model.dart';
import '../data/challenge_service.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final ChallengeGenerator _challengeGenerator = ChallengeGenerator();

  late Future<List<Challenge>> _challengesFuture;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
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

    return challenges;
  }

  /// Refresh today's challenges.
  Future<void> _refreshChallenges() async {
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
                    child: _ChallengeCard(challenge: challenge),
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

  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final target = challenge.targetCount;

    final progress = target <= 0
        ? 0.0
        : (challenge.currentCount / target).clamp(0.0, 1.0);

    final isCompleted = challenge.isCompleted;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              // ignore: deprecated_member_use
              ? AppColors.success.withOpacity(0.35)
              : AppColors.border,
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      challenge.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              Text(
                isCompleted ? 'Completed' : 'In progress',
                style: TextStyle(
                  color: isCompleted
                      ? AppColors.success
                      : AppColors.textSecondary,
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
              backgroundColor: AppColors.border,
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
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),

              const Spacer(),

              if (isCompleted)
                const Text(
                  '🎉 Great job!',
                  style: TextStyle(fontWeight: FontWeight.w700),
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
                  : () {
                      context.push(
                        '/practice'
                        '?grade=${Uri.encodeComponent(challenge.grade)}'
                        '&subject=${Uri.encodeComponent(challenge.subject)}'
                        '&unitNumber=0'
                        '&unitName=${Uri.encodeComponent(challenge.title)}'
                        '&questionCount=${challenge.targetCount}',
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

          // --------------------------------------------------
          // START BUTTON
          // --------------------------------------------------
          if (!isCompleted) ...[
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  // We will connect this to Practice next.
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Challenge'),
              ),
            ),
          ],
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: 70),

        Icon(
          Icons.emoji_events_outlined,
          size: 80,
          color: Colors.grey.shade400,
        ),

        const SizedBox(height: 20),

        const Text(
          'No challenges today',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          'Keep practicing and EduRise will create a challenge for you.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
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

              const Text(
                'Challenge Loading Error',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  error,
                  style: const TextStyle(fontSize: 13, height: 1.5),
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
