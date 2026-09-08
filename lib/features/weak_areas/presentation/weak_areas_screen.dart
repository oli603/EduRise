import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
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
    if (weakAreas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph_rounded, size: 60),

              SizedBox(height: 16),

              Text(
                "No weak areas yet 🎉",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 8),

              Text(
                "Complete some practice questions "
                "and EduRise will identify where "
                "you need more practice.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          "Know your gaps. Build your confidence.",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: AppSpacing.sm),

        Text(
          "Focus on the topics where you need "
          "the most practice.",
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),

        const SizedBox(height: 28),

        ...weakAreas.map((area) => _buildWeakArea(context, area)),
      ],
    );
  }

  Widget _buildWeakArea(BuildContext context, WeakArea area) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.04),
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
                  // ignore: deprecated_member_use
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: AppColors.primary,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
            borderRadius: BorderRadius.circular(10),
          ),

          const SizedBox(height: 10),

          Text(
            "${area.correctAnswers} correct "
            "out of ${area.totalQuestions}",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
