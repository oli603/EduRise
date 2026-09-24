import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../coach/data/coach_service.dart';
import '../data/book_model.dart';
import '../data/book_text_service.dart';

class UnitSummaryScreen extends StatefulWidget {
  final BookUnit unit;

  const UnitSummaryScreen({super.key, required this.unit});

  @override
  State<UnitSummaryScreen> createState() => _UnitSummaryScreenState();
}

class _UnitSummaryScreenState extends State<UnitSummaryScreen> {
  final CoachService _coachService = CoachService.instance;
  final BookTextService _textService = BookTextService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;
  bool _isScannedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isScannedOnly = false;
    });

    try {
      final textResult = await _textService.getUnitText(widget.unit);
      if (textResult.isScannedOnly) {
        _isScannedOnly = true;
      }

      final contextWindow = textResult.hasUsableText
          ? _textService.prepareContextWindow(textResult.text)
          : null;

      final res = await _coachService.getUnitSummary(
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
        title: Text('Unit ${unit.unitNumber} Summary'),
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
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Regenerate',
            onPressed: () => _loadSummary(forceRefresh: true),
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
              'Generating Unit Summary...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.eduColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Extracting core concepts and entrance exam highlights',
              style: TextStyle(
                color: context.eduColors.textSecondary,
                fontSize: 13,
              ),
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
                onPressed: () => _loadSummary(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data ?? {};
    final overview = data['overview'] as String? ?? '';
    final rawConcepts = data['key_concepts'] ?? data['important_terms'] ?? data['key_points'];
    final List<String> keyConcepts = [];
    if (rawConcepts is List) {
      for (final item in rawConcepts) {
        if (item is Map && item.containsKey('term')) {
          keyConcepts.add('${item['term']}: ${item['definition'] ?? ''}');
        } else if (item != null) {
          keyConcepts.add(item.toString());
        }
      }
    }

    final rawBullet = data['bullet_points'] ?? data['key_points'];
    final List<String> bulletPoints = [];
    if (rawBullet is List) {
      for (final item in rawBullet) {
        if (item != null) bulletPoints.add(item.toString());
      }
    }

    final examImportance = (data['exam_importance'] ?? data['summary_recap'] ?? '').toString();

    final colors = context.eduColors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_isScannedOnly)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: colors.isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: colors.isDark ? 0.35 : 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colors.isDark ? const Color(0xFFFBBF24) : Colors.amber.shade900,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Note: This unit contains scanned images. Summary is synthesized from curriculum syllabus standards.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Unit Header Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.85),
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
              Text(
                '${widget.unit.subject} • ${widget.unit.grade}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Unit ${widget.unit.unitNumber}: ${widget.unit.unitName}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Overview Section
        if (overview.isNotEmpty) ...[
          _buildSectionHeader(Icons.article_rounded, 'Unit Overview'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              overview,
              style: TextStyle(fontSize: 14, height: 1.6, color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Key Concepts
        if (keyConcepts.isNotEmpty) ...[
          _buildSectionHeader(Icons.lightbulb_rounded, 'Core Concepts & Principles'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: keyConcepts.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.toString(),
                          style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500, color: colors.textPrimary),
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

        // Fast Bulleted Takeaways
        if (bulletPoints.isNotEmpty) ...[
          _buildSectionHeader(Icons.checklist_rounded, 'Quick Revision Takeaways'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: bulletPoints.map((bp) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bp.toString(),
                          style: TextStyle(fontSize: 14, height: 1.4, color: colors.textPrimary),
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

        // Entrance Exam Relevance
        if (examImportance.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: colors.isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: colors.isDark ? 0.35 : 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: colors.isDark ? const Color(0xFFFBBF24) : Colors.amber.shade900,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'National Exam Importance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.isDark ? const Color(0xFFFBBF24) : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        examImportance,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colors.isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
