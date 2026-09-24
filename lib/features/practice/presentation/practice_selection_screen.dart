import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/access_service.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/offline/download_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/access_locked_dialog.dart';
import '../../profile/data/profile_service.dart';
import '../data/question_service.dart';

class PracticeSelectionScreen extends StatefulWidget {
  final String? grade;
  final String? stream;

  const PracticeSelectionScreen({
    super.key,
    this.grade,
    this.stream,
  });

  @override
  State<PracticeSelectionScreen> createState() =>
      _PracticeSelectionScreenState();
}

class _PracticeSelectionScreenState extends State<PracticeSelectionScreen> {
  final QuestionService _questionService = QuestionService();
  final ProfileService _profileService = ProfileService();
  final DownloadManager _downloadManager = DownloadManager();

  StreamSubscription<String>? _downloadStatusSubscription;
  PackageDownloadState _packageDownloadState = PackageDownloadState.notDownloaded;

  static const List<String> _availableGrades = [
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  static const List<int> _availableYears = [
    2013,
    2014,
    2015,
    2016,
    2017,
    2018,
  ];

  String? _selectedGrade;
  String? _selectedSubject;
  int? _selectedUnitNumber;
  String? _selectedUnitName;
  int? _selectedYear;
  String? _stream;

  int _questionCount = 10;

  List<Map<String, dynamic>> _units = [];

  bool _isLoadingUnits = false;
  String? _errorMessage;

  /// Canonical EduRise stream: strictly 'natural' or 'social'
  String get _canonicalStream {
    final raw = (_stream != null && _stream!.trim().isNotEmpty)
        ? _stream!.trim().toLowerCase()
        : '';
    if (raw.contains('social')) return 'social';
    if (raw.contains('natural')) return 'natural';

    if (_selectedSubject != null) {
      final sub = _selectedSubject!.trim().toLowerCase();
      if (sub == 'economics' || sub == 'geography' || sub == 'history') {
        return 'social';
      }
    }
    return 'natural';
  }

  @override
  void initState() {
    super.initState();
    // Default textbook grade can start with widget.grade if valid, or Grade 11
    final initialGrade = widget.grade?.trim();
    if (initialGrade != null && _availableGrades.contains(initialGrade)) {
      _selectedGrade = initialGrade;
    } else {
      _selectedGrade = 'Grade 11';
    }

    _stream = widget.stream?.trim();
    _selectedYear = 2017;

    _loadStudentStreamIfNeeded();

    _downloadStatusSubscription = _downloadManager.onStatusChanged.listen((_) {
      _refreshPackageDownloadState();
    });
  }

  @override
  void dispose() {
    _downloadStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshPackageDownloadState() async {
    if (_selectedGrade == null ||
        _selectedSubject == null ||
        _selectedUnitNumber == null ||
        _selectedUnitNumber! <= 0) {
      if (_packageDownloadState != PackageDownloadState.notDownloaded && mounted) {
        setState(() => _packageDownloadState = PackageDownloadState.notDownloaded);
      }
      return;
    }

    final packageId = _downloadManager.getPracticePackageId(
      grade: _selectedGrade!,
      stream: _canonicalStream,
      subject: _selectedSubject!,
      unitNumber: _selectedUnitNumber!,
      examYear: _selectedYear,
    );

    try {
      final state = await _downloadManager.getPackageState(packageId);
      if (mounted && _packageDownloadState != state) {
        setState(() => _packageDownloadState = state);
      }
    } catch (_) {}
  }

  Future<void> _loadStudentStreamIfNeeded() async {
    if (_stream != null && _stream!.isNotEmpty) return;

    try {
      final profile = await _profileService.getProfile();
      if (profile != null && mounted) {
        final profileStream = profile.stream;
        if (profileStream.isNotEmpty) {
          final previousStream = _canonicalStream;
          setState(() {
            _stream = profileStream;
          });
          // Only reload units if the canonical stream actually changed
          if (_canonicalStream != previousStream &&
              _selectedSubject != null &&
              _selectedGrade != null) {
            _loadUnits(_selectedSubject!);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading student stream for practice: $e');
    }
  }

  // ------------------------------------------------------------
  // SUBJECTS
  // ------------------------------------------------------------

  List<String> get _subjects {
    return EduRiseSubjects.getPracticeSubjects(
      stream: _canonicalStream,
      grade: _selectedGrade,
    );
  }

  // ------------------------------------------------------------
  // LOAD UNITS
  // ------------------------------------------------------------

  Future<void> _loadUnits(String subject) async {
    final grade = _selectedGrade;
    final stream = _canonicalStream;

    if (grade == null) return;

    final preservedUnitNumber = _selectedUnitNumber;
    final preservedUnitName = _selectedUnitName;

    setState(() {
      _isLoadingUnits = true;
      _errorMessage = null;
    });

    try {
      final units = await _questionService.getAvailableUnits(
        grade: grade,
        stream: stream,
        subject: subject,
      );

      if (!mounted) return;

      int? newUnitNumber;
      String? newUnitName;

      // Check if previously selected unit is still present in newly loaded units
      if (preservedUnitNumber != null) {
        final match = units.firstWhere(
          (u) => (u['number'] as num?)?.toInt() == preservedUnitNumber,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          newUnitNumber = (match['number'] as num?)?.toInt();
          newUnitName = (match['name'] as String?)?.trim() ?? preservedUnitName;
        }
      }

      // If no valid previous unit is selected, auto-select if there is exactly 1 unit
      if (newUnitNumber == null && units.length == 1) {
        newUnitNumber = (units.first['number'] as num?)?.toInt();
        newUnitName = (units.first['name'] as String?)?.trim();
      }

      setState(() {
        _units = units;
        _selectedUnitNumber = newUnitNumber;
        _selectedUnitName = newUnitName;
        _isLoadingUnits = false;
      });
      _refreshPackageDownloadState();
    } catch (e) {
      debugPrint('LOAD AVAILABLE UNITS ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingUnits = false;
        _errorMessage = 'Unable to load units.';
      });
    }
  }

  // ------------------------------------------------------------
  // START PRACTICE
  // ------------------------------------------------------------

  Future<void> _startPractice() async {
    final grade = _selectedGrade;
    final stream = _canonicalStream;
    final subject = _selectedSubject;
    int? unitNumber = _selectedUnitNumber;
    String? unitName = _selectedUnitName;
    final examYear = _selectedYear;

    // Resolve unit if null but available in _units
    if ((unitNumber == null || unitNumber <= 0) && _units.isNotEmpty) {
      if (_units.length == 1) {
        unitNumber = (_units.first['number'] as num?)?.toInt();
        unitName = (_units.first['name'] as String?)?.trim();
        _selectedUnitNumber = unitNumber;
        _selectedUnitName = unitName;
      }
    }

    String resolvedUnitName = (unitName != null && unitName.trim().isNotEmpty)
        ? unitName.trim()
        : '';
    if (resolvedUnitName.isEmpty && _units.isNotEmpty && unitNumber != null) {
      final matchingUnit = _units.firstWhere(
        (u) => (u['number'] as num?)?.toInt() == unitNumber,
        orElse: () => <String, dynamic>{},
      );
      resolvedUnitName = (matchingUnit['name'] as String?)?.trim() ?? '';
    }

    // Structured debug logging immediately before Start Practice validation
    // ignore: avoid_print
    print('''
PRACTICE START DEBUG
--------------------
selectedGrade: $grade
selectedSubject: $subject
selectedUnit: $unitNumber
selectedUnitNumber: $unitNumber
selectedUnitName: $resolvedUnitName
selectedYear: $examYear
selectedStream: $stream
Grade: $grade
Subject: $subject
Stream: $stream
Unit Number: $unitNumber
Unit Name: $resolvedUnitName
Year: $examYear
''');

    if (grade == null) {
      _showMessage('Please select a textbook grade.');
      return;
    }

    if (subject == null) {
      _showMessage('Please select a subject.');
      return;
    }

    if (unitNumber == null || unitNumber <= 0) {
      _showMessage('Please select a unit.');
      return;
    }

    if (examYear == null) {
      _showMessage('Please select an entrance exam year.');
      return;
    }

    // Access control check: Grade 12 + 2017 EC + Unit 1 is allowed free for testing.
    // All other grades and entrance years require paid access.
    final canAccess = await AccessService.canAccessPractice(
      grade: grade,
      examYear: examYear,
      unitNumber: unitNumber,
    );
    if (!canAccess) {
      if (!mounted) return;
      AccessLockedDialog.show(
        context,
        featureName: 'Practice Questions ($grade • $examYear EC)',
      );
      return;
    }

    if (!mounted) return;

    context.push(
      '/practice',
      extra: {
        'grade': grade,
        'stream': stream,
        'subject': subject,
        'unitNumber': unitNumber,
        'unitName': resolvedUnitName,
        'examYear': examYear,
        'questionCount': _questionCount,
      },
    );
  }

  Future<void> _handleDownloadPackage() async {
    final grade = _selectedGrade;
    final stream = _canonicalStream;
    final subject = _selectedSubject;
    final unitNumber = _selectedUnitNumber;
    final unitName = _selectedUnitName ?? 'Unit $unitNumber';
    final examYear = _selectedYear;

    if (grade == null || subject == null || unitNumber == null || unitNumber <= 0) {
      _showMessage('Please select grade, subject, and unit to download.');
      return;
    }

    final canAccess = await AccessService.canAccessPractice(
      grade: grade,
      examYear: examYear ?? 0,
      unitNumber: unitNumber,
    );

    if (!canAccess) {
      if (!mounted) return;
      AccessLockedDialog.show(
        context,
        featureName: 'Practice Download ($grade • ${examYear ?? ''} EC)',
      );
      return;
    }

    try {
      await _downloadManager.downloadPracticePackage(
        grade: grade,
        stream: stream,
        subject: subject,
        unitNumber: unitNumber,
        unitName: unitName,
        examYear: examYear,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded "$subject $grade Unit $unitNumber" for offline practice!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDownloadAllUnits() async {
    final grade = _selectedGrade;
    final stream = _canonicalStream;
    final subject = _selectedSubject;
    final examYear = _selectedYear;

    if (grade == null || subject == null) {
      _showMessage('Please select grade and subject to download.');
      return;
    }

    final hasPaid = await AccessService.hasPaidAccess();
    if (!hasPaid) {
      if (!mounted) return;
      AccessLockedDialog.show(
        context,
        featureName: 'Download All Practice Units ($subject • $grade)',
      );
      return;
    }

    try {
      await _downloadManager.downloadAllPracticeUnitsForSubject(
        grade: grade,
        stream: stream,
        subject: subject,
        examYear: examYear,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All available units for "$subject $grade" downloaded for offline practice!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch download failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
            // ------------------------------------------------------
            // HEADER
            // ------------------------------------------------------
            Text(
              'Choose what you want to practice',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _canonicalStream == 'natural'
                                ? 'Natural Science Stream'
                                : 'Social Science Stream',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ------------------------------------------------------
            // 1. GRADE (TEXTBOOK GRADE)
            // ------------------------------------------------------
            const Text(
              'Textbook Grade',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedGrade,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select textbook grade',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: _availableGrades.map((grade) {
                return DropdownMenuItem<String>(
                  value: grade,
                  child: Text(grade),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null || value == _selectedGrade) return;

                setState(() {
                  _selectedGrade = value;
                  _selectedSubject = null;
                  _selectedUnitNumber = null;
                  _selectedUnitName = null;
                  _units = [];
                });
              },
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------------
            // 2. SUBJECT
            // ------------------------------------------------------
            const Text(
              'Subject',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedSubject,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select subject',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: _subjects.map((subject) {
                return DropdownMenuItem<String>(
                  value: subject,
                  child: Text(subject),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedSubject = value;
                  _selectedUnitNumber = null;
                  _selectedUnitName = null;
                  _units = [];
                });

                if (_selectedGrade != null) {
                  _loadUnits(value);
                }
              },
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------------
            // 3. UNIT
            // ------------------------------------------------------
            const Text(
              'Unit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            if (_isLoadingUnits)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              )
            else
              DropdownButtonFormField<int>(
                // ignore: deprecated_member_use
                value: _selectedUnitNumber,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: _selectedSubject == null
                      ? 'Select a subject first'
                      : _units.isEmpty
                          ? 'No units available for this subject'
                          : 'Select unit',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: _units.map((unit) {
                  final number = (unit['number'] as num?)?.toInt() ?? 0;
                  final name = (unit['name'] as String?)?.trim() ?? '';
                  final label = name.isNotEmpty ? 'Unit $number - $name' : 'Unit $number';

                  return DropdownMenuItem<int>(
                    value: number,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _selectedSubject == null
                    ? null
                    : (value) {
                        if (value == null) return;

                        final selectedUnit = _units.firstWhere(
                          (unit) => (unit['number'] as num?)?.toInt() == value,
                          orElse: () => <String, dynamic>{'number': value, 'name': ''},
                        );

                        setState(() {
                          _selectedUnitNumber = value;
                          _selectedUnitName = (selectedUnit['name'] as String?)?.trim() ?? '';
                        });
                        _refreshPackageDownloadState();
                      },
              ),

            const SizedBox(height: 20),

            // ------------------------------------------------------
            // 4. ENTRANCE EXAM YEAR
            // ------------------------------------------------------
            const Text(
              'Entrance Exam Year',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _selectedYear,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select entrance year',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: _availableYears.map((year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text('$year EC'),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedYear = value;
                });
                _refreshPackageDownloadState();
              },
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------------
            // 5. QUESTION COUNT
            // ------------------------------------------------------
            const Text(
              'Number of questions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _questionCount,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 Questions')),
                DropdownMenuItem(value: 10, child: Text('10 Questions')),
                DropdownMenuItem(value: 20, child: Text('20 Questions')),
                DropdownMenuItem(value: 30, child: Text('30 Questions')),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _questionCount = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // ------------------------------------------------------
            // OFFLINE DOWNLOAD CARD (SINGLE UNIT OR DOWNLOAD ALL)
            // ------------------------------------------------------
            _buildOfflineDownloadCard(),

            // ------------------------------------------------------
            // START PRACTICE BUTTON
            // ------------------------------------------------------
            SizedBox(
              height: 54,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startPractice,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'Start Practice',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildOfflineDownloadCard() {
    if (_selectedGrade == null ||
        _selectedSubject == null ||
        _selectedUnitNumber == null ||
        _selectedUnitNumber! <= 0) {
      return const SizedBox.shrink();
    }

    final packageId = _downloadManager.getPracticePackageId(
      grade: _selectedGrade!,
      stream: _canonicalStream,
      subject: _selectedSubject!,
      unitNumber: _selectedUnitNumber!,
      examYear: _selectedYear,
    );

    final batchKey = _downloadManager.getPracticeSubjectBatchKey(
      grade: _selectedGrade!,
      stream: _canonicalStream,
      subject: _selectedSubject!,
      examYear: _selectedYear,
    );

    final state = _packageDownloadState;
    final progress = _downloadManager.getProgress(packageId);

    final isBatchDownloading =
        _downloadManager.getActiveState(batchKey) == PackageDownloadState.downloading;
    final batchProgress = _downloadManager.getProgress(batchKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.eduColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.eduColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.offline_pin_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Practice Package',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.eduColors.textPrimary,
                      ),
                    ),
                    Text(
                      state == PackageDownloadState.downloaded
                          ? 'This unit is downloaded and ready offline'
                          : 'Download questions for offline practice without internet',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.eduColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (state == PackageDownloadState.downloaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Downloaded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (state == PackageDownloadState.downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress > 0 ? progress : 0.1,
              backgroundColor: context.eduColors.border,
              color: AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading unit questions... ${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: context.eduColors.textSecondary),
            ),
          ],
          if (isBatchDownloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: batchProgress > 0 ? batchProgress : 0.1,
              backgroundColor: context.eduColors.border,
              color: AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading all units... ${(batchProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: context.eduColors.textSecondary),
            ),
          ],
          if (!isBatchDownloading &&
              state != PackageDownloadState.downloading) ...[
            const SizedBox(height: 12),
            if (state != PackageDownloadState.downloaded)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Download This Unit',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _handleDownloadPackage,
                ),
              ),
            if (_units.length > 1) ...[
              if (state != PackageDownloadState.downloaded) const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                  label: Text(
                    'Download All Units (${_units.length} Units)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _handleDownloadAllUnits,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
