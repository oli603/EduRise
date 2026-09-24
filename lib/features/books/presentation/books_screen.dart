import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/access_service.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/download_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/access_locked_dialog.dart';
import '../../profile/data/profile_service.dart';
import '../data/book_download_service.dart';
import '../data/book_model.dart';
import '../data/book_service.dart';
import 'unit_content_screen.dart';

class BooksScreen extends StatefulWidget {
  final String grade;
  final String subject;
  final BookService? bookService;
  final DownloadManager? downloadManager;
  final BookDownloadService? bookDownloadService;

  const BooksScreen({
    super.key,
    required this.grade,
    required this.subject,
    this.bookService,
    this.downloadManager,
    this.bookDownloadService,
  });

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  late final BookService _bookService;
  late final DownloadManager _downloadManager;
  late final BookDownloadService _bookDownloadService;

  late String _selectedGrade;
  late String _selectedSubject;
  String _stream = 'natural';

  late Future<List<BookUnit>> _unitsFuture;
  StreamSubscription<String>? _statusSubscription;

  PackageDownloadState _packageState = PackageDownloadState.notDownloaded;
  double _downloadProgress = 0.0;
  final Map<String, bool> _unitDownloadStatus = {};

  String get _packageId => _downloadManager.getBookPackageId(
        grade: _selectedGrade,
        subject: _selectedSubject,
        stream: _stream,
      );

  List<String> get _availableSubjects =>
      EduRiseSubjects.getPracticeSubjects(stream: _stream, grade: _selectedGrade);

  @override
  void initState() {
    super.initState();
    _bookService = widget.bookService ?? BookService();
    _downloadManager = widget.downloadManager ?? DownloadManager();
    _bookDownloadService = widget.bookDownloadService ?? BookDownloadService();

    _selectedGrade = widget.grade.isNotEmpty ? widget.grade : 'Grade 12';
    _selectedSubject = widget.subject.isNotEmpty ? widget.subject : 'Mathematics';

    _unitsFuture = Future.value([]);
    _resolveStreamAndLoad();

    _statusSubscription = _downloadManager.onStatusChanged.listen((id) {
      if (id == _packageId && mounted) {
        _updatePackageState();
      }
    });
  }

