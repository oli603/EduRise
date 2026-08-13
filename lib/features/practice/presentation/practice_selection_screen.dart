import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class PracticeSelectionScreen extends StatefulWidget {
  const PracticeSelectionScreen({super.key});

  @override
  State<PracticeSelectionScreen> createState() =>
      _PracticeSelectionScreenState();
}

class _PracticeSelectionScreenState extends State<PracticeSelectionScreen> {
  String? _selectedGrade;
  String? _selectedSubject;
  int? _selectedUnitNumber;
  String? _selectedUnitName;

  final List<String> _grades = ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];

  final List<String> _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
  ];

  final Map<String, List<Map<String, dynamic>>> _units = {
    'Mathematics': [
      {'number': 1, 'name': 'Sets'},
      {'number': 2, 'name': 'Functions'},
      {'number': 3, 'name': 'Algebra'},
    ],
    'Physics': [
      {'number': 1, 'name': 'Motion'},
      {'number': 2, 'name': 'Forces'},
    ],
    'Chemistry': [
      {'number': 1, 'name': 'Atomic Structure'},
      {'number': 2, 'name': 'Chemical Bonding'},
    ],
    'Biology': [
      {'number': 1, 'name': 'Cell Biology'},
      {'number': 2, 'name': 'Genetics'},
    ],
  };

  void _selectSubject(String subject) {
    setState(() {
      _selectedSubject = subject;
      _selectedUnitNumber = null;
      _selectedUnitName = null;
    });
  }

  void _selectUnit(int unitNumber, String unitName) {
    setState(() {
      _selectedUnitNumber = unitNumber;
      _selectedUnitName = unitName;
    });
  }

  void _startPractice() {
    if (_selectedGrade == null ||
        _selectedSubject == null ||
        _selectedUnitNumber == null ||
        _selectedUnitName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select grade, subject, and unit.'),
        ),
      );

      return;
    }

    context.push(
      '/practice'
      '?grade=${Uri.encodeComponent(_selectedGrade!)}'
      '&subject=${Uri.encodeComponent(_selectedSubject!)}'
      '&unitNumber=$_selectedUnitNumber'
      '&unitName=${Uri.encodeComponent(_selectedUnitName!)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableUnits = _selectedSubject == null
        ? <Map<String, dynamic>>[]
        : _units[_selectedSubject!] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Choose what you want to practice',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'Select your grade, subject, and unit.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 30),

          const Text(
            '1. Choose your grade',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 12),

          ..._grades.map(
            (grade) => _buildChoiceCard(
              title: grade,
              selected: _selectedGrade == grade,
              onTap: () {
                setState(() {
                  _selectedGrade = grade;
                });
              },
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            '2. Choose your subject',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 12),

          ..._subjects.map(
            (subject) => _buildChoiceCard(
              title: subject,
              selected: _selectedSubject == subject,
              onTap: () => _selectSubject(subject),
            ),
          ),

          if (_selectedSubject != null) ...[
            const SizedBox(height: 28),

            const Text(
              '3. Choose your unit',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 12),

            ...availableUnits.map(
              (unit) => _buildChoiceCard(
                title: 'Unit ${unit['number']} — ${unit['name']}',
                selected: _selectedUnitNumber == unit['number'],
                onTap: () {
                  _selectUnit(unit['number'] as int, unit['name'] as String);
                },
              ),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startPractice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Start Practice',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
