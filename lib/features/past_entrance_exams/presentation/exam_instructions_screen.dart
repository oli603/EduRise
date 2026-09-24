import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/access_service.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/download_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/access_locked_dialog.dart';

class ExamInstructionsScreen extends StatefulWidget {
  final String year;
  final String stream;
  final String subject;
  final String? round;
  final int questionCount;
  final Duration examDuration;

  const ExamInstructionsScreen({
    super.key,
    required this.year,
    this.stream = 'natural',
    required this.subject,
    this.round,
    required this.questionCount,
    required this.examDuration,
  });

  @override
  State<ExamInstructionsScreen> createState() => _ExamInstructionsScreenState();
}

class _ExamInstructionsScreenState extends State<ExamInstructionsScreen> {
  final DownloadManager _downloadManager = DownloadManager();
  StreamSubscription<String>? _downloadSubscription;
  PackageDownloadState _packageState = PackageDownloadState.notDownloaded;

  String get _packageId => _downloadManager.getPastExamPackageId(
        year: widget.year,
        stream: widget.stream,
        subject: widget.subject,
      );

  @override
  void initState() {
    super.initState();
    _refreshDownloadState();
    _downloadSubscription = _downloadManager.onStatusChanged.listen((_) {
      _refreshDownloadState();
    });
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshDownloadState() async {
    final state = await _downloadManager.getPackageState(_packageId);
    if (mounted && _packageState != state) {
      setState(() {
        _packageState = state;
      });
    }
  }

  Future<void> _handleDownload() async {
    final hasAccess = await AccessService.canAccessPastExams();
    if (!hasAccess) {
      if (!mounted) return;
      AccessLockedDialog.show(
        context,
        featureName: 'Past Entrance Exams Download',
      );
      return;
    }

    try {
      await _downloadManager.downloadPastExamPackage(
        year: widget.year,
        stream: widget.stream,
        subject: widget.subject,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded "${widget.year} EC ${widget.subject} Exam" for offline practice!'),
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours hours $minutes minutes';
    }

    if (hours > 0) {
      return '$hours hours';
    }

    return '$minutes minutes';
  }

  void _safeBack() {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/past-entrance-exams');
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
          title: const Text('Exam Instructions'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _safeBack,
          ),
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exam title
              Text(
                '${widget.year} EC ${widget.subject} Exam',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 28),

              // Warning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Before You Start',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    Text(
                      'Once you start the exam, the timer runs continuously.',
                    ),

                    SizedBox(height: 10),

                    Text(
                      'Downloaded exams work 100% offline without any internet connection.',
                    ),

                    SizedBox(height: 10),

                    Text(
                      'The countdown timer will start immediately when you begin.',
                    ),

                    SizedBox(height: 10),

                    Text(
                      'Your answers will be submitted when you finish or when the time expires.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Exam information
              const Text(
                'Exam Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              _buildInfoCard(
                icon: Icons.timer_outlined,
                title: 'Duration',
                value: _formatDuration(widget.examDuration),
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.quiz_outlined,
                title: 'Questions',
                value: '${widget.questionCount} questions',
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.subject_outlined,
                title: 'Subject',
                value: widget.subject,
              ),

              const SizedBox(height: 24),

              // Download Card
              _buildOfflineDownloadCard(),

              const SizedBox(height: 24),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final hasAccess = await AccessService.canAccessPastExams();
                    if (!hasAccess) {
                      if (!context.mounted) return;
                      AccessLockedDialog.show(context, featureName: 'Past Entrance Exams');
                      return;
                    }

                    if (!context.mounted) return;

                    final isDownloaded = _packageState == PackageDownloadState.downloaded;
                    final isOnline = ConnectivityService().isOnline;

                    if (!isDownloaded && !isOnline) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.cloud_off_rounded, color: AppColors.warning),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Exam Unavailable Offline',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          content: const Text(
                            'This exam has not been downloaded to this device yet.\n\nConnect to the internet or download it first to practice offline.',
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _handleDownload();
                              },
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('Download Exam'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    final queryParams = {
                      'year': widget.year,
                      'stream': widget.stream,
                      'subject': widget.subject,
                      'durationMinutes': widget.examDuration.inMinutes.toString(),
                      'examId': _packageId,
                    };

                    context.pushReplacement(
                      Uri(
                        path: '/past-entrance-exams/exam',
                        queryParameters: queryParams,
                      ).toString(),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Start Exam',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: _safeBack,
                  child: const Text('Go Back'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildOfflineDownloadCard() {
    final state = _packageState;
    final progress = _downloadManager.getProgress(_packageId);
    final colors = context.eduColors;

    return Container(
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
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.offline_pin_rounded,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Exam Package',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      state == PackageDownloadState.downloaded
                          ? 'Downloaded & ready for offline exam'
                          : 'Download to take this exam without internet',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
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
              backgroundColor: colors.border,
              color: colors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading exam... ${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
          if (state != PackageDownloadState.downloaded &&
              state != PackageDownloadState.downloading) ...[
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
                label: const Text(
                  'Download for Offline Exam',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _handleDownload,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colors = context.eduColors;
    return Card(
      elevation: 0,
      color: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: colors.primary),
        title: Text(
          title,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
