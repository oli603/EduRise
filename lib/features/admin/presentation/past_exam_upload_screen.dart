import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PastExamUploadScreen extends StatefulWidget {
  const PastExamUploadScreen({super.key});

  @override
  State<PastExamUploadScreen> createState() => _PastExamUploadScreenState();
}

class _PastExamUploadScreenState extends State<PastExamUploadScreen> {
  String? _selectedYear;
  String? _selectedStream;
  String? _selectedRound;
  String? _selectedSubject;
  String? _selectedDuration;

  final List<String> _years = ['2013', '2014', '2015', '2016', '2017', '2018'];

  final List<String> _streams = ['Natural Science', 'Social Science'];

  final List<String> _rounds = [
    'Round 1',
    'Round 2',
    'Round 3',
    'Round 4',
    'Round 5',
    'Round 6',
  ];

  final List<String> _naturalScienceSubjects = [
    'Math',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'SAT',
  ];

  final List<String> _socialScienceSubjects = [
    'Math',
    'History',
    'Geography',
    'Economics',
    'English',
    'SAT',
  ];

  final List<String> _durations = ['2 hours', '3 hours'];

  List<String> get _availableSubjects {
    if (_selectedStream == 'Natural Science') {
      return _naturalScienceSubjects;
    }

    if (_selectedStream == 'Social Science') {
      return _socialScienceSubjects;
    }

    return [];
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
          title: const Text('Upload Past Entrance Exam'),
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exam Configuration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Choose the exam information before adding questions.',
              style: TextStyle(color: Colors.black54),
            ),

            const SizedBox(height: 32),

            _buildDropdown(
              label: 'Year',
              hint: 'Select exam year',
              value: _selectedYear,
              items: _years,
              onChanged: (value) {
                setState(() {
                  _selectedYear = value;
                });
              },
            ),

            const SizedBox(height: 20),

            _buildDropdown(
              label: 'Stream',
              hint: 'Select stream',
              value: _selectedStream,
              items: _streams,
              onChanged: (value) {
                setState(() {
                  _selectedStream = value;
                  _selectedSubject = null;
                });
              },
            ),

            const SizedBox(height: 20),

            _buildDropdown(
              label: 'Round',
              hint: 'Optional — select if this exam has a round',
              value: _selectedRound,
              items: _rounds,
              allowNone: true,
              onChanged: (value) {
                setState(() {
                  _selectedRound = value;
                });
              },
            ),

            const SizedBox(height: 20),

            _buildDropdown(
              label: 'Subject',
              hint: 'Select subject',
              value: _selectedSubject,
              items: _availableSubjects,
              enabled: _selectedStream != null,
              onChanged: (value) {
                setState(() {
                  _selectedSubject = value;
                });
              },
            ),

            const SizedBox(height: 20),

            _buildDropdown(
              label: 'Duration',
              hint: 'Select exam duration',
              value: _selectedDuration,
              items: _durations,
              onChanged: (value) {
                setState(() {
                  _selectedDuration = value;
                });
              },
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_selectedYear == null ||
                      _selectedStream == null ||
                      _selectedSubject == null ||
                      _selectedDuration == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please complete the exam configuration first.',
                        ),
                      ),
                    );
                    return;
                  }

                  context.push(
                    '/admin/past-exams/questions',
                    extra: {
                      'year': _selectedYear!,
                      'stream': _selectedStream!,
                      'round': _selectedRound,
                      'subject': _selectedSubject!,
                      'duration': _selectedDuration!,
                    },
                  );
                },

                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to Questions'),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
    bool allowNone = false,
  }) {
    final dropdownItems = <DropdownMenuItem<String>>[];

    if (allowNone) {
      dropdownItems.add(
        const DropdownMenuItem<String>(value: null, child: Text('No round')),
      );
    }

    dropdownItems.addAll(
      items.map(
        (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          items: dropdownItems,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}
