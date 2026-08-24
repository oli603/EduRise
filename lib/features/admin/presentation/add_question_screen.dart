import 'package:flutter/material.dart';

import '../../practice/data/question_model.dart';
import '../../practice/data/question_service.dart';

class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _formKey = GlobalKey<FormState>();

  final QuestionService _questionService = QuestionService();

  // ============================================================
  // EXAM / ACADEMIC INFORMATION
  // ============================================================

  String? _selectedGrade;
  String? _selectedStream;
  String? _selectedSubject;
  int? _selectedUnitNumber;
  String? _selectedExamYear;
  String? _selectedExamType;

  // Admin writes this carefully.
  final _unitNameController = TextEditingController();

  // ============================================================
  // QUESTION DRAFTS
  // ============================================================

  final List<_QuestionDraft> _questions = [_QuestionDraft()];

  bool _isSaving = false;

  // ============================================================
  // FIXED OPTIONS
  // ============================================================

  final List<String> _grades = const [
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  final List<String> _streams = const ['Natural Science', 'Social Science'];

  final List<String> _naturalScienceSubjects = const [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
  ];

  final List<String> _socialScienceSubjects = const [
    'Mathematics',
    'History',
    'Geography',
    'Economics',
    'English',
  ];

  final List<int> _unitNumbers = List.generate(15, (index) => index + 1);

  final List<String> _examYears = const [
    '2013',
    '2014',
    '2015',
    '2016',
    '2017',
    '2018',
    '2019',
    '2020',
    '2021',
    '2022',
    '2023',
    '2024',
    '2025',
    '2026',
  ];

  final List<String> _examTypes = const [
    'Practice Question',
    'Entrance Exam',
    'Model Exam',
    'School Exam',
    'Mock Exam',
    'Other',
  ];

  // ============================================================
  // SUBJECTS DEPEND ON STREAM
  // ============================================================

  List<String> get _availableSubjects {
    if (_selectedStream == 'Natural Science') {
      return _naturalScienceSubjects;
    }

    if (_selectedStream == 'Social Science') {
      return _socialScienceSubjects;
    }

    return [];
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _unitNameController.dispose();

    for (final question in _questions) {
      question.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // ADD ANOTHER QUESTION
  // ============================================================

  void _addQuestion() {
    if (!_validateQuestionSetup()) {
      return;
    }

    if (!_validateCurrentQuestions()) {
      return;
    }

    setState(() {
      _questions.add(_QuestionDraft());
    });

    // Move the screen toward the new question.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      Scrollable.ensureVisible(
        _questions.last.key.currentContext!,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  // ============================================================
  // REMOVE QUESTION
  // ============================================================

  void _removeQuestion(int index) {
    if (_questions.length == 1) {
      _showMessage('You must keep at least one question.');
      return;
    }

    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  // ============================================================
  // SAVE ALL QUESTIONS
  // ============================================================

  Future<void> _saveQuestions() async {
    if (!_validateQuestionSetup()) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final questions = <Question>[];

      final unitName = _unitNameController.text.trim();

      for (int i = 0; i < _questions.length; i++) {
        final draft = _questions[i];

        final question = Question(
          id: '',

          // Academic information
          grade: _selectedGrade!,
          stream: _selectedStream!,
          subject: _selectedSubject!,

          // Unit information
          unitNumber: _selectedUnitNumber!,
          unitName: unitName,

          // Question information
          questionNumber: i + 1,
          question: draft.questionController.text.trim(),
          questionImageUrl: draft.questionImageUrl,

          // Answers
          options: [
            draft.optionAController.text.trim(),
            draft.optionBController.text.trim(),
            draft.optionCController.text.trim(),
            draft.optionDController.text.trim(),
          ],

          correctAnswer: draft.correctAnswer,

          // Explanation
          explanation: draft.explanationController.text.trim(),
          explanationImageUrl: draft.explanationImageUrl,

          // Exam information
          examYear: int.parse(_selectedExamYear!),
          examType: _selectedExamType!,

          // Status
          status: 'published',

          createdAt: null,
        );

        questions.add(question);
      }

      await _questionService.addQuestions(questions);

      if (!mounted) return;

      _showMessage('${questions.length} questions saved successfully! 🎉');

      // After successful save, return to admin dashboard.
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('SAVE QUESTIONS ERROR: $e');

      if (!mounted) return;

      _showMessage('Unable to save questions. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // FINISH
  // ============================================================

  void _finish() {
    if (_isSaving) return;

    if (_questions.length == 1 &&
        _questions.first.questionController.text.trim().isEmpty) {
      _showMessage('Add your questions first, then press Save Questions.');
      return;
    }

    _showMessage('Please press Save Questions before finishing.');
  }

  // ============================================================
  // VALIDATE SETUP
  // ============================================================

  bool _validateQuestionSetup() {
    if (_selectedGrade == null ||
        _selectedStream == null ||
        _selectedSubject == null ||
        _selectedUnitNumber == null ||
        _selectedExamYear == null ||
        _selectedExamType == null) {
      _showMessage('Please complete all exam information first.');

      return false;
    }

    if (_unitNameController.text.trim().isEmpty) {
      _showMessage('Please enter the Unit Name carefully.');

      return false;
    }

    return true;
  }

  // ============================================================
  // VALIDATE CURRENT QUESTIONS
  // ============================================================

  bool _validateCurrentQuestions() {
    for (final question in _questions) {
      if (question.questionController.text.trim().isEmpty ||
          question.optionAController.text.trim().isEmpty ||
          question.optionBController.text.trim().isEmpty ||
          question.optionCController.text.trim().isEmpty ||
          question.optionDController.text.trim().isEmpty ||
          question.explanationController.text.trim().isEmpty) {
        _showMessage(
          'Please complete the current question before adding another.',
        );

        return false;
      }
    }

    return true;
  }

  // ============================================================
  // IMAGE PLACEHOLDERS
  // ============================================================

  void _addQuestionImage(_QuestionDraft draft) {
    _showMessage('Question image upload will be connected next.');
  }

  void _addExplanationImage(_QuestionDraft draft) {
    _showMessage('Explanation image upload will be connected next.');
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Practice Questions')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Question Bank',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                'Create a complete question set and save it when finished.',
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 28),

              // ==================================================
              // EXAM INFORMATION
              // ==================================================
              _sectionTitle('Exam Information'),

              const SizedBox(height: 16),

              _buildDropdown<String>(
                label: 'Grade',
                hint: 'Select grade',
                value: _selectedGrade,
                items: _grades,
                onChanged: (value) {
                  setState(() {
                    _selectedGrade = value;
                    _selectedSubject = null;
                    _selectedUnitNumber = null;
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildDropdown<String>(
                label: 'Stream',
                hint: 'Select stream',
                value: _selectedStream,
                items: _streams,
                onChanged: (value) {
                  setState(() {
                    _selectedStream = value;
                    _selectedSubject = null;
                    _selectedUnitNumber = null;
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildDropdown<String>(
                label: 'Subject',
                hint: 'Select subject',
                value: _selectedSubject,
                items: _availableSubjects,
                enabled: _selectedStream != null,
                onChanged: (value) {
                  setState(() {
                    _selectedSubject = value;
                    _selectedUnitNumber = null;
                  });
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // UNIT NUMBER 1–15
              // ==================================================
              _buildDropdown<int>(
                label: 'Unit Number',
                hint: 'Select unit number',
                value: _selectedUnitNumber,
                items: _unitNumbers,
                enabled: _selectedSubject != null,
                onChanged: (value) {
                  setState(() {
                    _selectedUnitNumber = value;
                  });
                },
                itemBuilder: (unit) {
                  return 'Unit $unit';
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // UNIT NAME
              // ==================================================
              TextFormField(
                controller: _unitNameController,
                decoration: InputDecoration(
                  labelText: 'Unit Name',
                  hintText: 'Admin: enter the official unit name',
                  helperText: 'Write the unit name carefully and consistently.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Unit Name is required.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // EXAM YEAR
              // ==================================================
              _buildDropdown<String>(
                label: 'Exam Year',
                hint: 'Select exam year',
                value: _selectedExamYear,
                items: _examYears,
                onChanged: (value) {
                  setState(() {
                    _selectedExamYear = value;
                  });
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // EXAM TYPE
              // ==================================================
              _buildDropdown<String>(
                label: 'Exam Type',
                hint: 'Select exam type',
                value: _selectedExamType,
                items: _examTypes,
                onChanged: (value) {
                  setState(() {
                    _selectedExamType = value;
                  });
                },
              ),

              const SizedBox(height: 32),

              // ==================================================
              // QUESTIONS HEADER
              // ==================================================
              Row(
                children: [
                  _sectionTitle('Questions'),
                  const Spacer(),
                  Text(
                    '${_questions.length} total',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // ALL QUESTIONS
              // ==================================================
              ...List.generate(_questions.length, (index) {
                final draft = _questions[index];

                return KeyedSubtree(
                  key: draft.key,
                  child: _buildQuestionCard(index, draft),
                );
              }),

              const SizedBox(height: 8),

              // ==================================================
              // ADD QUESTION
              // ==================================================
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _addQuestion,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Question'),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // SAVE QUESTIONS
              // ==================================================
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveQuestions,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _isSaving ? 'Saving Questions...' : 'Save Questions',
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // FINISH
              // ==================================================
              SizedBox(
                height: 52,
                child: TextButton.icon(
                  onPressed: _isSaving ? null : _finish,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Finish'),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUESTION CARD
  // ============================================================

  Widget _buildQuestionCard(int index, _QuestionDraft draft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================================
          // QUESTION HEADER
          // ======================================================
          Row(
            children: [
              CircleAvatar(child: Text('${index + 1}')),

              const SizedBox(width: 12),

              Text(
                'Question ${index + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              if (_questions.length > 1)
                IconButton(
                  onPressed: _isSaving ? null : () => _removeQuestion(index),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove question',
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ======================================================
          // QUESTION TEXT
          // ======================================================
          _buildTextField(
            controller: draft.questionController,
            label: 'Question',
            hint: 'Enter the question...',
            maxLines: 5,
          ),

          const SizedBox(height: 12),

          // ======================================================
          // QUESTION IMAGE
          // ======================================================
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _addQuestionImage(draft),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Add Question Image (Optional)'),
          ),

          const SizedBox(height: 24),

          // ======================================================
          // ANSWERS
          // ======================================================
          const Text(
            'Answer Options',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 14),

          _buildTextField(
            controller: draft.optionAController,
            label: 'Option A',
            hint: 'Enter option A',
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller: draft.optionBController,
            label: 'Option B',
            hint: 'Enter option B',
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller: draft.optionCController,
            label: 'Option C',
            hint: 'Enter option C',
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller: draft.optionDController,
            label: 'Option D',
            hint: 'Enter option D',
          ),

          const SizedBox(height: 16),

          // ======================================================
          // CORRECT ANSWER
          // ======================================================
          _buildDropdown<String>(
            label: 'Correct Answer',
            hint: 'Select correct answer',
            value: draft.correctAnswer,
            items: const ['A', 'B', 'C', 'D'],
            onChanged: (value) {
              setState(() {
                draft.correctAnswer = value!;
              });
            },
            itemBuilder: (answer) {
              return 'Option $answer';
            },
          ),

          const SizedBox(height: 24),

          // ======================================================
          // EXPLANATION
          // ======================================================
          const Text(
            'Explanation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 14),

          _buildTextField(
            controller: draft.explanationController,
            label: 'Explanation',
            hint: 'Explain why the answer is correct...',
            maxLines: 6,
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _addExplanationImage(draft),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Add Explanation Image (Optional)'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required.';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================
  // GENERIC DROPDOWN
  // ============================================================

  Widget _buildDropdown<T>({
    required String label,
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
    String Function(T item)? itemBuilder,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(itemBuilder?.call(item) ?? item.toString()),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: enabled
          ? (value) {
              if (value == null) {
                return 'Please select $label.';
              }

              return null;
            }
          : null,
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}

// =================================================================
// QUESTION DRAFT
// =================================================================

class _QuestionDraft {
  final GlobalKey key = GlobalKey();

  final TextEditingController questionController = TextEditingController();

  final TextEditingController optionAController = TextEditingController();

  final TextEditingController optionBController = TextEditingController();

  final TextEditingController optionCController = TextEditingController();

  final TextEditingController optionDController = TextEditingController();

  final TextEditingController explanationController = TextEditingController();

  String correctAnswer = 'A';

  String? questionImageUrl;

  String? explanationImageUrl;

  void dispose() {
    questionController.dispose();
    optionAController.dispose();
    optionBController.dispose();
    optionCController.dispose();
    optionDController.dispose();
    explanationController.dispose();
  }
}
