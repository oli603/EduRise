import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/import/past_exam_bulk_import_models.dart';
import '../data/import/past_exam_bulk_import_service.dart';
import '../data/import/practice_bulk_import_models.dart';

class ImportPastExamsScreen extends StatefulWidget {
  const ImportPastExamsScreen({super.key});

  @override
  State<ImportPastExamsScreen> createState() => _ImportPastExamsScreenState();
}

class _ImportPastExamsScreenState extends State<ImportPastExamsScreen> {
  final PastExamBulkImportService _importService = PastExamBulkImportService();

  final List<QueuedImportFile> _files = [];
  List<PastExamPackageDraft> _packages = [];

  bool _isValidating = false;
  bool _hasValidated = false;
  bool _isImporting = false;
  double _importProgress = 0.0;
  int _importedCount = 0;
  int _totalToImport = 0;

  PastExamPackageDraft? _selectedPackageForPreview;

  // Computed summary properties
  int get _totalPackages => _packages.length;
  int get _totalQuestions =>
      _packages.fold(0, (sum, p) => sum + p.totalQuestions);
  int get _completePackages =>
      _packages.where((p) => p.isPackageValid && p.reviewQuestions == 0).length;
  int get _reviewPackages =>
      _packages.where((p) => p.isPackageValid && p.reviewQuestions > 0).length;
  int get _invalidPackages =>
      _packages.where((p) => !p.isPackageValid).length;

