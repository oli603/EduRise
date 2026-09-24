import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/coach_service.dart';

class ExplainMoreSheet extends StatefulWidget {
  final String questionId;
  final String questionText;
  final Map<String, String> options;
  final String correctAnswer;
  final String? subject;
  final String? grade;
  final int? unitNumber;
  final String? examYear;

  const ExplainMoreSheet({
    super.key,
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.subject,
    this.grade,
    this.unitNumber,
    this.examYear,
  });

  static Future<void> show(
    BuildContext context, {
    required String questionId,
    required String questionText,
    required Map<String, String> options,
    required String correctAnswer,
    String? subject,
    String? grade,
    int? unitNumber,
    String? examYear,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExplainMoreSheet(
        questionId: questionId,
        questionText: questionText,
        options: options,
        correctAnswer: correctAnswer,
        subject: subject,
        grade: grade,
        unitNumber: unitNumber,
        examYear: examYear,
      ),
    );
  }

  @override
  State<ExplainMoreSheet> createState() => _ExplainMoreSheetState();
}

class _ExplainMoreSheetState extends State<ExplainMoreSheet> {
  final CoachService _coachService = CoachService.instance;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _coachService.explainQuestion(
        questionId: widget.questionId,
        questionText: widget.questionText,
        options: widget.options,
        correctAnswer: widget.correctAnswer,
        subject: widget.subject,
        grade: widget.grade,
        unitNumber: widget.unitNumber,
        examYear: widget.examYear,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCached = _data?['cached'] == true;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: context.eduColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: context.eduColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AI Deep Explanation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.eduColors.textPrimary,
                            ),
                          ),
                          if (isCached) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.eduColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'OFFLINE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: context.eduColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Why (${widget.correctAnswer}) is correct & why others are wrong',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.eduColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.eduColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.eduColors.border),

          // Content body
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Generating comprehensive breakdown...',
              style: TextStyle(color: context.eduColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Analyzing curriculum concepts & distractors',
              style: TextStyle(color: context.eduColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.eduColors.textPrimary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _fetchExplanation(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

    final data = _data ?? {};
    final coreConcept = data['core_concept'] as String? ?? '';
    final whyCorrect = data['why_correct'] as String? ?? '';
    final keyTakeaway = data['key_takeaway'] as String? ?? '';
    final commonTrap = data['common_trap'] as String? ?? '';
    final optionsBreakdown = data['options_breakdown'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Core Concept Banner
        if (coreConcept.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Core Concept',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coreConcept,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.eduColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Correct Option Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      widget.correctAnswer,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Why This is the Correct Answer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                whyCorrect.isNotEmpty ? whyCorrect : 'This is the verified correct answer in the Ethiopian national curriculum.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.eduColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Why Other Options Are Wrong Section
        Text(
          'Analysis of All Options',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.eduColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        ...widget.options.entries.map((entry) {
          final optKey = entry.key.toUpperCase();
          final optVal = entry.value;
          final isCorrect = optKey == widget.correctAnswer.toUpperCase();
          final analysis = optionsBreakdown[optKey] ??
              (isCorrect
                  ? whyCorrect
                  : 'This option does not satisfy the requirements of the concept.');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCorrect
                  ? AppColors.success.withValues(alpha: 0.06)
                  : context.eduColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorrect
                    ? AppColors.success.withValues(alpha: 0.35)
                    : context.eduColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCorrect ? AppColors.success : context.eduColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        optKey,
                        style: TextStyle(
                          color: isCorrect ? Colors.white : context.eduColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        optVal,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.eduColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                    else
                      const Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    analysis.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isCorrect ? context.eduColors.textPrimary : context.eduColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        if (commonTrap.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Common Exam Trap',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        commonTrap,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: context.eduColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        if (keyTakeaway.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Key Takeaway',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        keyTakeaway,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: context.eduColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }
}
