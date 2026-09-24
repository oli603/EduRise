import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../coach/data/coach_service.dart';
import '../data/book_model.dart';
import '../data/book_text_service.dart';

class UnitAiNotesScreen extends StatefulWidget {
  final BookUnit unit;

  const UnitAiNotesScreen({super.key, required this.unit});

  @override
  State<UnitAiNotesScreen> createState() => _UnitAiNotesScreenState();
}

class _UnitAiNotesScreenState extends State<UnitAiNotesScreen> {
  final CoachService _coachService = CoachService.instance;
  final BookTextService _textService = BookTextService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final textResult = await _textService.getUnitText(widget.unit);
      final contextWindow = textResult.hasUsableText
          ? _textService.prepareContextWindow(textResult.text)
          : null;

      final res = await _coachService.getUnitAiNotes(
        bookId: widget.unit.id,
        unitId: 'unit_${widget.unit.unitNumber}',
        unitTitle: widget.unit.unitName,
        subject: widget.unit.subject,
        grade: widget.unit.grade,
        unitNumber: widget.unit.unitNumber,
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

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final isCached = _data?['cached'] == true;

    final colors = context.eduColors;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Unit ${unit.unitNumber} AI Notes'),
        actions: [
          if (isCached)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OFFLINE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.textSecondary),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Regenerate',
            onPressed: () => _loadNotes(forceRefresh: true),
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
              'Compiling In-Depth Study Notes...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.eduColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Synthesizing textbook curriculum and exam patterns',
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
                onPressed: () => _loadNotes(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data ?? {};
    var rawSections = (data['sections'] as List<dynamic>?) ?? [];
    if (rawSections.isEmpty) {
      final concepts = (data['key_concepts'] as List<dynamic>?) ?? [];
      final procs = (data['important_processes'] as List<dynamic>?) ?? [];
      final comps = (data['comparisons'] as List<dynamic>?) ?? [];
      final confs = (data['common_confusions'] as List<dynamic>?) ?? [];

      final synth = <Map<String, dynamic>>[];
      if (concepts.isNotEmpty) {
        synth.add({
          'title': 'Core Concepts & Principles',
          'content': 'Fundamental curriculum foundation for ${widget.unit.unitName}.',
          'key_points': concepts,
        });
      }
      if (procs.isNotEmpty) {
        synth.add({
          'title': 'Key Processes & Mechanisms',
          'content': 'Sequential operational transformations and principles.',
          'key_points': procs,
        });
      }
      if (comps.isNotEmpty) {
        synth.add({
          'title': 'Critical Distinctions & Comparisons',
          'content': 'Comparing and contrasting essential components.',
          'key_points': comps.map((c) => c is Map ? '${c['comparison']}: ${c['distinction'] ?? ''}' : c.toString()).toList(),
        });
      }
      if (confs.isNotEmpty) {
        synth.add({
          'title': 'Common Confusions to Avoid',
          'content': 'Frequent student pitfalls on exam questions.',
          'key_points': confs,
        });
      }
      rawSections = synth;
    }
    final sections = rawSections;

    final rawTerms = data['key_terms'] ?? data['definitions'];
    final List<dynamic> keyTerms = (rawTerms is List) ? rawTerms : [];
    final formulas = (data['formulas_or_rules'] as List<dynamic>?) ?? [];
    final rawTips = data['exam_tips'] ?? data['exam_focused_points'];
    final List<dynamic> tips = (rawTips is List) ? rawTips : [];

    final colors = context.eduColors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit ${widget.unit.unitNumber}: ${widget.unit.unitName}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Comprehensive revision notes aligned with MOE standards',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Topic Sections
        ...sections.map((sec) {
          final s = Map<String, dynamic>.from(sec as Map);
          final title = s['title'] as String? ?? '';
          final content = s['content'] as String? ?? '';
          final subpoints = (s['key_points'] as List<dynamic>?) ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(fontSize: 14, height: 1.5, color: colors.textPrimary),
                ),
                if (subpoints.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...subpoints.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                            Expanded(
                              child: Text(
                                p.toString(),
                                style: TextStyle(fontSize: 13, height: 1.4, color: colors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          );
        }),

        // Key Terms & Definitions
        if (keyTerms.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSectionHeader(Icons.menu_book_rounded, 'Key Definitions & Terms'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: keyTerms.map((t) {
                final termMap = Map<String, dynamic>.from(t as Map);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          termMap['term']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          termMap['definition']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Formulas or Key Rules
        if (formulas.isNotEmpty) ...[
          _buildSectionHeader(Icons.functions_rounded, 'Essential Formulas & Rules'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Column(
              children: formulas.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded, size: 18, color: Colors.teal.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Exam Tips
        if (tips.isNotEmpty) ...[
          _buildSectionHeader(Icons.lightbulb_outline_rounded, 'Exam Strategy Tips'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: colors.isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: colors.isDark ? 0.35 : 0.25),
              ),
            ),
            child: Column(
              children: tips.map((tip) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: colors.isDark ? const Color(0xFFFBBF24) : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: colors.isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900,
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

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.eduColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
