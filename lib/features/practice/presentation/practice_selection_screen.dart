import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  String? _selectedGrade;
  String? _selectedSubject;
  int? _selectedUnitNumber;
  String? _selectedUnitName;
  String? _stream;

  int _questionCount = 10;

  List<String> _grades = [];
  List<Map<String, dynamic>> _units = [];

  bool _isLoadingAcademicInfo = true;
  bool _isLoadingUnits = false;
  String? _errorMessage;

  // ------------------------------------------------------------
  // SUBJECTS
  // ------------------------------------------------------------

  List<String> get _subjects {
    if (widget.stream == 'Natural Science') {
      return ['Mathematics', 'Physics', 'Chemistry', 'Biology'];
    }

    if (widget.stream == 'Social Science') {
      return ['Mathematics', 'Economics', 'Geography', 'History'];
    }

    return const [];
  }

  // ------------------------------------------------------------
  // LOAD UNITS
  // ------------------------------------------------------------

  Future<void> _loadUnits(String subject) async {
    final grade = _selectedGrade;
    final stream = _stream;

    if (grade == null || stream == null) return;

    setState(() {
      _selectedUnitNumber = null;
      _selectedUnitName = null;
      _units = [];
      _isLoadingUnits = true;
      _errorMessage = null;
    });

    try {
      final units = await _questionService.getAvailableUnits(
        grade: widget.grade,
        stream: widget.stream,
        subject: subject,
      );

      if (!mounted) return;

      setState(() {
        _units = units;
        _isLoadingUnits = false;
      });
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
    final stream = _stream;
    final subject = _selectedSubject;
    final unitNumber = _selectedUnitNumber;
    final unitName = _selectedUnitName;

    if (grade == null) {
      _showMessage('Please select a grade.');
      return;
    }

    if (stream == null) {
      _showMessage('Your learning stream is not available.');
      return;
    }

    if (subject == null) {
      _showMessage('Please select a subject.');
      return;
    }

    if (unitNumber == null || unitName == null) {
      _showMessage('Please select a unit.');
      return;
    }

    // Access control check
    final hasAccess = await AccessService.hasPaidAccess();
    if (!hasAccess) {
      if (!mounted) return;
      AccessLockedDialog.show(context, featureName: 'Practice Questions');
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
        'unitName': unitName,
        'questionCount': _questionCount,
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isReady = !_isLoadingAcademicInfo && _errorMessage == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListView(
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

          Text(
            '${widget.grade} • ${widget.stream}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),

          const SizedBox(height: 30),

          // ------------------------------------------------------
          // SUBJECT
          // ------------------------------------------------------
          const Text(
            'Subject',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _selectedSubject,
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
              });

              _loadUnits(value);
            },
          ),

          const SizedBox(height: 28),

          // ------------------------------------------------------
          // UNIT
          // ------------------------------------------------------
          const Text(
            'Unit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 10),

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
              decoration: InputDecoration(
                hintText: _selectedSubject == null
                    ? 'Select a subject first'
                    : 'Select unit',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: _units.map((unit) {
                final number = unit['number'] as int;
                final name = unit['name'] as String;

                return DropdownMenuItem<int>(
                  value: number,
                  child: Text('Unit $number - $name'),
                );
              }).toList(),
              onChanged: _selectedSubject == null
                  ? null
                  : (value) {
                      if (value == null) return;

                      final selectedUnit = _units.firstWhere(
                        (unit) => unit['number'] == value,
                      );

                      setState(() {
                        _selectedUnitNumber = value;
                        _selectedUnitName = selectedUnit['name'] as String;
                      });
                    },
            ),

          const SizedBox(height: 28),

          // ------------------------------------------------------
          // QUESTION COUNT
          // ------------------------------------------------------
          const Text(
            'Number of questions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<int>(
            // ignore: deprecated_member_use
            value: _questionCount,
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

          const SizedBox(height: 40),

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
    );
  }
}
