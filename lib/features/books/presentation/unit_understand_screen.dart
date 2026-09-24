import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../coach/data/coach_service.dart';
import '../data/book_model.dart';
import '../data/book_text_service.dart';

class UnitUnderstandScreen extends StatefulWidget {
  final BookUnit unit;

  const UnitUnderstandScreen({super.key, required this.unit});

  @override
  State<UnitUnderstandScreen> createState() => _UnitUnderstandScreenState();
}

class _UnitUnderstandScreenState extends State<UnitUnderstandScreen> {
  final CoachService _coachService = CoachService.instance;
  final BookTextService _textService = BookTextService();
  final TextEditingController _conceptController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;
  String? _currentConceptFilter;

  @override
  void initState() {
    super.initState();
    _loadExplanation();
  }

  @override
  void dispose() {
    _conceptController.dispose();
    super.dispose();
  }

  Future<void> _loadExplanation({String? specificConcept, bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentConceptFilter = specificConcept;
    });

    try {
      final textResult = await _textService.getUnitText(widget.unit);
      final contextWindow = textResult.hasUsableText
          ? _textService.prepareContextWindow(textResult.text)
          : null;

      final res = await _coachService.getUnitUnderstand(
        bookId: widget.unit.id,
        unitId: 'unit_${widget.unit.unitNumber}',
        unitTitle: widget.unit.unitName,
        subject: widget.unit.subject,
        grade: widget.unit.grade,
        unitNumber: widget.unit.unitNumber,
        specificConcept: specificConcept,
        unitContent: contextWindow,
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
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchConcept() {
    final text = _conceptController.text.trim();
    if (text.isNotEmpty) {
      _loadExplanation(specificConcept: text, forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCached = _data?['cached'] == true;

    return Scaffold(
      backgroundColor: context.eduColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Understand This Unit'),
        actions: [
          if (isCached)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.eduColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.eduColors.border),
                  ),
                  child: Text(
                    'OFFLINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.eduColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Regenerate',
            onPressed: () => _loadExplanation(
              specificConcept: _currentConceptFilter,
              forceRefresh: true,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Simplifying Unit Concepts...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.eduColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Translating complex curriculum into intuitive teacher breakdowns',
              style: TextStyle(color: context.eduColors.textSecondary, fontSize: 13),
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
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadExplanation(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data ?? {};
    final bigIdea = (data['big_idea_in_plain_english'] ?? data['unit_overview'] ?? '').toString();
    final analogy = (data['real_life_analogy'] ??
        (data['analogies_and_examples'] is List && (data['analogies_and_examples'] as List).isNotEmpty
            ? (data['analogies_and_examples'] as List)[0]
            : '')).toString();
    final steps = (data['step_by_step_breakdown'] as List<dynamic>?) ??
        (data['main_ideas_simplified'] as List<dynamic>?) ?? [];
    final checks = (data['quick_self_check_questions'] as List<dynamic>?) ??
        (data['common_pitfalls'] as List<dynamic>?) ?? [];

    final colors = context.eduColors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Ask specific concept input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confused by a specific topic in this unit?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _conceptController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Photosynthesis light reactions, Gauss Law...',
                        hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        isDense: true,
                        filled: true,
                        fillColor: colors.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _onSearchConcept(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _onSearchConcept,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: const Text('Explain'),
                  ),
                ],
              ),
              if (_currentConceptFilter != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Showing topic: "$_currentConceptFilter"',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        _conceptController.clear();
                        _loadExplanation(forceRefresh: true);
                      },
                      child: const Text(
                        'Clear filter',
                        style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Step 1: Big Idea
        _buildTeacherStepCard(
          stepNumber: 1,
          icon: Icons.lightbulb_rounded,
          title: 'The Big Idea in Plain English',
          color: Colors.blue,
          content: bigIdea,
        ),

        const SizedBox(height: 16),

        // Step 2: Real Life Analogy
        _buildTeacherStepCard(
          stepNumber: 2,
          icon: Icons.auto_awesome_rounded,
          title: 'Real-Life Analogy',
          color: Colors.purple,
          content: analogy,
        ),

        const SizedBox(height: 16),

        // Step 3: Step-by-Step Breakdown
        _buildSectionHeader(Icons.format_list_numbered_rounded, 'Step 3: Step-by-Step Breakdown'),
        const SizedBox(height: 10),

        ...steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final st = entry.value;
          final stNum = (st is Map ? st['step'] : null) ?? '${idx + 1}';
          final stTitle = (st is Map ? st['title'] : null) ?? 'Step ${idx + 1}';
          final stExp = (st is Map ? st['explanation'] : null) ?? st.toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        stNum.toString(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stTitle.toString(),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    stExp.toString(),
                    style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 10),

        // Step 4: Quick Self-Check
        if (checks.isNotEmpty) ...[
          _buildSectionHeader(Icons.quiz_rounded, 'Step 4: Quick Self-Check'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: checks.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.help_outline_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildTeacherStepCard({
    required int stepNumber,
    required IconData icon,
    required String title,
    required MaterialColor color,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.shade800, size: 22),
              const SizedBox(width: 8),
              Text(
                'Step $stepNumber: $title',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
