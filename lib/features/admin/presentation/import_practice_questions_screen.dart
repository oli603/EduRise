import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/import/practice_bulk_import_models.dart';
import '../data/import/practice_bulk_import_service.dart';

class ImportPracticeQuestionsScreen extends StatefulWidget {
  const ImportPracticeQuestionsScreen({super.key});

  @override
  State<ImportPracticeQuestionsScreen> createState() =>
      _ImportPracticeQuestionsScreenState();
}

class _ImportPracticeQuestionsScreenState
    extends State<ImportPracticeQuestionsScreen> {
  final PracticeBulkImportService _importService = PracticeBulkImportService();

  final List<QueuedImportFile> _files = [];
  bool _isValidating = false;
  bool _hasValidated = false;
  bool _isImporting = false;
  double _importProgress = 0.0;
  int _importedCount = 0;
  int _totalToImport = 0;

  BulkImportResult? _lastResult;
  BulkImportResult? get lastResult => _lastResult;
  String _tableFilter = 'all'; // all, valid, needsReview, invalid
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Summary computed properties
  int get _totalQuestions =>
      _files.fold(0, (sum, f) => sum + f.totalQuestionsCount);
  int get _validQuestions =>
      _files.fold(0, (sum, f) => sum + f.validRowsCount);
  int get _needsReviewQuestions =>
      _files.fold(0, (sum, f) => sum + f.needsReviewRowsCount);
  int get _invalidQuestions =>
      _files.fold(0, (sum, f) => sum + f.invalidRowsCount);

  List<PracticeImportRow> get _allRows =>
      _files.expand((f) => f.practiceRows).toList();

  List<PracticeImportRow> get _filteredRows {
    var list = _allRows;
    if (_tableFilter == 'valid') {
      list = list.where((r) => r.isValid && !r.needsReview).toList();
    } else if (_tableFilter == 'needsReview') {
      list = list.where((r) => r.isValid && r.needsReview).toList();
    } else if (_tableFilter == 'invalid') {
      list = list.where((r) => !r.isValid).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        return r.questionId.toLowerCase().contains(q) ||
            r.subject.toLowerCase().contains(q) ||
            r.question.toLowerCase().contains(q) ||
            r.unitName.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // FILE SELECTION (MULTIPLE FILES QUEUE)
  // ============================================================

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        for (final file in result.files) {
          if (file.bytes == null) continue;

          // Prevent identical file duplicates in queue
          if (_files.any((f) => f.name == file.name && f.size == file.size)) {
            continue;
          }

          _files.add(
            QueuedImportFile(
              id: '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
              name: file.name,
              size: file.size,
              bytes: file.bytes!,
              status: ImportFileStatus.ready,
            ),
          );
        }
        _hasValidated = false;
        _lastResult = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick files: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
      _hasValidated = false;
      _lastResult = null;
    });
  }

  // ============================================================
  // VALIDATE ALL
  // ============================================================

  Future<void> _validateAll() async {
    if (_files.isEmpty) return;

    setState(() {
      _isValidating = true;
      _hasValidated = false;
    });

    try {
      await _importService.validateAllFiles(_files);
      if (!mounted) return;
      setState(() {
        _hasValidated = true;
        _isValidating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Validation error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ============================================================
  // IMPORT ALL
  // ============================================================

  Future<void> _importAll() async {
    final validRows = _allRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid questions found to import. Please review errors.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final hasDuplicates = validRows.any((r) => r.isDuplicateInFirestore);
    bool skipDuplicates = true;

    if (hasDuplicates) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Firestore Duplicates Detected'),
          content: const Text(
            'Some question IDs already exist in Firestore.\n\n'
            'Would you like to skip duplicates (safe), or overwrite them with this import?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              child: const Text('Overwrite Duplicates'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'skip'),
              child: const Text('Skip Duplicates (Recommended)'),
            ),
          ],
        ),
      );

      if (action == null || action == 'cancel') return;
      skipDuplicates = action == 'skip';
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _totalToImport = validRows.length;
      _importedCount = 0;
    });

    try {
      final result = await _importService.importQuestions(
        rows: _allRows,
        skipFirestoreDuplicates: skipDuplicates,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _importedCount = current;
              _importProgress = total > 0 ? current / total : 0.0;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _lastResult = result;
        for (final f in _files) {
          f.status = ImportFileStatus.imported;
        }
      });

      _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ============================================================
  // RESULT DIALOG
  // ============================================================

  void _showResultDialog(BulkImportResult result) {
    final colors = context.eduColors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Row(
          children: [
            Icon(
              result.hasWarningsOrErrors
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: result.hasWarningsOrErrors ? AppColors.warning : AppColors.success,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.hasWarningsOrErrors
                    ? 'Import Completed With Warnings'
                    : 'Import Complete! 🎉',
                style: TextStyle(color: colors.textPrimary),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metricTile('Files Processed', '${result.filesProcessed}', Icons.folder_outlined),
              _metricTile('Questions Imported', '${result.questionsImported}', Icons.check_circle_outline, color: AppColors.success),
              if (result.skippedCount > 0)
                _metricTile('Skipped (Duplicates)', '${result.skippedCount}', Icons.skip_next_outlined, color: AppColors.warning),
              if (result.failedCount > 0)
                _metricTile('Failed (Invalid Data)', '${result.failedCount}', Icons.error_outline, color: AppColors.error),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Imported ${result.questionsImported} question documents safely into the "questions" collection.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showDetailedLogSheet(result);
            },
            child: const Text('View Details'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showDetailedLogSheet(BulkImportResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Import Audit & Itemized Log',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (result.failedDetails.isNotEmpty) ...[
                      const Text(
                        'Failed Rows',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 6),
                      ...result.failedDetails.map(
                        (f) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.error, color: Colors.red, size: 18),
                          title: Text(f, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (result.skippedDetails.isNotEmpty) ...[
                      const Text(
                        'Skipped Duplicates',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(height: 6),
                      ...result.skippedDetails.map(
                        (s) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.skip_next, color: Colors.orange, size: 18),
                          title: Text(s, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (result.importedDetails.isNotEmpty) ...[
                      const Text(
                        'Imported Questions',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 6),
                      ...result.importedDetails.take(100).map(
                        (i) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.check, color: Colors.green, size: 18),
                          title: Text(i, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, {Color? color}) {
    final colors = context.eduColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: colors.textPrimary))),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROW INSPECTOR MODAL
  // ============================================================

  void _inspectRow(PracticeImportRow row) {
    final colors = context.eduColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Row(
          children: [
            Icon(
              row.isValid ? Icons.check_circle_outline : Icons.error_outline,
              color: row.isValid ? (row.needsReview ? AppColors.warning : AppColors.success) : AppColors.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Row ${row.rowIndex} • ${row.questionId}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (row.validationErrors.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Validation Errors (Must be fixed):',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...row.validationErrors.map(
                          (err) => Text('✕ $err', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                if (row.validationWarnings.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Warnings / Review Items:',
                          style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...row.validationWarnings.map(
                          (w) => Text('⚠ $w', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                Text('${row.grade} • ${row.subject} • Unit ${row.unitNumber} (${row.unitName}) • Year ${row.examYear}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                const SizedBox(height: 12),
                Text('Question:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text(row.question, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                const SizedBox(height: 14),
                Text('Options:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textSecondary)),
                const SizedBox(height: 6),
                _optionItem('A', row.optionA, row.correctAnswer == 'A', colors),
                _optionItem('B', row.optionB, row.correctAnswer == 'B', colors),
                _optionItem('C', row.optionC, row.correctAnswer == 'C', colors),
                _optionItem('D', row.optionD, row.correctAnswer == 'D', colors),
                const SizedBox(height: 14),
                Text('Explanation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text(row.explanation.isNotEmpty ? row.explanation : '(None provided)',
                    style: TextStyle(fontSize: 13, color: colors.textPrimary)),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _optionItem(String letter, String text, bool isCorrect, EduRiseThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCorrect ? AppColors.success.withValues(alpha: 0.12) : colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCorrect ? AppColors.success : colors.border,
          width: isCorrect ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isCorrect ? AppColors.success : colors.border,
            child: Text(letter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCorrect ? Colors.white : colors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal, color: colors.textPrimary))),
          if (isCorrect)
            const Text('✓ Correct Answer', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _safeBack() {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/admin/dashboard');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _safeBack();
      },
      child: Scaffold(
        backgroundColor: colors.scaffoldBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _safeBack,
          ),
          title: const Text('Import Practice Questions'),
          actions: [
            if (_files.isNotEmpty)
              TextButton.icon(
                onPressed: _isImporting ? null : () => setState(() => _files.clear()),
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Queue'),
              ),
          ],
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Import Type Switcher
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'practice',
                    label: Text('Practice Questions'),
                    icon: Icon(Icons.quiz_outlined),
                  ),
                  ButtonSegment(
                    value: 'past_exams',
                    label: Text('Past Entrance Exams'),
                    icon: Icon(Icons.history_edu_rounded),
                  ),
                ],
                selected: const {'practice'},
                onSelectionChanged: (set) {
                  if (set.contains('past_exams')) {
                    context.pushReplacement('/admin/past-exams/import');
                  }
                },
              ),
            ),
            _buildStep1AddFiles(colors),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildStep2ValidateAll(colors),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildStep3Review(colors),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildStep4Import(colors),
          ],
        ),
      ),
    ),
    );
  }

  // ============================================================
  // STEP 1: ADD FILES
  // ============================================================

  Widget _buildStep1AddFiles(EduRiseThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('1', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Step 1 — Add Files',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add multiple Excel (.xlsx) or CSV (.csv) files to the queue before importing.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Production Ingestion Guide Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Practice Question File Requirements & Workflow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '• Supported Formats: Microsoft Excel (.xlsx) or Comma-Separated Values (.csv)\n'
                '• Required Columns: question_text, option_a, option_b, option_c, option_d, answer_letter (A/B/C/D)\n'
                '• Organization Columns: grade (e.g. Grade 11), stream (natural/social), subject, unit_number, unit_name\n'
                '• Workflow: 1. Pick file → 2. Validate structure & schema → 3. Preview in table → 4. Import directly to Firestore questions library.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Drop / Add Box
        InkWell(
          onTap: _isImporting ? null : _pickFiles,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.35),
                style: BorderStyle.solid,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 48, color: colors.primary),
                const SizedBox(height: 12),
                Text(
                  '📄  ADD FILE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  '.xlsx  /  .csv',
                  style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click to choose practice questions spreadsheet from your device',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isImporting ? null : _pickFiles,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Browse Files'),
                ),
              ],
            ),
          ),
        ),

        if (_files.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Files to Import (${_files.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.textPrimary),
              ),
              TextButton.icon(
                onPressed: _isImporting ? null : _pickFiles,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Add More Files'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: colors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _files.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
              itemBuilder: (context, index) {
                final file = _files[index];
                return ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                  title: Text(
                    file.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${file.formattedSize} • ${file.totalQuestionsCount > 0 ? "${file.totalQuestionsCount} questions" : "Pending validation"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: file.status.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(file.status.icon, size: 14, color: file.status.color),
                            const SizedBox(width: 4),
                            Text(
                              file.status.label,
                              style: TextStyle(
                                color: file.status.color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        onPressed: _isImporting ? null : () => _removeFile(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // STEP 2: VALIDATE ALL
  // ============================================================

  Widget _buildStep2ValidateAll(EduRiseThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('2', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Step 2 — Validate All',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Runs multi-level validation on all queued rows before touching Firestore.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard('Files', '${_files.length}', Icons.folder_outlined, Colors.blueGrey, colors),
            _statCard('Questions found', '$_totalQuestions', Icons.quiz_outlined, Colors.blue, colors),
            _statCard('✓ Valid questions', '$_validQuestions', Icons.check_circle_outline, AppColors.success, colors),
            _statCard('⚠ Need review', '$_needsReviewQuestions', Icons.warning_amber_rounded, AppColors.warning, colors),
            _statCard('✕ Invalid', '$_invalidQuestions', Icons.error_outline, AppColors.error, colors),
          ],
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: (_files.isEmpty || _isValidating || _isImporting) ? null : _validateAll,
            icon: _isValidating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.rule_rounded),
            label: Text(_isValidating ? 'Validating All Files...' : 'Validate All Files'),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, EduRiseThemeColors colors) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colors.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: colors.isDark ? 0.4 : 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3: REVIEW PREVIEW TABLE
  // ============================================================

  Widget _buildStep3Review(EduRiseThemeColors colors) {
    final rows = _filteredRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('3', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Step 3 — Review',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Inspect individual parsed questions, errors, warnings, and duplicate warnings.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Filter and Search Toolbar
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('all', 'All (${_allRows.length})'),
                _filterChip('valid', 'Valid ($_validQuestions)'),
                _filterChip('needsReview', 'Need Review ($_needsReviewQuestions)'),
                _filterChip('invalid', 'Invalid ($_invalidQuestions)'),
              ],
            ),
            SizedBox(
              width: 240,
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search parsed questions...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!_hasValidated && _files.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please click "Validate All Files" above to populate the preview table.',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          )
        else if (_files.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.table_chart_outlined, size: 36, color: colors.textSecondary),
                const SizedBox(height: 10),
                Text(
                  'No questions parsed yet',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a .xlsx or .csv practice question file in Step 1 to populate the review and validation preview table.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
          )
        else if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'No questions match the current filter or search.',
              style: TextStyle(color: colors.textSecondary),
            ),
          )
        else
          Card(
            elevation: 0,
            color: colors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(colors.surfaceSubtle),
                dataRowColor: WidgetStateProperty.all(colors.cardBackground),
                headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                dataTextStyle: TextStyle(color: colors.textPrimary),
                columns: [
                  DataColumn(label: Text('Row', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Question ID', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Answer', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                ],
                rows: rows.take(100).map((row) {
                  final statusText = !row.isValid
                      ? '✕ Invalid'
                      : (row.needsReview ? '⚠ Review' : '✓ Valid');
                  final statusColor = !row.isValid
                      ? AppColors.error
                      : (row.needsReview ? AppColors.warning : AppColors.success);

                  return DataRow(
                    cells: [
                      DataCell(Text('${row.rowIndex}', style: TextStyle(color: colors.textPrimary))),
                      DataCell(
                        Text(
                          row.questionId,
                          style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ),
                      DataCell(Text(row.grade, style: TextStyle(color: colors.textPrimary))),
                      DataCell(Text(row.subject, style: TextStyle(color: colors.textPrimary))),
                      DataCell(Text('Unit ${row.unitNumber}', style: TextStyle(color: colors.textPrimary))),
                      DataCell(Text('${row.examYear}', style: TextStyle(color: colors.textPrimary))),
                      DataCell(
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.success.withValues(alpha: 0.15),
                          child: Text(
                            row.correctAnswer,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.remove_red_eye_outlined, size: 18, color: colors.primary),
                          tooltip: 'Inspect Row Details',
                          onPressed: () => _inspectRow(row),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _tableFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _tableFilter = filterKey),
    );
  }

  // ============================================================
  // STEP 4: IMPORT
  // ============================================================

  Widget _buildStep4Import(EduRiseThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('4', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Step 4 — Import',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Imports all validated questions into Firestore using batched writes.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),

        if (_isImporting) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'IMPORTING QUESTIONS...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                    Text(
                      '${(_importProgress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _importProgress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                Text(
                  '$_importedCount / $_totalToImport questions processed. Please do not close this screen.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        Row(
          children: [
            OutlinedButton(
              onPressed: _isImporting ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: (!_hasValidated || _validQuestions == 0 || _isImporting)
                    ? null
                    : _importAll,
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text(
                  _isImporting ? 'Importing...' : '🚀 IMPORT ALL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