  Future<void> _resolveStreamAndLoad() async {
    try {
      final profile = await ProfileService().getProfile();
      if (profile != null && profile.stream.isNotEmpty) {
        _stream = EduRiseSubjects.canonicalizeStream(profile.stream);
      }
    } catch (_) {}

    // Security & correctness: Clamp subject to stream-allowed subjects
    final allowed = _availableSubjects;
    if (!allowed.contains(_selectedSubject)) {
      _selectedSubject = allowed.isNotEmpty ? allowed.first : 'Mathematics';
    }

    if (mounted) {
      setState(() {
        _loadData();
      });
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _loadData() {
    _unitsFuture = _bookService.getUnits(
      grade: _selectedGrade,
      subject: _selectedSubject,
    );
    _unitsFuture.then((units) => _checkUnitsStatus(units));
    _updatePackageState();
  }

  Future<void> _updatePackageState() async {
    final state = await _downloadManager.getPackageState(_packageId);
    final progress = _downloadManager.getProgress(_packageId);
    if (mounted) {
      setState(() {
        _packageState = state;
        _downloadProgress = progress;
      });
      final units = await _unitsFuture;
      await _checkUnitsStatus(units);
    }
  }

  Future<void> _checkUnitsStatus(List<BookUnit> units) async {
    final Map<String, bool> status = {};
    for (final unit in units) {
      status[unit.id] = await _bookDownloadService.isDownloaded(unit.id);
    }
    if (mounted) {
      setState(() {
        _unitDownloadStatus.addAll(status);
      });
    }
  }

  Future<void> _handleDownloadAll(List<BookUnit> units) async {
    final hasAccess = await AccessService.hasPaidAccess();
    if (!hasAccess) {
      if (!mounted) return;
      AccessLockedDialog.show(context, featureName: 'Books & Units');
      return;
    }

    try {
      await _downloadManager.downloadBookPackage(
        grade: _selectedGrade,
        subject: _selectedSubject,
        stream: _stream,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All units downloaded successfully for offline reading!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download status: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openUnit(BookUnit unit) async {
    final hasAccess = await AccessService.hasPaidAccess();
    if (!hasAccess) {
      if (!mounted) return;
      AccessLockedDialog.show(context, featureName: 'Book Units');
      return;
    }

    final isDownloaded = _unitDownloadStatus[unit.id] ?? false;
    final isOnline = ConnectivityService().isOnline;
    if (!isDownloaded && !isOnline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unit ${unit.unitNumber} is not downloaded for offline use. Connect to the internet to view or download it.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UnitContentScreen(unit: unit),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
      backgroundColor: context.eduColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('$_selectedSubject • $_selectedGrade'),
      ),
      body: Column(
        children: [
          // ==============================================
          // SUBJECT SELECTOR CHIPS
          // ==============================================
          _buildSubjectChips(),

          // ==============================================
          // MAIN UNITS CONTENT
          // ==============================================
          Expanded(
            child: FutureBuilder<List<BookUnit>>(
              future: _unitsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Unable to load learning units.',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _loadData());
                            },
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final units = snapshot.data ?? [];

                if (units.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No learning units available for $_selectedSubject yet.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadData();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      // ==============================================
                      // BOOK DOWNLOAD ALL HEADER CARD
                      // ==============================================
                      _buildDownloadHeaderCard(units),

                      const SizedBox(height: AppSpacing.lg),

                      // ==============================================
                      // SECTION TITLE
                      // ==============================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Course Units',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${units.length} Unit${units.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // ==============================================
                      // UNITS LIST
                      // ==============================================
                      ...units.map((unit) {
                        final isDownloaded = _unitDownloadStatus[unit.id] ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _buildUnitCard(unit, isDownloaded: isDownloaded),
                        );
                      }),

                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ============================================================
  // SUBJECT SELECTOR CHIPS BAR
  // ============================================================
  Widget _buildSubjectChips() {
    final colors = context.eduColors;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _availableSubjects.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final subject = _availableSubjects[index];
          final isSelected = subject == _selectedSubject;
          return ChoiceChip(
            label: Text(subject),
            selected: isSelected,
            selectedColor: colors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: isSelected ? colors.primary : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected ? colors.primary : colors.border,
            ),
            onSelected: (selected) {
              if (selected && _selectedSubject != subject) {
                setState(() {
                  _selectedSubject = subject;
                  _loadData();
                });
              }
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // DOWNLOAD ALL HEADER CARD
  // ============================================================
  Widget _buildDownloadHeaderCard(List<BookUnit> units) {
    final colors = context.eduColors;
    final downloadedCount = units.where((u) => _unitDownloadStatus[u.id] == true).length;
    final isAllDownloaded = units.isNotEmpty && downloadedCount == units.length;
    final isDownloading = _packageState == PackageDownloadState.downloading;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.indigo, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedSubject • $_selectedGrade',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$downloadedCount of ${units.length} units downloaded',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAllDownloaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
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

          // PROGRESS BAR IF DOWNLOADING
          if (isDownloading) ...[
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading units... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],

          if (!isAllDownloaded && !isDownloading) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  downloadedCount > 0
                      ? 'Download Remaining (${units.length - downloadedCount} Units)'
                      : 'Download All (${units.length} Units)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _handleDownloadAll(units),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // UNIT CARD
  // ============================================================
  Widget _buildUnitCard(BookUnit unit, {required bool isDownloaded}) {
    final colors = context.eduColors;
    return Material(
      color: colors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openUnit(unit),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: isDownloaded
                      ? AppColors.success.withValues(alpha: 0.1)
                      : colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${unit.unitNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDownloaded ? AppColors.success : colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit ${unit.unitNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit.unitName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDownloaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
