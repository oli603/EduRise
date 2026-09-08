import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Past Exams Imported! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metricTile('Files processed', '${result.filesProcessed}', Icons.folder_outlined),
            _metricTile('Exams imported', '${result.importedDetails.length}', Icons.library_books_outlined, color: Colors.green),
            _metricTile('Questions imported', '${result.questionsImported}', Icons.check_circle_outline, color: Colors.green),
            if (result.failedCount > 0)
              _metricTile('Failed questions', '${result.failedCount}', Icons.error_outline, color: Colors.red),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            const Text(
              '✓ Original question numbers preserved.\n'
              '✓ Q1 → Q2 → ... → Q100 order strictly maintained in Firestore.',
              style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
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
            _buildStep1AddExamFiles(),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildStep2ValidateAllExams(),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildStep3ReviewExams(),
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
  // STEP 1: ADD EXAM FILES
  // ============================================================

  Widget _buildStep1AddExamFiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('1', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Step 1 — Add Exam Files',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Add multiple historical entrance exam files (.xlsx / .csv).',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),

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
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.history_edu_rounded, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text(
                  '📄  ADD EXAM FILE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '.xlsx  /  .csv',
                  style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload full entrance exams with sequential questions (Q1..Q100)',
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
                'Exam Files (${_files.length})',
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
                  leading: const Icon(Icons.school_outlined, color: AppColors.primary),
                  title: Text(
                    file.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    file.formattedSize,
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
  // STEP 2: VALIDATE ALL EXAMS
  // ============================================================

  Widget _buildStep2ValidateAllExams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, child: Text('2', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Step 2 — Validate All Exams',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Validates exam packages, question counts, numbering gaps, and required fields.',
          style: TextStyle(color: Colors.black54),
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

  Widget _buildStep3ReviewExams() {
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
          'Confirm exam packages and verify question sequence ordering.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),

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
                  child: Text('Please click "Validate All Exams" above to preview the exam packages.'),
                ),
              ],
            ),
          )
        else if (_packages.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('No exam packages parsed yet.'),
          )
        else ...[
          // Package Summary Table
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
                  DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Stream', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Round', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Questions', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Select', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _packages.map((pkg) {
                  final isSelected = _selectedPackageForPreview == pkg;
                  final statusText = pkg.isPackageValid ? '✓ Ready' : '✕ Invalid';
                  final statusColor = pkg.isPackageValid ? Colors.green : Colors.red;

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => setState(() => _selectedPackageForPreview = pkg),
                    cells: [
                      DataCell(Text(pkg.year, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(pkg.subject)),
                      DataCell(Text(pkg.stream)),
                      DataCell(Text(pkg.round ?? '—')),
                      DataCell(Text('${pkg.totalQuestions}')),
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
            _buildOrderPreviewCard(_selectedPackageForPreview!),
          ],
        ],
      ],
    );
  }

  Widget _buildOrderPreviewCard(PastExamPackageDraft pkg) {
    final orderedQuestions = pkg.getOrderedQuestions();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  'Q${q.questionNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              );
            }).toList()
              ..addAll(orderedQuestions.length > 30
                  ? [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text(
                          '... → Q${orderedQuestions.last.questionNumber} (${orderedQuestions.length} total)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                      )
                    ]
                  : []),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 6),
          const Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text('Original question order preserved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text('Original question numbers preserved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
          'Saves each entrance exam into the "past_exams" collection without reordering.',
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
                      'IMPORTING PAST EXAMS...',
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
                  '$_importedCount / $_totalToImport exams processed. Please do not close this screen.',
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
