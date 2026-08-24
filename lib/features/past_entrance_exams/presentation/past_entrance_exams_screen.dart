import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/past_exam_service.dart';

class PastEntranceExamsScreen extends StatefulWidget {
  const PastEntranceExamsScreen({super.key});

  @override
  State<PastEntranceExamsScreen> createState() =>
      _PastEntranceExamsScreenState();
}

class _PastEntranceExamsScreenState extends State<PastEntranceExamsScreen> {
  final PastExamService _pastExamService = PastExamService();

  String? _grade;
  String? _stream;

  String? _selectedYear;
  String? _selectedRound;

  bool _isLoading = true;
  String? _errorMessage;

  // Temporary years for the UI.
  // Later these will come from the admin configuration.
  final List<String> _years = ['2013', '2014', '2015', '2016', '2017', '2018'];

  // Temporary round configuration.
  //
  // Later this information will come from Firestore
  // and will be controlled by the admin.
  final Map<String, List<String>> _yearRounds = {
    '2013': [],
    '2014': [],
    '2015': ['Round 1', 'Round 2'],
    '2016': ['Round 1', 'Round 2', 'Round 3'],
    '2017': ['Round 1', 'Round 2', 'Round 3'],
    '2018': ['Round 1', 'Round 2', 'Round 3'],
  };

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past Entrance Exams')),
      body: _buildBody(),
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

          const SizedBox(height: 24),

          _buildRoundSection(),

          const SizedBox(height: 32),

          _buildSubjectsSection(),
        ],
      ),
    );
  }

  Widget _buildAcademicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Academic Stream',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),

            const SizedBox(height: 8),

            Text(
              _grade ?? 'Unknown grade',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              _stream ?? 'Unknown stream',
              style: const TextStyle(fontSize: 16),
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
            return DropdownMenuItem<String>(value: year, child: Text(year));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedYear = value;

              // Whenever the year changes,
              // the previously selected round must be cleared.
              _selectedRound = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRoundSection() {
    // No year selected yet.
    if (_selectedYear == null) {
      return const SizedBox.shrink();
    }

    // Get rounds configured for the selected year.
    final rounds = _yearRounds[_selectedYear] ?? [];

    // If admin has not configured any round,
    // don't show the round selector at all.
    if (rounds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Round',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          initialValue: _selectedRound,
          decoration: const InputDecoration(
            labelText: 'Round',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.filter_list_outlined),
          ),
          hint: const Text('Choose an exam round'),
          items: rounds.map((round) {
            return DropdownMenuItem<String>(value: round, child: Text(round));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedRound = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubjectsSection() {
    if (_selectedYear == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exam Subjects',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          const Text(
            'Select a year to see the available subjects.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      );
    }

    final rounds = _yearRounds[_selectedYear] ?? [];

    // This year has rounds, but the student has not selected one yet.
    if (rounds.isNotEmpty && _selectedRound == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exam Subjects',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          const Text(
            'Select a round to see the available subjects.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      );
    }

    // Subjects are determined automatically from
    // the student's registered stream.
    final List<String> subjects;

    if (_stream == 'Natural Science') {
      subjects = [
        'Mathematics',
        'Physics',
        'Chemistry',
        'Biology',
        'English',
        'SAT',
      ];
    } else if (_stream == 'Social Science') {
      subjects = [
        'Mathematics',
        'History',
        'Geography',
        'Economics',
        'English',
        'SAT',
      ];
    } else {
      subjects = [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exam Subjects',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        if (subjects.isEmpty)
          const Text(
            'No subjects are available for your stream.',
            style: TextStyle(color: Colors.black54),
          )
        else
          ...subjects.map((subject) => _buildSubjectCard(subject)),
      ],
    );
  }

  Widget _buildSubjectCard(String subject) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(
          subject,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        onTap: () {
          final queryParameters = <String, String>{
            'year': _selectedYear!,
            'subject': subject,
            'questionCount': '50',
            'durationMinutes': '180',
          };

          if (_selectedRound != null) {
            queryParameters['round'] = _selectedRound!;
          }

          context.push(
            Uri(
              path: '/past-entrance-exams/instructions',
              queryParameters: queryParameters,
            ).toString(),
          );
        },
      ),
    );
  }
}
