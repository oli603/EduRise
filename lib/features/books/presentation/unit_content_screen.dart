import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/offline/offline_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/book_download_service.dart';
import '../data/book_model.dart';
import 'pdf_reader_screen.dart';
import 'unit_summary_screen.dart';
import 'unit_flashcards_screen.dart';
import 'unit_ai_notes_screen.dart';
import 'unit_understand_screen.dart';
import 'unit_quiz_screen.dart';

class UnitContentScreen extends StatefulWidget {
  final BookUnit unit;

  const UnitContentScreen({super.key, required this.unit});

  @override
  State<UnitContentScreen> createState() => _UnitContentScreenState();
}

class _UnitContentScreenState extends State<UnitContentScreen> {
  final BookDownloadService _downloadService = BookDownloadService();

  bool _checkingDownload = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;

  double _downloadProgress = 0;

  Future<bool> _verifyStreamAccess() async {
    final gradeClean = widget.unit.grade.toLowerCase().replaceAll('grade', '').trim();
    if (gradeClean == '9' || gradeClean == '10') {
      return true; // Grades 9 & 10 are common foundational curriculum
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? SessionManager.currentUid;
    if (uid != null) {
      final profile = await OfflineStorageService.instance.getStudentProfile(uid);
      final stream = profile?.stream ?? 'natural';
      if (!EduRiseSubjects.isSubjectAllowedForStream(widget.unit.subject, stream)) {
        if (mounted) {
          final streamDisplay = EduRiseSubjects.displayStream(stream);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${widget.unit.subject} is not part of the $streamDisplay curriculum.',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _checkDownload();
  }

  Future<void> _checkDownload() async {
    final downloaded = await _downloadService.isDownloaded(widget.unit.id);

    if (!mounted) return;

    setState(() {
      _isDownloaded = downloaded;
      _checkingDownload = false;
    });
  }

  Future<void> _downloadBook() async {
    if (widget.unit.pdfUrl.trim().isEmpty) {
      _showMessage('PDF is not available yet.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      await _downloadService.downloadBook(
        bookId: widget.unit.id,
        pdfUrl: widget.unit.pdfUrl,
        onProgress: (progress) {
          if (!mounted) return;

          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
        _downloadProgress = 1;
      });

      _showMessage('Book downloaded successfully.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDownloading = false;
      });

      _showMessage('Download failed. Please try again.');
    }
  }

  Future<void> _openBook() async {
    final file = await _downloadService.getLocalBookFile(widget.unit.id);

    if (!mounted) return;

    if (file == null) {
      _showMessage('Please download the book first.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfReaderScreen(
          pdfPath: file.path,
          title: 'Unit ${widget.unit.unitNumber} — ${widget.unit.unitName}',
        ),
      ),
    );
  }

  Future<void> _deleteBook() async {
    await _downloadService.deleteBook(widget.unit.id);

    if (!mounted) return;

    setState(() {
      _isDownloaded = false;
    });

    _showMessage('Downloaded book removed from this device.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Unit ${unit.unitNumber}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: context.eduColors.isDark ? 0.16 : 0.08,
                    ),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(
                        alpha: context.eduColors.isDark ? 0.3 : 0.15,
                      ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit ${unit.unitNumber}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unit.unitName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.eduColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${unit.subject} • ${unit.grade}',
                    style: TextStyle(color: context.eduColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Learning Material',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _buildBookCard(),

            const SizedBox(height: 24),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'EduRise Coach Tools',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _LearningActionCard(
              icon: Icons.article_rounded,
              title: 'Unit Summary',
              subtitle: 'Core concepts, highlights & exam takeaways',
              enabled: true,
              onTap: () async {
                if (!await _verifyStreamAccess()) return;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UnitSummaryScreen(unit: unit),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _LearningActionCard(
              icon: Icons.style_rounded,
              title: 'Flashcards',
              subtitle: 'Active recall key definitions and formulas',
              enabled: true,
              onTap: () async {
                if (!await _verifyStreamAccess()) return;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UnitFlashcardsScreen(unit: unit),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _LearningActionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Study Notes',
              subtitle: 'Structured in-depth notes with exam traps',
              enabled: true,
              onTap: () async {
                if (!await _verifyStreamAccess()) return;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UnitAiNotesScreen(unit: unit),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _LearningActionCard(
              icon: Icons.psychology_rounded,
              title: 'I Don\'t Understand This Unit',
              subtitle: 'Plain English teacher breakdown & analogies',
              enabled: true,
              onTap: () async {
                if (!await _verifyStreamAccess()) return;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UnitUnderstandScreen(unit: unit),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _LearningActionCard(
              icon: Icons.quiz_rounded,
              title: 'Unit Quiz (7 Questions)',
              subtitle: 'Quick self-check test for this specific unit',
              enabled: true,
              onTap: () async {
                if (!await _verifyStreamAccess()) return;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UnitQuizScreen(unit: unit),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _LearningActionCard(
              icon: Icons.edit_note_rounded,
              title: 'Curriculum Practice Questions',
              subtitle: 'Practice national entrance questions for this unit',
              enabled: true,
              onTap: () {
                context.push(
                  '/practice?grade=${Uri.encodeComponent(unit.grade)}&subject=${Uri.encodeComponent(unit.subject)}&unitNumber=${unit.unitNumber}&unitName=${Uri.encodeComponent(unit.unitName)}',
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard() {
    final colors = context.eduColors;

    if (_checkingDownload) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isDownloading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.downloading_rounded, color: colors.textPrimary),
                const SizedBox(width: 12),
                Text(
                  'Downloading book...',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: colors.border,
            ),
            const SizedBox(height: 8),
            Text(
              '${(_downloadProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_isDownloaded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: 10),
                Text(
                  'Book downloaded',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openBook,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('READ BOOK'),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _deleteBook,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove Download'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: colors.textPrimary),
              const SizedBox(width: 12),
              Text(
                'Unit Book',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Download this unit for offline reading.',
            style: TextStyle(color: colors.textSecondary),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _downloadBook,
              icon: const Icon(Icons.download_rounded),
              label: const Text('DOWNLOAD BOOK'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _LearningActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final isDark = colors.isDark;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: enabled ? colors.cardBackground : colors.surfaceSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: enabled
                      ? primary.withValues(alpha: isDark ? 0.2 : 0.10)
                      : colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: enabled ? primary : colors.textMuted,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: enabled ? colors.textPrimary : colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled
                            ? colors.textSecondary
                            : colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                enabled
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_outline_rounded,
                size: 17,
                color: enabled ? colors.textSecondary : colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
