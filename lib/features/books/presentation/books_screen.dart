import 'package:flutter/material.dart';

import '../data/book_model.dart';
import '../data/book_service.dart';
import 'unit_content_screen.dart';

class BooksScreen extends StatelessWidget {
  final String grade;
  final String subject;

  const BooksScreen({super.key, required this.grade, required this.subject});

  @override
  Widget build(BuildContext context) {
    final bookService = BookService();

    return Scaffold(
      appBar: AppBar(title: Text('$subject • $grade')),
      body: FutureBuilder<List<BookUnit>>(
        future: bookService.getUnits(grade: grade, subject: subject),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load learning units.'));
          }

          final units = snapshot.data ?? [];

          if (units.isEmpty) {
            return const Center(
              child: Text('No learning units available yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: units.length,
            // ignore: unnecessary_underscores
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final unit = units[index];

              return _UnitCard(
                unit: unit,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UnitContentScreen(unit: unit),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final BookUnit unit;
  final VoidCallback onTap;

  const _UnitCard({required this.unit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      // ignore: deprecated_member_use
                      .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${unit.unitNumber}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit ${unit.unitNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unit.unitName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
