import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../practice/data/models/question_package_model.dart';
import '../../practice/data/question_model.dart';
import '../../practice/data/question_service.dart';
import '../data/question_package_service.dart';

class AssignQuestionsScreen extends StatefulWidget {
  const AssignQuestionsScreen({required this.packageId, super.key});

  final String packageId;

  @override
  State<AssignQuestionsScreen> createState() => _AssignQuestionsScreenState();
}

class _AssignQuestionsScreenState extends State<AssignQuestionsScreen> {
  final _questionPackageService = QuestionPackageService();
  final _questionService = QuestionService();

  QuestionPackage? _package;
  List<Question> _questions = [];
  Set<String> _selectedQuestionIds = {};
  Set<String> _previouslyAssignedQuestionIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPackageAndQuestions();
  }

  Future<void> _loadPackageAndQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // --------------------------------------------
      // 1. Load package
      // --------------------------------------------

      final package = await _questionPackageService.getPackageById(
        widget.packageId,
      );

      if (package == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _package = null;
          _questions = [];
          _selectedQuestionIds = {};
          _previouslyAssignedQuestionIds = {};
          _isLoading = false;
        });

        return;
      }

      // --------------------------------------------
      // 2. Load questions matching package metadata
      // --------------------------------------------

      final questions = await _questionService.getQuestions(
        grade: package.grade,
        stream: package.stream,
        subject: package.subject,
        unitNumber: package.unitNumber,
      );

      // --------------------------------------------
      // 3. Find questions already assigned
      // --------------------------------------------

      final assignedQuestionIds = await _questionPackageService
          .getAssignedQuestionIds(package.packageId);

      // --------------------------------------------
      // 4. Make sure unit name also matches
      // --------------------------------------------

      final compatibleQuestions = questions
          .where((question) => question.unitName == package.unitName)
          .toList();

      // --------------------------------------------
      // 5. Get IDs of compatible questions
      // --------------------------------------------

      final compatibleQuestionIds = compatibleQuestions
          .map((question) => question.id)
          .toSet();

      // --------------------------------------------
      // 6. Select only assigned questions that are
      //    still compatible with this package
      // --------------------------------------------

      final selectedQuestionIds = assignedQuestionIds.intersection(
        compatibleQuestionIds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _package = package;

        _questions = compatibleQuestions;

        _selectedQuestionIds = selectedQuestionIds;

        _previouslyAssignedQuestionIds = selectedQuestionIds;

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('LOAD ASSIGNABLE QUESTIONS ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load questions for this package.';

        _isLoading = false;
      });
    }
  }

  Future<void> _saveAssignments() async {
    final package = _package;

    if (package == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _questionPackageService.saveQuestionAssignments(
        packageId: package.packageId,
        selectedQuestionIds: _selectedQuestionIds,
        previouslyAssignedQuestionIds: _previouslyAssignedQuestionIds,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question assignments saved successfully.'),
        ),
      );

      await _loadPackageAndQuestions();
    } catch (error) {
      debugPrint('SAVE QUESTION ASSIGNMENTS ERROR: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save question assignments. Please try again.',
          ),
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

  void _toggleQuestion(String questionId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedQuestionIds.add(questionId);
      } else {
        _selectedQuestionIds.remove(questionId);
      }
    });
  }

  void _safeBack() {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/admin/question-packages/${widget.packageId}');
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
          title: const Text('Assign Questions'),
        ),

        body: SafeArea(child: _buildBody()),

        bottomNavigationBar: _package == null || _isLoading
            ? null
            : SafeArea(
                minimum: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAssignments,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : 'Save ${_selectedQuestionIds.length} Questions',
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorState(
        message: _errorMessage!,
        onRetry: _loadPackageAndQuestions,
      );
    }

    final package = _package;

    if (package == null) {
      return const _MessageState(message: 'Package not found.');
    }

    if (_questions.isEmpty) {
      return const _MessageState(
        message: 'No published questions match this package.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPackageAndQuestions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _questions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${package.grade} - ${package.subject}\n'
                'Unit ${package.unitNumber}: ${package.unitName}\n'
                'Selected: ${_selectedQuestionIds.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }

          final question = _questions[index - 1];

          final isSelected = _selectedQuestionIds.contains(question.id);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: CheckboxListTile(
              value: isSelected,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      _toggleQuestion(question.id, value ?? false);
                    },
              title: Text('Question ${question.questionNumber}'),
              subtitle: Text(
                question.question,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          );
        },
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
