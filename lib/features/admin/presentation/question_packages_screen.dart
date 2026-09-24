import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../practice/data/models/question_package_model.dart';
import '../data/question_package_service.dart';

class QuestionPackagesScreen extends StatefulWidget {
  const QuestionPackagesScreen({super.key});

  @override
  State<QuestionPackagesScreen> createState() => _QuestionPackagesScreenState();
}

class _QuestionPackagesScreenState extends State<QuestionPackagesScreen> {
  final _questionPackageService = QuestionPackageService();

  late Future<List<QuestionPackage>> _packagesFuture;

  @override
  void initState() {
    super.initState();
    _packagesFuture = _questionPackageService.getPackages();
  }

  Future<void> _reloadPackages() async {
    setState(() {
      _packagesFuture = _questionPackageService.getPackages();
    });

    await _packagesFuture;
  }

  Future<void> _openCreatePackage() async {
    await context.push('/admin/create-package');

    if (!mounted) {
      return;
    }

    await _reloadPackages();
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _safeBack,
          ),
          title: const Text('Question Packages'),
        ),
        floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePackage,
        icon: const Icon(Icons.add),
        label: const Text('Create Package'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<QuestionPackage>>(
          future: _packagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorState(onRetry: _reloadPackages);
            }

            final packages = snapshot.data ?? [];

            if (packages.isEmpty) {
              return _EmptyState(onCreatePackage: _openCreatePackage);
            }

            return RefreshIndicator(
              onRefresh: _reloadPackages,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: packages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _PackageCard(
                    package: packages[index],
                    onTap: () {
                      context.push(
                        '/admin/question-packages/${packages[index].packageId}',
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.onTap});

  final QuestionPackage package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPublished = package.status == 'published';
    final statusColor = isPublished ? Colors.green : Colors.orange;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${package.grade} - ${package.subject}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      package.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Unit',
                value: '${package.unitNumber} - ${package.unitName}',
              ),
              if (package.examType != null && package.examType!.isNotEmpty)
                _DetailRow(label: 'Exam type', value: package.examType!),
              if (package.examYear != null)
                _DetailRow(label: 'Exam year', value: '${package.examYear}'),
              _DetailRow(label: 'Version', value: '${package.version}'),
              _DetailRow(label: 'Questions', value: '${package.questionCount}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreatePackage});

  final VoidCallback onCreatePackage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              'No question packages yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a draft package before assigning questions.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreatePackage,
              icon: const Icon(Icons.add),
              label: const Text('Create Package'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Unable to load question packages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
