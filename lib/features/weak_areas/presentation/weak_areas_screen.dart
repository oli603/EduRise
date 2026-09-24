import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/weak_areas_service.dart';

class WeakAreasScreen extends StatefulWidget {
  final WeakAreasService? weakAreasService;
  final List<WeakArea>? initialWeakAreas;

  const WeakAreasScreen({
    super.key,
    this.weakAreasService,
    this.initialWeakAreas,
  });

  @override
  State<WeakAreasScreen> createState() => _WeakAreasScreenState();
}

class _WeakAreasScreenState extends State<WeakAreasScreen> {
  late final WeakAreasService _weakAreasService;
  late Future<List<WeakArea>> _weakAreasFuture;

  @override
  void initState() {
    super.initState();
    _weakAreasService = widget.weakAreasService ?? WeakAreasService();
    if (widget.initialWeakAreas != null) {
      _weakAreasFuture = Future.value(widget.initialWeakAreas);
    } else {
      _weakAreasFuture = _weakAreasService.getWeakAreas();
    }
  }

  void _refresh() {
    setState(() {
      _weakAreasFuture = _weakAreasService.getWeakAreas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Weak Areas"),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<WeakArea>>(
        future: _weakAreasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 50),

                    const SizedBox(height: 16),

                    const Text(
                      "Unable to load your weak areas.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text("Try Again"),
                    ),
                  ],
                ),
              ),
            );
          }

          final weakAreas = snapshot.data ?? [];

          return _buildContent(context, weakAreas);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<WeakArea> weakAreas) {
    final colors = context.eduColors;

    if (weakAreas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph_rounded, size: 60, color: colors.textSecondary),

              const SizedBox(height: 16),

              Text(
                "No weak areas yet 🎉",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Complete some practice questions and EduRise will identify where you need more practice.",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          "Know your gaps. Build your confidence.",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        Text(
          "Focus on the topics where you need the most practice.",
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),

        const SizedBox(height: 28),

        ...weakAreas.map((area) => _buildWeakArea(context, area)),
      ],
    );
  }

  Widget _buildWeakArea(BuildContext context, WeakArea area) {
    final colors = context.eduColors;
    final primaryAccent = colors.isDark ? AppColors.primaryForDark : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: primaryAccent,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                "${area.accuracy}%",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getAccuracyColor(area.accuracy),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          LinearProgressIndicator(
            value: area.accuracy / 100,
            minHeight: 7,
            backgroundColor: colors.border,
            borderRadius: BorderRadius.circular(10),
            valueColor: AlwaysStoppedAnimation<Color>(_getAccuracyColor(area.accuracy)),
          ),

          const SizedBox(height: 10),

          Text(
            "${area.correctAnswers} correct out of ${area.totalQuestions}",
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.push(
                  '/practice',
                  extra: {
                    'grade': area.grade.isNotEmpty ? area.grade : 'Grade 11',
                    'stream': area.stream ?? 'Natural Science',
                    'subject': area.subject,
                    'unitNumber': area.unitNumber,
                    'unitName': area.unitName,
                    'questionCount': 10,
                  },
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("Practice This Area"),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy < 50) {
      return Colors.red;
    }

    if (accuracy < 70) {
      return Colors.orange;
    }

    return Colors.green;
  }
}
