import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/book_model.dart';
import '../data/book_service.dart';
import '../data/book_upload_item.dart';

class AdminBookUploadScreen extends StatefulWidget {
  const AdminBookUploadScreen({super.key});

  @override
  State<AdminBookUploadScreen> createState() => _AdminBookUploadScreenState();
}

class _AdminBookUploadScreenState extends State<AdminBookUploadScreen> {
  final BookService _bookService = BookService();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? selectedGrade;
  String? selectedSubject;

  final List<BookUploadItem> _uploadQueue = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusMessage = '';

  final List<String> grades = ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];

  final List<String> subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
  ];

  // ============================================================
  // ADD UNIT
  // ============================================================

  Future<void> _addUnit() async {
    if (selectedGrade == null || selectedSubject == null) {
      _showMessage('Please select grade and subject first.');
      return;
    }

    final result = await showDialog<BookUploadItem>(
      context: context,
      builder: (_) {
        return _AddUnitDialog(
          existingUnits: _uploadQueue.map((item) => item.unitNumber).toSet(),
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _uploadQueue.add(result);

      _uploadQueue.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
    });
  }

  // ============================================================
  // EDIT UNIT
  // ============================================================

  Future<void> _editUnit(int index) async {
    final currentItem = _uploadQueue[index];

    final otherUnits = _uploadQueue
        .asMap()
        .entries
        .where((entry) => entry.key != index)
        .map((entry) => entry.value.unitNumber)
        .toSet();

    final result = await showDialog<BookUploadItem>(
      context: context,
      builder: (_) {
        return _AddUnitDialog(
          existingUnits: otherUnits,
          initialItem: currentItem,
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _uploadQueue[index] = result;

      _uploadQueue.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
    });

    _showMessage('Unit updated successfully.');
  }

  // ============================================================
  // DELETE UNIT
  // ============================================================

  Future<void> _removeUnit(int index) async {
    final item = _uploadQueue[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Remove unit?'),
          content: Text(
            'Remove Unit ${item.unitNumber} — '
            '${item.unitName} from the upload list?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _uploadQueue.removeAt(index);
    });

    _showMessage('Unit removed.');
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? _validateBatch() {
    if (selectedGrade == null) {
      return 'Please select a grade.';
    }

    if (selectedSubject == null) {
      return 'Please select a subject.';
    }

    if (_uploadQueue.isEmpty) {
      return 'Please add at least one unit.';
    }

    final unitNumbers = _uploadQueue.map((item) => item.unitNumber).toList();

    final duplicates = <int>{};

    for (int i = 0; i < unitNumbers.length; i++) {
      for (int j = i + 1; j < unitNumbers.length; j++) {
        if (unitNumbers[i] == unitNumbers[j]) {
          duplicates.add(unitNumbers[i]);
        }
      }
    }

    if (duplicates.isNotEmpty) {
      return 'Duplicate units found: '
          '${duplicates.map((e) => 'Unit $e').join(', ')}';
    }

    for (final item in _uploadQueue) {
      if (!item.pdfFile.existsSync()) {
        return 'PDF for Unit ${item.unitNumber} '
            'could not be found.';
      }
    }

    return null;
  }

  // ============================================================
  // REVIEW
  // ============================================================

  Future<bool> _showReviewDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Review Book Units'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _uploadQueue.length,
              // ignore: unnecessary_underscores
              separatorBuilder: (_, __) => const Divider(height: 20),
              itemBuilder: (_, index) {
                final item = _uploadQueue[index];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit ${item.unitNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(item.unitName),
                    const SizedBox(height: 3),
                    Text(
                      item.pdfFile.path.split(Platform.pathSeparator).last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Looks Good'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // SUBMIT ALL
  // ============================================================

  Future<void> _submitAll() async {
    final validationError = _validateBatch();

    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    final reviewed = await _showReviewDialog();

    if (!reviewed) {
      return;
    }

    final shouldSubmit = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Submit all units?'),
          content: Text(
            '${_uploadQueue.length} unit(s) are ready.\n\n'
            'Grade: $selectedGrade\n'
            'Subject: $selectedSubject\n\n'
            'Are you sure you want to submit this batch?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Submit All'),
            ),
          ],
        );
      },
    );

    if (shouldSubmit != true) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusMessage = 'Starting upload...';
    });

    try {
      int completed = 0;
      final total = _uploadQueue.length;

      for (final item in _uploadQueue) {
        setState(() {
          _uploadStatusMessage =
              'Uploading Unit ${item.unitNumber} (${completed + 1}/$total)...';
        });

        // 1. Upload to Firebase Storage
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cleanGrade = selectedGrade!.replaceAll(' ', '_');
        final storagePath =
            'book_pdfs/${cleanGrade}_${selectedSubject}_unit_${item.unitNumber}_$timestamp.pdf';

        final ref = _storage.ref().child(storagePath);
        final uploadTask = await ref.putFile(
          item.pdfFile,
          SettableMetadata(contentType: 'application/pdf'),
        );

        final downloadUrl = await uploadTask.ref.getDownloadURL();

        // 2. Save BookUnit to Firestore
        final bookUnit = BookUnit(
          id: '',
          grade: selectedGrade!,
          subject: selectedSubject!,
          unitNumber: item.unitNumber,
          unitName: item.unitName,
          pdfUrl: downloadUrl,
        );

        await _bookService.addUnit(bookUnit);

        completed++;
        setState(() {
          _uploadProgress = completed / total;
        });
      }

      if (!mounted) return;

      _showMessage('All $total unit(s) uploaded successfully! 🎉');

      setState(() {
        _uploadQueue.clear();
        _isUploading = false;
      });

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('UPLOAD ERROR: $e');
      if (!mounted) return;
      _showMessage('Upload failed: ${e.toString()}');
      setState(() {
        _isUploading = false;
      });
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final hasUnits = _uploadQueue.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _safeBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _safeBack,
          ),
          title: const Text('Upload Book Units'),
        ),
        body: SafeArea(
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Book Library',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              'Prepare multiple units and submit them together.',
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // GRADE
            // ==================================================
            DropdownButtonFormField<String>(
              initialValue: selectedGrade,
              decoration: const InputDecoration(
                labelText: 'Grade',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: grades.map((grade) {
                return DropdownMenuItem(value: grade, child: Text(grade));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGrade = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // ==================================================
            // SUBJECT
            // ==================================================
            DropdownButtonFormField<String>(
              initialValue: selectedSubject,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
              items: subjects.map((subject) {
                return DropdownMenuItem(value: subject, child: Text(subject));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubject = value;
                });
              },
            ),

            const SizedBox(height: 28),

            // ==================================================
            // UNITS HEADER
            // ==================================================
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Book Units',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: _addUnit,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Unit'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ==================================================
            // EMPTY STATE
            // ==================================================
            if (!hasUnits)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No units added yet.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Select a grade and subject, '
                      'then start adding your PDFs.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // ==================================================
            // QUEUED UNITS
            // ==================================================
            ...List.generate(_uploadQueue.length, (index) {
              final item = _uploadQueue[index];

              final fileName = item.pdfFile.path
                  .split(Platform.pathSeparator)
                  .last;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color:
                          // ignore: deprecated_member_use
                          Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // UNIT NUMBER
                      CircleAvatar(
                        radius: 23,
                        child: Text(
                          '${item.unitNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // INFORMATION
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unit ${item.unitNumber}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              item.unitName,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),

                            const SizedBox(height: 5),

                            Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ACTIONS
                      Column(
                        children: [
                          IconButton(
                            tooltip: 'Edit unit',
                            onPressed: () {
                              _editUnit(index);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete unit',
                            onPressed: () {
                              _removeUnit(index);
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ==================================================
            // SUMMARY + SUBMIT
            // ==================================================
            if (hasUnits) ...[
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_uploadQueue.length} unit(s) '
                        'ready to submit',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // REVIEW BUTTON
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final validationError = _validateBatch();

                    if (validationError != null) {
                      _showMessage(validationError);
                      return;
                    }

                    await _showReviewDialog();
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('REVIEW ALL UNITS'),
                ),
              ),

              const SizedBox(height: 12),

              if (_isUploading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text(
                  _uploadStatusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],

              // SUBMIT BUTTON
              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isUploading ? null : _submitAll,
                  icon: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _isUploading ? 'UPLOADING UNITS...' : 'SUBMIT ALL UNITS',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

// ==================================================================
// ADD / EDIT UNIT DIALOG
// ==================================================================

class _AddUnitDialog extends StatefulWidget {
  final Set<int> existingUnits;
  final BookUploadItem? initialItem;

  const _AddUnitDialog({required this.existingUnits, this.initialItem});

  @override
  State<_AddUnitDialog> createState() => _AddUnitDialogState();
}

class _AddUnitDialogState extends State<_AddUnitDialog> {
  int? unitNumber;

  late final TextEditingController unitNameController;

  File? selectedPdf;

  bool get isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialItem;

    unitNumber = initial?.unitNumber;

    unitNameController = TextEditingController(text: initial?.unitName ?? '');

    selectedPdf = initial?.pdfFile;
  }

  @override
  void dispose() {
    unitNameController.dispose();
    super.dispose();
  }

  // ================================================================
  // PICK PDF
  // ================================================================

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    setState(() {
      selectedPdf = File(result.files.single.path!);
    });
  }

  // ================================================================
  // SAVE
  // ================================================================

  void _save() {
    if (unitNumber == null) {
      _showError('Please select a unit number.');
      return;
    }

    if (unitNameController.text.trim().isEmpty) {
      _showError('Please enter the unit name.');
      return;
    }

    if (selectedPdf == null) {
      _showError('Please select a PDF.');
      return;
    }

    Navigator.pop(
      context,
      BookUploadItem(
        unitNumber: unitNumber!,
        unitName: unitNameController.text.trim(),
        pdfFile: selectedPdf!,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final availableUnits = List.generate(
      15,
      (index) => index + 1,
    ).where((unit) => !widget.existingUnits.contains(unit));

    return AlertDialog(
      title: Text(isEditing ? 'Edit Unit' : 'Add Unit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // UNIT NUMBER
            DropdownButtonFormField<int>(
              initialValue: unitNumber,
              decoration: const InputDecoration(
                labelText: 'Unit Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.format_list_numbered),
              ),
              items: availableUnits.map((unit) {
                return DropdownMenuItem(value: unit, child: Text('Unit $unit'));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  unitNumber = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // UNIT NAME
            TextField(
              controller: unitNameController,
              decoration: const InputDecoration(
                labelText: 'Unit Name',
                hintText: 'Example: Sets',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),

            const SizedBox(height: 16),

            // PDF
            OutlinedButton.icon(
              onPressed: _pickPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(selectedPdf == null ? 'Choose PDF' : 'Replace PDF'),
            ),

            if (selectedPdf != null) ...[
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedPdf!.path.split(Platform.pathSeparator).last,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Save Changes' : 'Add Unit'),
        ),
      ],
    );
  }
}
