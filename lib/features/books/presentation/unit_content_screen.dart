//import 'dart:io';

import 'package:flutter/material.dart';

import '../data/book_download_service.dart';
import '../data/book_model.dart';
import 'pdf_reader_screen.dart';

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
                // ignore: deprecated_member_use
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
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
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${unit.subject} • ${unit.grade}',
                    style: TextStyle(color: Colors.grey.shade600),
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

            const SizedBox(height: 14),

            _LearningActionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Notes',
              subtitle: 'Learn this unit deeply with AI',
              enabled: false,
              onTap: null,
            ),

            const SizedBox(height: 14),

            _LearningActionCard(
              icon: Icons.style_rounded,
              title: 'Flashcards',
              subtitle: 'Review important concepts',
              enabled: false,
              onTap: null,
            ),

            const SizedBox(height: 14),

            _LearningActionCard(
              icon: Icons.edit_note_rounded,
              title: 'Practice',
              subtitle: 'Practice questions from this unit',
              enabled: false,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard() {
    if (_checkingDownload) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_isDownloading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.downloading_rounded),
                  SizedBox(width: 12),
                  Text(
                    'Downloading book...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text('${(_downloadProgress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      );
    }

    if (_isDownloaded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(width: 10),
                  Text(
                    'Book downloaded',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded),
                SizedBox(width: 12),
                Text(
                  'Unit Book',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Download this unit for offline reading.',
              style: TextStyle(color: Colors.grey.shade600),
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
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: enabled
                      // ignore: deprecated_member_use
                      ? primary.withOpacity(0.10)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: enabled ? primary : Colors.grey.shade400,
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
                        color: enabled ? Colors.black87 : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
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
                color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
