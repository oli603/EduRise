import 'package:flutter/material.dart';

import 'package:edurise/features/past_entrance_exams/data/past_exam_model.dart';

import 'package:edurise/features/past_entrance_exams/data/past_exam_service.dart';

class PastExamQuestionEditorScreen extends StatefulWidget {
  final String year;
  final String stream;
  final String? round;
  final String subject;
  final String duration;

  const PastExamQuestionEditorScreen({
    super.key,
    required this.year,
    required this.stream,
    required this.round,
    required this.subject,
    required this.duration,
  });

  @override
  State<PastExamQuestionEditorScreen> createState() =>
      _PastExamQuestionEditorScreenState();
}

class _PastExamQuestionEditorScreenState
    extends State<PastExamQuestionEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  final PastExamService _pastExamService = PastExamService();

  final _questionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  final _explanationController = TextEditingController();

  String? _correctAnswer;

  bool _isSaving = false;
  bool _hasSaved = false;

  final List<Map<String, dynamic>> _questions = [];

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    _explanationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Exam Questions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildExamInfo(),

              const SizedBox(height: 24),

              _buildQuestionCounter(),

              const SizedBox(height: 32),

              const Text(
                'Question',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              _buildTextField(
                controller: _questionController,
                label: 'Question text',
                hint: 'Enter the question',
                maxLines: 5,
              ),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _addQuestionImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Add Image (Optional)'),
              ),

              const SizedBox(height: 32),

              const Text(
                'Answer Options',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _optionAController,
                label: 'Option A',
                hint: 'Enter option A',
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _optionBController,
                label: 'Option B',
                hint: 'Enter option B',
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _optionCController,
                label: 'Option C',
                hint: 'Enter option C',
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _optionDController,
                label: 'Option D',
                hint: 'Enter option D',
              ),

              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                initialValue: _correctAnswer,
                decoration: const InputDecoration(
                  labelText: 'Correct Answer',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('Option A')),
                  DropdownMenuItem(value: 'B', child: Text('Option B')),
                  DropdownMenuItem(value: 'C', child: Text('Option C')),
                  DropdownMenuItem(value: 'D', child: Text('Option D')),
                ],
                onChanged: (value) {
                  setState(() {
                    _correctAnswer = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select the correct answer.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 32),

              const Text(
                'Explanation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              _buildTextField(
                controller: _explanationController,
                label: 'Explanation',
                hint: 'Explain why this answer is correct',
                maxLines: 5,
              ),

              const SizedBox(height: 40),

              // --------------------------------------------------
              // ADD QUESTION
              // --------------------------------------------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // SAVE ALL QUESTIONS
              // --------------------------------------------------
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving || _questions.isEmpty
                      ? null
                      : _saveQuestions,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : 'Save Questions (${_questions.length})',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // FINISH
              // --------------------------------------------------
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _hasSaved ? _finish : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Finish'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // EXAM INFORMATION
  // ==============================================================

  Widget _buildExamInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exam Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _infoRow('Year', widget.year),
            _infoRow('Stream', widget.stream),

            if (widget.round != null) _infoRow('Round', widget.round!),

            _infoRow('Subject', widget.subject),
            _infoRow('Duration', widget.duration),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // QUESTION COUNTER
  // ==============================================================

  Widget _buildQuestionCounter() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.quiz_outlined),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                'Questions added: ${_questions.length}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // TEXT FIELD
  // ==============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required.';
        }

        return null;
      },
    );
  }

  // ==============================================================
  // INFO ROW
  // ==============================================================

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ==============================================================
  // IMAGE
  // ==============================================================

  void _addQuestionImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image upload will be connected next.')),
    );
  }

  // ==============================================================
  // ADD QUESTION TO TEMPORARY LIST
  // ==============================================================

  void _addQuestion() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final question = {
      'questionNumber': _questions.length + 1,
      'questionText': _questionController.text.trim(),
      'optionA': _optionAController.text.trim(),
      'optionB': _optionBController.text.trim(),
      'optionC': _optionCController.text.trim(),
      'optionD': _optionDController.text.trim(),
      'correctAnswer': _correctAnswer!,
      'explanation': _explanationController.text.trim(),
      'imageUrl': null,
    };

    setState(() {
      _questions.add(question);
      _hasSaved = false;
    });

    _clearQuestionForm();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Question ${_questions.length} added successfully.'),
      ),
    );
  }

  // ==============================================================
  // CLEAR FORM
  // ==============================================================

  void _clearQuestionForm() {
    _questionController.clear();
    _optionAController.clear();
    _optionBController.clear();
    _optionCController.clear();
    _optionDController.clear();
    _explanationController.clear();

    setState(() {
      _correctAnswer = null;
    });
  }

  // ==============================================================
  // DURATION
  // ==============================================================

  int _durationToMinutes() {
    if (widget.duration == '3 hours') {
      return 180;
    }

    return 120;
  }

  // ==============================================================
  // CREATE EXAM ID
  // ==============================================================

  String _buildExamId() {
    final year = widget.year.replaceAll(' ', '_');
    final stream = widget.stream.replaceAll(' ', '_');
    final subject = widget.subject.replaceAll(' ', '_');

    if (widget.round != null) {
      final round = widget.round!.replaceAll(' ', '_');

      return '${year}_${stream}_${subject}_$round';
    }

    return '${year}_${stream}_$subject';
  }

  // ==============================================================
  // SAVE COMPLETE EXAM TO FIRESTORE
  // ==============================================================

  Future<void> _saveQuestions() async {
    if (_questions.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final questions = _questions.map((question) {
        return PastExamQuestion(
          questionNumber: question['questionNumber'] as int,
          questionText: question['questionText'] as String,
          imageUrl: question['imageUrl'] as String?,
          optionA: question['optionA'] as String,
          optionB: question['optionB'] as String,
          optionC: question['optionC'] as String,
          optionD: question['optionD'] as String,
          correctAnswer: question['correctAnswer'] as String,
          explanation: question['explanation'] as String,
        );
      }).toList();

      final exam = PastExam(
        id: _buildExamId(),
        year: widget.year,
        stream: widget.stream,
        round: widget.round,
        subject: widget.subject,
        durationMinutes: _durationToMinutes(),
        questions: questions,
      );

      await _pastExamService.savePastExam(exam);

      if (!mounted) return;

      setState(() {
        _hasSaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_questions.length} questions saved successfully to Firestore.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save questions: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ==============================================================
  // FINISH
  // ==============================================================

  void _finish() {
    Navigator.of(context).pop();
  }
}
