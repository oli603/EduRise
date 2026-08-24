import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../practice/data/models/question_package_model.dart';
import '../data/question_package_service.dart';

class QuestionPackageDetailsScreen extends StatefulWidget {
  const QuestionPackageDetailsScreen({required this.packageId, super.key});

  final String packageId;

  @override
  State<QuestionPackageDetailsScreen> createState() =>
      _QuestionPackageDetailsScreenState();
}

class _QuestionPackageDetailsScreenState
    extends State<QuestionPackageDetailsScreen> {
  final _questionPackageService = QuestionPackageService();

  late Future<QuestionPackage?> _packageFuture;

  @override
  void initState() {
    super.initState();
    _packageFuture = _questionPackageService.getPackageById(widget.packageId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Package Details')),
      body: SafeArea(
        child: FutureBuilder<QuestionPackage?>(
          future: _packageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const _MessageState(
                icon: Icons.error_outline,
                title: 'Unable to load this package',
              );
            }

            final package = snapshot.data;

            if (package == null) {
              return const _MessageState(
                icon: Icons.inventory_2_outlined,
                title: 'Package not found',
              );
            }

            return _PackageDetails(
              package: package,
              onAssignQuestions: () {
                context.push(
                  '/admin/question-packages/${package.packageId}/assign',
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PackageDetails extends StatelessWidget {
  const _PackageDetails({
    required this.package,
    required this.onAssignQuestions,
  });

  final QuestionPackage package;
  final VoidCallback onAssignQuestions;

  @override
  Widget build(BuildContext context) {
    final isPublished = package.status == 'published';
    final statusColor = isPublished ? Colors.green : Colors.orange;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${package.grade} - ${package.subject}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _StatusChip(status: package.status, color: statusColor),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Package Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        _DetailTile(label: 'Grade', value: package.grade),
        _DetailTile(label: 'Subject', value: package.subject),
        _DetailTile(label: 'Unit Number', value: '${package.unitNumber}'),
        _DetailTile(label: 'Unit Name', value: package.unitName),
        _DetailTile(
          label: 'Exam Type',
          value: package.examType?.isNotEmpty == true
              ? package.examType!
              : 'Not specified',
        ),
        _DetailTile(
          label: 'Exam Year',
          value: package.examYear?.toString() ?? 'Not specified',
        ),
        _DetailTile(label: 'Version', value: '${package.version}'),
        _DetailTile(label: 'Question Count', value: '${package.questionCount}'),
        _DetailTile(label: 'Status', value: package.status),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onAssignQuestions,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Assign Questions'),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(child: Text(value, textAlign: TextAlign.end)),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
