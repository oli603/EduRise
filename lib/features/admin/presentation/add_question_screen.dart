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

  final _unitNumberController = TextEditingController();
  final _unitNameController = TextEditingController();
  final _examYearController = TextEditingController();

  final QuestionService _questionService = QuestionService();

  String _selectedGrade = 'Grade 12';
  String _selectedSubject = 'Mathematics';
  String _selectedExamType = 'Entrance Exam';

  bool _isSaving = false;

  final List<_QuestionDraft> _questions = [_QuestionDraft()];

  @override
  void dispose() {
    _unitNumberController.dispose();
    _unitNameController.dispose();
    _examYearController.dispose();

    for (final question in _questions) {
      question.dispose();
    }

    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_QuestionDraft());
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length == 1) {
      return;
    }

    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  Future<void> _saveAllQuestions() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final questions = <Question>[];

      for (int i = 0; i < _questions.length; i++) {
        final draft = _questions[i];

        final question = Question(
          id: '',
          grade: _selectedGrade,
          subject: _selectedSubject,
          unitNumber: int.parse(_unitNumberController.text.trim()),
          unitName: _unitNameController.text.trim(),

          questionNumber: i + 1,

          question: draft.questionController.text.trim(),

          options: [
            draft.optionAController.text.trim(),
            draft.optionBController.text.trim(),
            draft.optionCController.text.trim(),
            draft.optionDController.text.trim(),
          ],

          correctAnswer: draft.correctAnswer,

          explanation: draft.explanationController.text.trim(),

          examYear: int.parse(_examYearController.text.trim()),

          examType: _selectedExamType,

          status: 'published',

          createdAt: null,
        );

        questions.add(question);
      }

      await _questionService.addQuestions(questions);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${questions.length} questions added successfully! 🎉'),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('BATCH QUESTION ERROR: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save questions. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    if (int.tryParse(value.trim()) == null) {
      return 'Enter a valid number.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Questions')),
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
                'Add multiple verified questions at once.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),

              const SizedBox(height: 28),

              _sectionTitle('Exam Information'),

              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Grade',
                value: _selectedGrade,
                items: const ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'],
                onChanged: (value) {
                  setState(() {
                    _selectedGrade = value!;
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Subject',
                value: _selectedSubject,
                items: const [
                  'Mathematics',
                  'Physics',
                  'Chemistry',
                  'Biology',
                  'English',
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSubject = value!;
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildTextField(
                controller: _unitNumberController,
                label: 'Unit Number',
                hint: 'Example: 1',
                keyboardType: TextInputType.number,
                validator: _numberValidator,
              ),

              const SizedBox(height: 14),

              _buildTextField(
                controller: _unitNameController,
                label: 'Unit Name',
                hint: 'Example: Sets',
                validator: _requiredValidator,
              ),

              const SizedBox(height: 14),

              _buildTextField(
                controller: _examYearController,
                label: 'Exam Year',
                hint: 'Example: 2024',
                keyboardType: TextInputType.number,
                validator: _numberValidator,
              ),

              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Exam Type',
                value: _selectedExamType,
                items: const [
                  'Entrance Exam',
                  'Model Exam',
                  'School Exam',
                  'Mock Exam',
                  'Other',
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedExamType = value!;
                  });
                },
              ),

              const SizedBox(height: 32),

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

              ...List.generate(_questions.length, (index) {
                return _buildQuestionCard(index, _questions[index]);
              }),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _isSaving ? null : _addQuestion,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Another Question'),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAllQuestions,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Save All Questions'),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, _QuestionDraft draft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      // ignore: deprecated_member_use
                      .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),

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
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Remove question',
                ),
            ],
          ),

          const SizedBox(height: 18),

          _buildTextField(
            controller: draft.questionController,
            label: 'Question',
            hint: 'Enter the question...',
            maxLines: 4,
            validator: _requiredValidator,
          ),

          const SizedBox(height: 14),

          _buildTextField(
            controller: draft.optionAController,
            label: 'Option A',
            hint: 'Enter option A',
            validator: _requiredValidator,
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller: draft.optionBController,
            label: 'Option B',
            hint: 'Enter option B',
            validator: _requiredValidator,
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller: draft.optionCController,
            label: 'Option C',
            hint: 'Enter option C',
            validator: _requiredValidator,
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller: draft.optionDController,
            label: 'Option D',
            hint: 'Enter option D',
            validator: _requiredValidator,
          ),

          const SizedBox(height: 16),

          _buildDropdown(
            label: 'Correct Answer',
            value: draft.correctAnswer,
            items: const ['A', 'B', 'C', 'D'],
            onChanged: (value) {
              setState(() {
                draft.correctAnswer = value!;
              });
            },
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: draft.explanationController,
            label: 'Explanation',
            hint: 'Explain why the correct answer is correct...',
            maxLines: 5,
            validator: _requiredValidator,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _QuestionDraft {
  final questionController = TextEditingController();

  final optionAController = TextEditingController();

  final optionBController = TextEditingController();

  final optionCController = TextEditingController();

  final optionDController = TextEditingController();

  final explanationController = TextEditingController();

  String correctAnswer = 'A';

  void dispose() {
    questionController.dispose();
    optionAController.dispose();
    optionBController.dispose();
    optionCController.dispose();
    optionDController.dispose();
    explanationController.dispose();
  }
}