  // ============================================================
  // FILE SELECTION
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
        _packages = [];
        _selectedPackageForPreview = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick exam files: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
      _hasValidated = false;
      _packages = [];
      _selectedPackageForPreview = null;
    });
  }

  // ============================================================
  // VALIDATE ALL EXAMS
  // ============================================================

  Future<void> _validateAllExams() async {
    if (_files.isEmpty) return;

    setState(() {
      _isValidating = true;
      _hasValidated = false;
      _packages = [];
    });

    try {
      final parsedPackages = <PastExamPackageDraft>[];

      for (final file in _files) {
        file.status = ImportFileStatus.validating;
        final pkgs = _importService.parseFile(file);
        parsedPackages.addAll(pkgs);

        if (pkgs.isEmpty || pkgs.any((p) => !p.isPackageValid)) {
          file.status = ImportFileStatus.invalid;
        } else if (pkgs.any((p) => p.reviewQuestions > 0)) {
          file.status = ImportFileStatus.needsReview;
        } else {
          file.status = ImportFileStatus.valid;
        }
      }

      setState(() {
        _packages = parsedPackages;
        _hasValidated = true;
        _isValidating = false;
        if (_packages.isNotEmpty) {
          _selectedPackageForPreview = _packages.first;
        }
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
  // IMPORT ALL EXAMS
  // ============================================================

  Future<void> _importAllExams() async {
    final validPackages = _packages.where((p) => p.isPackageValid).toList();
    if (validPackages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No complete exam packages available for import.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _totalToImport = validPackages.length;
      _importedCount = 0;
    });

    try {
      final result = await _importService.importExams(
        packages: validPackages,
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
        for (final f in _files) {
          f.status = ImportFileStatus.imported;
        }
      });

      _showCompletionDialog(result);
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

  void _showCompletionDialog(BulkImportResult result) {
    final colors = context.eduColors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Past Exams Imported! 🎉',
                style: TextStyle(color: colors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metricTile('Files processed', '${result.filesProcessed}', Icons.folder_outlined),
            _metricTile('Exams imported', '${result.importedDetails.length}', Icons.library_books_outlined, color: AppColors.success),
            _metricTile('Questions imported', '${result.questionsImported}', Icons.check_circle_outline, color: AppColors.success),
            if (result.failedCount > 0)
              _metricTile('Failed questions', '${result.failedCount}', Icons.error_outline, color: AppColors.error),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            Text(
              '✓ Original question numbers preserved.\n'
              '✓ Q1 → Q2 → ... → Q100 order strictly maintained in Firestore.',
              style: TextStyle(fontSize: 13, color: colors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, {Color? color}) {
    final colors = context.eduColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: colors.textPrimary))),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? colors.textPrimary,
            ),
          ),
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
          title: const Text('Import Past Entrance Exams'),
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
                  selected: const {'past_exams'},
                  onSelectionChanged: (set) {
                    if (set.contains('practice')) {
                      context.pushReplacement('/admin/questions/import');
                    }
                  },
                ),
              ),
              _buildStep1AddExamFiles(colors),
              const SizedBox(height: 32),
              Divider(color: colors.border),
              const SizedBox(height: 24),
              _buildStep2ValidateAllExams(colors),
              const SizedBox(height: 32),
              Divider(color: colors.border),
              const SizedBox(height: 24),
              _buildStep3ReviewExams(colors),
              const SizedBox(height: 32),
              Divider(color: colors.border),
              const SizedBox(height: 24),
              _buildStep4Import(colors),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STEP 1: ADD EXAM FILES
  // ============================================================

  Widget _buildStep1AddExamFiles(EduRiseThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('1', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Step 1 — Add Exam Files',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add multiple historical entrance exam files (.xlsx / .csv).',
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
                  Icon(Icons.school_outlined, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Past Entrance Exam File Requirements & Workflow',
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
                '• Exam Identity Columns: year (e.g. 2016), stream (natural/social), subject (e.g. Mathematics), duration_minutes (default: 180 for Math, 120 for others)\n'
                '• Question Columns: question_number (1..100), question_text, option_a, option_b, option_c, option_d, answer_letter (A/B/C/D), explanation\n'
                '• Workflow: 1. Select exam file → 2. Validate exam questions & key completeness → 3. Preview exam structure → 4. Save to Past Exam database for student consumption.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        InkWell(
          onTap: _isImporting ? null : _pickFiles,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.history_edu_rounded, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  '📄  ADD EXAM FILE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  '.xlsx  /  .csv',
                  style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload full entrance exams with sequential questions (Q1..Q100)',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isImporting ? null : _pickFiles,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Browse Exam Files'),
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
                'Exam Files (${_files.length})',
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
                  leading: const Icon(Icons.school_outlined, color: AppColors.primary),
                  title: Text(
                    file.name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colors.textPrimary),
                  ),
                  subtitle: Text(
                    file.formattedSize,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
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
                        icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
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
  // STEP 2: VALIDATE ALL EXAMS
  // ============================================================

  Widget _buildStep2ValidateAllExams(EduRiseThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('2', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Step 2 — Validate All Exams',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Validates exam packages, question counts, numbering gaps, and required fields.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard('Exam packages', '$_totalPackages', Icons.library_books_outlined, Colors.blueGrey),
            _statCard('Total questions', '$_totalQuestions', Icons.quiz_outlined, Colors.blue),
            _statCard('✓ Complete', '$_completePackages', Icons.check_circle_outline, Colors.green),
            _statCard('⚠ Need review', '$_reviewPackages', Icons.warning_amber_rounded, Colors.orange),
            _statCard('✕ Invalid', '$_invalidPackages', Icons.error_outline, Colors.red),
          ],
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: (_files.isEmpty || _isValidating || _isImporting)
                ? null
                : _validateAllExams,
            icon: _isValidating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.playlist_add_check_circle_outlined),
            label: Text(_isValidating ? 'Validating All Exams...' : 'Validate All Exams'),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
  // STEP 3: REVIEW EXAM PACKAGES & ORDER
  // ============================================================

  Widget _buildStep3ReviewExams(EduRiseThemeColors colors) {
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
          'Confirm exam packages and verify question sequence ordering.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),

        if (!_hasValidated && _files.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please click "Validate All Exams" above to preview the exam packages.',
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
                Icon(Icons.inventory_2_outlined, size: 36, color: colors.textSecondary),
                const SizedBox(height: 10),
                Text(
                  'No exam files selected yet',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a .xlsx or .csv past exam file in Step 1 to parse, validate, and preview exam packages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
          )
        else if (_packages.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No exam packages parsed yet.',
              style: TextStyle(color: colors.textSecondary),
            ),
          )
        else ...[
          // Package Summary Table
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
                  DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Stream', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Round', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                  DataColumn(label: Text('Select', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                ],
                rows: _packages.map((pkg) {
                  final isSelected = _selectedPackageForPreview == pkg;
                  final statusText = pkg.isPackageValid ? '✓ Ready' : '✕ Invalid';
                  final statusColor = pkg.isPackageValid ? Colors.green : Colors.red;

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => setState(() => _selectedPackageForPreview = pkg),
                    cells: [
                      DataCell(Text(pkg.year, style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                      DataCell(Text(pkg.subject, style: TextStyle(color: colors.textPrimary))),
                      DataCell(Text(pkg.stream, style: TextStyle(color: colors.textPrimary))),
                      DataCell(Text(pkg.round ?? '—', style: TextStyle(color: colors.textPrimary))),
                      DataCell(Text('${pkg.totalQuestions}', style: TextStyle(color: colors.textPrimary))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
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
                        TextButton(
                          onPressed: () => setState(() => _selectedPackageForPreview = pkg),
                          child: const Text('Preview Order'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Order Preservation Preview
          if (_selectedPackageForPreview != null) ...[
            const SizedBox(height: 20),
            _buildOrderPreviewCard(_selectedPackageForPreview!, colors),
          ],
        ],
      ],
    );
  }

  Widget _buildOrderPreviewCard(PastExamPackageDraft pkg, EduRiseThemeColors colors) {
    final orderedQuestions = pkg.getOrderedQuestions();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Preview: ${pkg.year} ${pkg.subject} ${pkg.round ?? ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✓ Original Order Preserved',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sequence Badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: orderedQuestions.take(30).map((q) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'Q${q.questionNumber}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary),
                ),
              );
            }).toList()
              ..addAll(orderedQuestions.length > 30
                  ? [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text(
                          '... → Q${orderedQuestions.last.questionNumber} (${orderedQuestions.length} total)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: colors.textSecondary),
                        ),
                      )
                    ]
                  : []),
          ),
          const SizedBox(height: 14),
          Divider(color: colors.border),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text('Original question order preserved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text('Original question numbers preserved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                ],
              ),
            ],
          ),
        ],
      ),
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
          'Saves each entrance exam into the "past_exams" collection without reordering.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),

        if (_isImporting) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'IMPORTING PAST EXAMS...',
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
                  '$_importedCount / $_totalToImport exams processed. Please do not close this screen.',
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
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: (!_hasValidated || _completePackages == 0 || _isImporting)
                    ? null
                    : _importAllExams,
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text(
                  _isImporting ? 'Importing...' : '🚀 IMPORT ALL EXAMS',
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
