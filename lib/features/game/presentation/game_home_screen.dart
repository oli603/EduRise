import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/download_manager.dart';
import '../../../core/offline/offline_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../past_entrance_exams/data/past_exam_service.dart';
import '../data/game_service.dart';
import '../data/models/game_models.dart';

class GameHomeScreen extends StatefulWidget {
  final GameService? gameService;
  final OfflineStorageService? storageService;

  const GameHomeScreen({
    super.key,
    this.gameService,
    this.storageService,
  });

  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen> {
  late final GameService _gameService;
  late final OfflineStorageService _storage;
  final PastExamService _pastExamService = PastExamService();
  StreamSubscription<String>? _downloadStatusSubscription;

  String _stream = 'natural';
  String _grade = 'Grade 12';
  String? _selectedSubject;
  bool _isLoading = true;

  final Map<String, int> _subjectQuestionCounts = {};
  GameProgressSummary? _currentProgress;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageService ?? OfflineStorageService.instance;
    _gameService = widget.gameService ?? GameService(storageService: _storage);

    _loadStudentProfileAndData();

    _downloadStatusSubscription = DownloadManager().onStatusChanged.listen((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _downloadStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStudentProfileAndData() async {
    try {
      final info = await _pastExamService
          .getStudentAcademicInfo()
          .timeout(const Duration(seconds: 2), onTimeout: () => {'grade': 'Grade 12', 'stream': 'Natural Science'});
      _grade = info['grade'] ?? 'Grade 12';
      final rawStream = (info['stream'] ?? 'natural').toString().toLowerCase();
      _stream = rawStream.contains('social') ? 'social' : 'natural';
    } catch (_) {
      _stream = 'natural';
    }


    final subjects = _gameService.getAvailableSubjectsForStream(_stream);
    if (subjects.isNotEmpty && _selectedSubject == null) {
      _selectedSubject = subjects.first;
    }

    await _refreshData();
  }

  Future<void> _refreshData() async {
    final subjects = _gameService.getAvailableSubjectsForStream(_stream);
    final counts = <String, int>{};

    for (final sub in subjects) {
      final count = await _gameService.getSubjectQuestionCount(
        stream: _stream,
        subject: sub,
      );
      counts[sub] = count;
    }

    if (_selectedSubject == null && subjects.isNotEmpty) {
      _selectedSubject = subjects.first;
    }

    GameProgressSummary? progress;
    if (_selectedSubject != null) {
      progress = await _gameService.getGameProgress(
        stream: _stream,
        subject: _selectedSubject!,
      );
    }

    if (mounted) {
      setState(() {
        _subjectQuestionCounts.addAll(counts);
        _currentProgress = progress;
        _isLoading = false;
      });
    }
  }

  Future<void> _onSubjectSelected(String subject) async {
    setState(() {
      _selectedSubject = subject;
      _isLoading = true;
    });

    final progress = await _gameService.getGameProgress(
      stream: _stream,
      subject: subject,
    );

    if (mounted) {
      setState(() {
        _currentProgress = progress;
        _isLoading = false;
      });
    }
  }

  void _startLevel(int levelNumber) {
    if (_selectedSubject == null) return;
    context.push(
      '/game/play?subject=${Uri.encodeComponent(_selectedSubject!)}&stream=${Uri.encodeComponent(_stream)}&level=$levelNumber',
    ).then((_) {
      if (mounted) _refreshData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _gameService.getAvailableSubjectsForStream(_stream);
    final totalStars = _currentProgress?.totalStarsEarned ?? 0;
    final currentQCount = _selectedSubject != null ? (_subjectQuestionCounts[_selectedSubject!] ?? 0) : 0;
    final hasEnoughQuestions = currentQCount >= 5;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. GAME HERO BANNER
              // ==========================================
              _buildHeroBanner(totalStars),

              const SizedBox(height: AppSpacing.lg),

              // ==========================================
              // 2. SUBJECT SELECTOR CHIPS
              // ==========================================
              Text(
                'Choose Subject',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.eduColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildSubjectChips(subjects),

              const SizedBox(height: AppSpacing.lg),

              // ==========================================
              // 3. LEVELS SECTION / EMPTY STATE
              // ==========================================
              if (!hasEnoughQuestions)
                _buildInsufficientQuestionsCard()
              else ...[
                _buildLevelHeader(),
                const SizedBox(height: 12),
                _buildLevelsGrid(),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(int totalStars) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_grade • ${_stream.contains('social') ? 'Social Science' : 'Natural Science'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 4),
                  Text(
                    '$totalStars Stars',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'EduRise Game',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Master Your Subjects • One Level at a Time! 🎯',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '5 quick questions per level. Score 3+ to earn stars and unlock the next challenge!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChips(List<String> subjects) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final subject = subjects[index];
          final isSelected = subject == _selectedSubject;
          final count = _subjectQuestionCounts[subject] ?? 0;

          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(subject),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            selected: isSelected,
            selectedColor: AppColors.primary.withValues(alpha: 0.12),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            onSelected: (selected) {
              if (selected && subject != _selectedSubject) {
                _onSubjectSelected(subject);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildInsufficientQuestionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.eduColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.eduColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_for_offline_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Download Practice Content for $_selectedSubject',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.eduColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'EduRise Game uses trusted offline practice questions. Download Practice Units for this subject to unlock all levels offline.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.eduColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Go to Practice Downloads'),
            onPressed: () {
              context.push('/practice');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLevelHeader() {
    final highestUnlocked = _currentProgress?.highestUnlockedLevel ?? 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_selectedSubject Levels',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.eduColors.textPrimary,
              ),
            ),
            Text(
              '${_currentProgress?.totalLevelsPassed ?? 0} levels completed',
              style: TextStyle(
                fontSize: 13,
                color: context.eduColors.textSecondary,
              ),
            ),
          ],
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text('Play Level $highestUnlocked'),
          onPressed: () => _startLevel(highestUnlocked),
        ),
      ],
    );
  }

  Widget _buildLevelsGrid() {
    // Generate up to 10 levels (or more as unlocked)
    final highestUnlocked = _currentProgress?.highestUnlockedLevel ?? 1;
    final totalLevelsToShow = (highestUnlocked + 4).clamp(10, 50);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.25,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: totalLevelsToShow,
      itemBuilder: (context, index) {
        final levelNum = index + 1;
        final record = _currentProgress?.getLevel(levelNum) ??
            GameLevelRecord(
              levelNumber: levelNum,
              isUnlocked: levelNum == 1,
            );

        return _buildLevelCard(record);
      },
    );
  }

  Widget _buildLevelCard(GameLevelRecord record) {
    final isUnlocked = record.isUnlocked;
    final isPassed = record.isPassed;
    final stars = record.bestStars;
    final isDark = context.eduColors.isDark;

    Color borderColor;
    Color bgColor;
    if (isPassed) {
      borderColor = AppColors.success.withValues(alpha: isDark ? 0.5 : 0.4);
      bgColor = isDark
          ? AppColors.success.withValues(alpha: 0.12)
          : AppColors.success.withValues(alpha: 0.05);
    } else if (isUnlocked) {
      borderColor = AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.4);
      bgColor = isDark
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.primary.withValues(alpha: 0.05);
    } else {
      borderColor = context.eduColors.border;
      bgColor = context.eduColors.surfaceSubtle;
    }

    return InkWell(
      onTap: isUnlocked
          ? () => _startLevel(record.levelNumber)
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Complete Level ${record.levelNumber - 1} with 3+ correct answers to unlock Level ${record.levelNumber}!',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isUnlocked ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level ${record.levelNumber}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? context.eduColors.textPrimary : context.eduColors.textSecondary,
                  ),
                ),
                if (!isUnlocked)
                  Icon(Icons.lock_rounded, size: 18, color: context.eduColors.textMuted)
                else if (isPassed)
                  const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success)
                else
                  const Icon(Icons.play_circle_fill_rounded, size: 20, color: AppColors.primary),
              ],
            ),
            // Stars row
            Row(
              children: List.generate(3, (starIndex) {
                final isEarned = starIndex < stars;
                return Icon(
                  isEarned ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: isEarned
                      ? Colors.amber
                      : (isUnlocked ? context.eduColors.border : context.eduColors.border.withValues(alpha: 0.5)),
                );
              }),
            ),
            // Best score or status footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPassed
                      ? 'Best: ${record.bestScore}/5'
                      : (isUnlocked ? '5 Questions' : 'Locked'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPassed
                        ? AppColors.success
                        : (isUnlocked ? context.eduColors.textSecondary : context.eduColors.textMuted),
                  ),
                ),
                if (isUnlocked)
                  Text(
                    isPassed ? 'Replay' : 'Start',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPassed ? context.eduColors.textSecondary : AppColors.primary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
