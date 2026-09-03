import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/access_service.dart';
import '../../../core/widgets/access_locked_dialog.dart';
import '../../past_entrance_exams/data/past_exam_service.dart';
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
  final PastExamService _pastExamService = PastExamService();

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

  @override
  void initState() {
    super.initState();
    _selectedGrade = _nonEmpty(widget.grade);
    _stream = _nonEmpty(widget.stream);
    _loadAcademicInfo();
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  // ------------------------------------------------------------
  // STUDENT ACADEMIC CONTEXT
  // ------------------------------------------------------------

  Future<void> _loadAcademicInfo() async {
    setState(() {
      _isLoadingAcademicInfo = true;
      _errorMessage = null;
    });

    try {
      // The students/{uid} profile remains the source of truth. Route values
      // are only accepted when supplied by an existing caller for compatibility.
      final academicInfo = await _pastExamService.getStudentAcademicInfo();
      final stream = academicInfo['stream'];
      final profileGrade = academicInfo['grade'];

      if (!mounted) return;

      final availableGrades = await _questionService.getAvailableGrades(
        stream: stream!,
      );

      if (!mounted) return;

      final grades = {...availableGrades, profileGrade!}.toList()..sort();
      final selectedGrade = grades.contains(_selectedGrade)
          ? _selectedGrade
          : (grades.contains(profileGrade) ? profileGrade : null);

      setState(() {
        _stream = stream;
        _grades = grades;
        _selectedGrade = selectedGrade;
        _isLoadingAcademicInfo = false;
      });
    } catch (e) {
      debugPrint('LOAD PRACTICE ACADEMIC INFO ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingAcademicInfo = false;
        _errorMessage = 'Unable to load your practice information.';
      });
    }
  }

  // ------------------------------------------------------------
  // SUBJECTS
  // ------------------------------------------------------------

  List<String> get _subjects {
    if (_stream == 'Natural Science') {
      return const ['Mathematics', 'Physics', 'Chemistry', 'Biology'];
    }

    if (_stream == 'Social Science') {
      return const ['Mathematics', 'Economics', 'Geography', 'History'];
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
        grade: grade,
        stream: stream,
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
      body: _isLoadingAcademicInfo
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Choose what you want to practice',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_stream != null)
                  Text(
                    _stream!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  _buildMessageCard(_errorMessage!),
                ] else ...[
                  const SizedBox(height: 30),
                  _buildLabel('Grade'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: _inputDecoration('Select grade'),
                    items: _grades
                        .map((grade) => DropdownMenuItem<String>(
                              value: grade,
                              child: Text(grade),
                            ))
                        .toList(),
                    onChanged: isReady && _grades.isNotEmpty
                        ? (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedGrade = value;
                              _selectedSubject = null;
                              _selectedUnitNumber = null;
                              _selectedUnitName = null;
                              _units = [];
                              _errorMessage = null;
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 28),
                  _buildLabel('Subject'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedSubject,
                    decoration: _inputDecoration(
                      _selectedGrade == null
                          ? 'Select a grade first'
                          : _subjects.isEmpty
                              ? 'No subjects available'
                              : 'Select subject',
                    ),
                    items: _subjects
                        .map((subject) => DropdownMenuItem<String>(
                              value: subject,
                              child: Text(subject),
                            ))
                        .toList(),
                    onChanged: _selectedGrade == null || _subjects.isEmpty
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedSubject = value;
                              _selectedUnitNumber = null;
                              _selectedUnitName = null;
                              _units = [];
                              _errorMessage = null;
                            });
                            _loadUnits(value);
                          },
                  ),
                  const SizedBox(height: 28),
                  _buildLabel('Unit'),
                  const SizedBox(height: 10),
                  if (_isLoadingUnits)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_selectedSubject != null && _units.isEmpty)
                    _buildMessageCard('No units available for this selection.')
                  else
                    DropdownButtonFormField<int>(
                      value: _selectedUnitNumber,
                      decoration: _inputDecoration(
                        _selectedSubject == null
                            ? 'Select a subject first'
                            : 'Select unit',
                      ),
                      items: _units.map((unit) {
                        final number = unit['number'] as int;
                        final name = unit['name'] as String;
                        return DropdownMenuItem<int>(
                          value: number,
                          child: Text('Unit $number - $name'),
                        );
                      }).toList(),
                      onChanged: _selectedSubject == null || _units.isEmpty
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
                  _buildLabel('Number of questions'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _questionCount,
                    decoration: _inputDecoration(null),
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
              ],
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  InputDecoration _inputDecoration(String? hintText) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildMessageCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    );
  }
}
