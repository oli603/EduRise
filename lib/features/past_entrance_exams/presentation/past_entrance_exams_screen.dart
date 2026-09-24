import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/access_service.dart';
import '../../../core/offline/download_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/access_locked_dialog.dart';
import '../data/past_exam_service.dart';

class PastEntranceExamsScreen extends StatefulWidget {
  const PastEntranceExamsScreen({super.key});

  @override
  State<PastEntranceExamsScreen> createState() =>
      _PastEntranceExamsScreenState();
}

class _PastEntranceExamsScreenState extends State<PastEntranceExamsScreen> {
  final PastExamService _pastExamService = PastExamService();
  final DownloadManager _downloadManager = DownloadManager();
  StreamSubscription<String>? _downloadStatusSubscription;

  String? _grade;
  String? _stream;

  String? _selectedYear;

  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _years = ['2013', '2014', '2015', '2016', '2017', '2018'];

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
    _downloadStatusSubscription = _downloadManager.onStatusChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _downloadStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStudentInfo() async {
    try {
      final info = await _pastExamService.getStudentAcademicInfo();

      if (!mounted) return;

      setState(() {
        _grade = info['grade'];
        _stream = info['stream'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _safeBack() {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _safeBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Past Entrance Exams'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _safeBack,
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load your profile.\n\n$_errorMessage',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAcademicInfo(),

          const SizedBox(height: 32),

          _buildYearSection(),

          const SizedBox(height: 32),

          _buildSubjectsSection(),
        ],
      ),
    );
  }

  Widget _buildAcademicInfo() {
    final colors = context.eduColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Academic Stream',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              _grade ?? 'Grade 12',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),

            const SizedBox(height: 4),

            Text(
              _stream ?? 'Natural Science',
              style: TextStyle(fontSize: 16, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Year',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          initialValue: _selectedYear,
          decoration: const InputDecoration(
            labelText: 'Year',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
          hint: const Text('Choose an exam year'),
          items: _years.map((year) {
            return DropdownMenuItem<String>(value: year, child: Text('$year EC'));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedYear = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubjectsSection() {
    if (_selectedYear == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exam Subjects',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 12),

          Text(
            'Select a year to see the available subjects.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      );
    }

    final isNatural = (_stream ?? '').toLowerCase().contains('natural');
    final List<String> subjects = isNatural
        ? [
            'Mathematics',
            'Physics',
            'Chemistry',
            'Biology',
            'English',
            'SAT',
          ]
        : [
            'Mathematics',
            'History',
            'Geography',
            'Economics',
            'English',
            'SAT',
          ];

    final canonicalStream = (_stream ?? '').toLowerCase().contains('social') ? 'social' : 'natural';
    final batchKey = _downloadManager.getPastExamYearBatchKey(
      year: _selectedYear!,
      stream: canonicalStream,
    );
    final batchState = _downloadManager.getActiveState(batchKey);
    final batchProgress = _downloadManager.getProgress(batchKey);
    final colors = context.eduColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Exam Subjects',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            if (subjects.isNotEmpty)
              Text(
                '${subjects.length} Subjects',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
          ],
        ),

        const SizedBox(height: 12),

        if (subjects.isEmpty)
          Text(
            'No subjects are available for your stream.',
            style: TextStyle(color: colors.textSecondary),
          )
        else ...[
          _buildBatchDownloadCard(subjects, canonicalStream, batchState, batchProgress),
          const SizedBox(height: 12),
          ...subjects.map((subject) => _buildSubjectCard(subject)),
        ],
      ],
    );
  }

  Widget _buildBatchDownloadCard(
    List<String> subjects,
    String stream,
    PackageDownloadState? batchState,
    double batchProgress,
  ) {
    final isDownloading = batchState == PackageDownloadState.downloading;
    final colors = context.eduColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.download_for_offline_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download All $_selectedYear EC Exams',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Download all ${subjects.length} subjects for offline entrance practice',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: batchProgress > 0 ? batchProgress : null,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              'Downloading $_selectedYear EC exams... ${(batchProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 12),
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
                label: Text(
                  'Download All (${subjects.length} Exams)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _handleDownloadAllExams(subjects, stream),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleDownloadAllExams(List<String> subjects, String stream) async {
    final hasAccess = await AccessService.canAccessPastExams();
    if (!hasAccess) {
      if (!mounted) return;
      AccessLockedDialog.show(context, featureName: 'Past Entrance Exams');
      return;
    }

    try {
      await _downloadManager.downloadAllPastExamsForYear(
        year: _selectedYear!,
        stream: stream,
        subjects: subjects,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All $_selectedYear EC entrance exams downloaded for offline practice!'),
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

  Widget _buildSubjectCard(String subject) {
    final isMath = subject.trim().toLowerCase() == 'mathematics';
    final durationMinutes = isMath ? 180 : 120;
    final stream = (_stream ?? '').toLowerCase().contains('social') ? 'social' : 'natural';
    final packageId = _downloadManager.getPastExamPackageId(
      year: _selectedYear!,
      stream: stream,
      subject: subject,
    );

    return FutureBuilder<PackageDownloadState>(
      future: _downloadManager.getPackageState(packageId),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data == PackageDownloadState.downloaded;
        final isDownloading = snapshot.data == PackageDownloadState.downloading;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              Icons.menu_book_outlined,
              color: isDownloaded ? AppColors.success : null,
            ),
            title: Text(
              subject,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Text(
                  isMath ? '3 Hours (180 min)' : '2 Hours (120 min)',
                  style: TextStyle(fontSize: 13, color: context.eduColors.textSecondary),
                ),
                if (isDownloaded) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Downloaded',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ] else if (isDownloading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: () async {
              final hasAccess = await AccessService.canAccessPastExams();
              if (!hasAccess) {
                if (!context.mounted) return;
                AccessLockedDialog.show(context, featureName: 'Past Entrance Exams');
                return;
              }

              if (!context.mounted) return;

              final queryParameters = <String, String>{
                'year': _selectedYear!,
                'stream': stream,
                'subject': subject,
                'questionCount': '50',
                'durationMinutes': '$durationMinutes',
              };

              context.push(
                Uri(
                  path: '/past-entrance-exams/instructions',
                  queryParameters: queryParameters,
                ).toString(),
              );
            },
          ),
        );
      },
    );
  }
}
