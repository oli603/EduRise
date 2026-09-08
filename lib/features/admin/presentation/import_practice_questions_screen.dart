import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.hasWarningsOrErrors
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: result.hasWarningsOrErrors ? Colors.orange : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(result.hasWarningsOrErrors
                ? 'Import Completed With Warnings'
                : 'Import Complete! 🎉'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metricTile('Files Processed', '${result.filesProcessed}', Icons.folder_outlined),
              _metricTile('Questions Imported', '${result.questionsImported}', Icons.check_circle_outline, color: Colors.green),
              if (result.skippedCount > 0)
                _metricTile('Skipped (Duplicates)', '${result.skippedCount}', Icons.skip_next_outlined, color: Colors.orange),
              if (result.failedCount > 0)
                _metricTile('Failed (Invalid Data)', '${result.failedCount}', Icons.error_outline, color: Colors.red),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Imported ${result.questionsImported} question documents safely into the "questions" collection.',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              row.isValid ? Icons.check_circle_outline : Icons.error_outline,
              color: row.isValid ? (row.needsReview ? Colors.orange : Colors.green) : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Row ${row.rowIndex} • ${row.questionId}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Validation Errors (Must be fixed):',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...row.validationErrors.map(
                          (err) => Text('✕ $err', style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                if (row.validationWarnings.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Warnings / Review Items:',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...row.validationWarnings.map(
                          (w) => Text('⚠ $w', style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                Text('${row.grade} • ${row.subject} • Unit ${row.unitNumber} (${row.unitName}) • Year ${row.examYear}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                const SizedBox(height: 12),
                const Text('Question:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(row.question, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 14),
                const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                _optionItem('A', row.optionA, row.correctAnswer == 'A'),
                _optionItem('B', row.optionB, row.correctAnswer == 'B'),
                _optionItem('C', row.optionC, row.correctAnswer == 'C'),
                _optionItem('D', row.optionD, row.correctAnswer == 'D'),
                const SizedBox(height: 14),
                const Text('Explanation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(row.explanation.isNotEmpty ? row.explanation : '(None provided)',
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
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

  Widget _optionItem(String letter, String text, bool isCorrect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.grey.shade300,
          width: isCorrect ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isCorrect ? Colors.green : Colors.grey.shade300,
            child: Text(letter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCorrect ? Colors.white : Colors.black87)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal))),
          if (isCorrect)
            const Text('✓ Correct Answer', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
            _buildStep1AddFiles(),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildStep2ValidateAll(),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildStep3Review(),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildStep4Import(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEP 1: ADD FILES
  // ============================================================

  Widget _buildStep1AddFiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('1', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Step 1 — Add Files',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Add multiple Excel (.xlsx) or CSV (.csv) files to the queue before importing.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // Drop / Add Box
        InkWell(
          onTap: _isImporting ? null : _pickFiles,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.35),
                style: BorderStyle.solid,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text(
                  '📄  ADD FILE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '.xlsx  /  .csv',
                  style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click to select one or multiple files from your computer',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _files.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
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
                          color: file.status.color.withOpacity(0.12),
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

  Widget _buildStep2ValidateAll() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('2', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Step 2 — Validate All',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Runs multi-level validation on all queued rows before touching Firestore.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard('Files', '${_files.length}', Icons.folder_outlined, Colors.blueGrey),
            _statCard('Questions found', '$_totalQuestions', Icons.quiz_outlined, Colors.blue),
            _statCard('✓ Valid questions', '$_validQuestions', Icons.check_circle_outline, Colors.green),
            _statCard('⚠ Need review', '$_needsReviewQuestions', Icons.warning_amber_rounded, Colors.orange),
            _statCard('✕ Invalid', '$_invalidQuestions', Icons.error_outline, Colors.red),
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
  // STEP 3: REVIEW PREVIEW TABLE
  // ============================================================

  Widget _buildStep3Review() {
    final rows = _filteredRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('3', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Step 3 — Review',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Inspect individual parsed questions, errors, warnings, and duplicate warnings.',
          style: TextStyle(color: Colors.black54),
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
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Please click "Validate All Files" above to populate the preview table.'),
                ),
              ],
            ),
          )
        else if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('No questions match the current filter or search.'),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Row', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Question ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Answer', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: rows.take(100).map((row) {
                  final statusText = !row.isValid
                      ? '✕ Invalid'
                      : (row.needsReview ? '⚠ Review' : '✓ Valid');
                  final statusColor = !row.isValid
                      ? Colors.red
                      : (row.needsReview ? Colors.orange : Colors.green);

                  return DataRow(
                    cells: [
                      DataCell(Text('${row.rowIndex}')),
                      DataCell(
                        Text(
                          row.questionId,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(row.grade)),
                      DataCell(Text(row.subject)),
                      DataCell(Text('Unit ${row.unitNumber}')),
                      DataCell(Text('${row.examYear}')),
                      DataCell(
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.green.shade100,
                          child: Text(
                            row.correctAnswer,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),
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
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
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

  Widget _buildStep4Import() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('4', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Step 4 — Import',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Imports all validated questions into Firestore using batched writes.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),

        if (_isImporting) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
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
