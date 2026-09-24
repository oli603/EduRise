import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/theme/app_colors.dart';
import '../../coach/data/coach_service.dart';
import '../../profile/data/profile_service.dart';
import '../data/past_exam_model.dart';
import '../data/past_exam_service.dart';

class PredictedMockExamScreen extends StatefulWidget {
  const PredictedMockExamScreen({super.key});

  @override
  State<PredictedMockExamScreen> createState() => _PredictedMockExamScreenState();
}

class _PredictedMockExamScreenState extends State<PredictedMockExamScreen> {
  final CoachService _coachService = CoachService.instance;
  String _selectedStream = 'natural';
  String _selectedSubject = EduRiseSubjects.mathematics;
  bool _isLoading = false;

  final Map<String, List<String>> _streamSubjects = {
    'natural': EduRiseSubjects.naturalEntranceExam,
    'social': EduRiseSubjects.socialEntranceExam,
  };

  @override
  void initState() {
    super.initState();
    _loadProfileStream();
  }

  Future<void> _loadProfileStream() async {
    try {
      final profile = await ProfileService().getProfile();
      if (profile != null && profile.stream.isNotEmpty) {
        final canon = EduRiseSubjects.canonicalizeStream(profile.stream);
        if (mounted) {
          setState(() {
            _selectedStream = canon;
            final subjects = _streamSubjects[_selectedStream] ?? [];
            if (!subjects.contains(_selectedSubject)) {
              _selectedSubject = subjects.isNotEmpty ? subjects.first : EduRiseSubjects.mathematics;
            }
          });
        }
      }
    } catch (_) {}
  }

  // Curated Blueprint Weightings from historical 2013-2018 EC Entrance Exams
  final Map<String, List<Map<String, dynamic>>> _blueprints = {
    EduRiseSubjects.mathematics: [
      {'topic': 'Calculus & Limits (Grade 12)', 'weight': '32%', 'importance': 'High'},
      {'topic': 'Vectors & Matrices (Grade 11-12)', 'weight': '24%', 'importance': 'High'},
      {'topic': 'Coordinate Geometry & Trigonometry', 'weight': '22%', 'importance': 'Medium'},
      {'topic': 'Statistics & Probability', 'weight': '12%', 'importance': 'Medium'},
      {'topic': 'Sequences & Series', 'weight': '10%', 'importance': 'Medium'},
    ],
    EduRiseSubjects.physics: [
      {'topic': 'Electromagnetism & Circuits', 'weight': '28%', 'importance': 'High'},
      {'topic': 'Mechanics & Dynamics', 'weight': '26%', 'importance': 'High'},
      {'topic': 'Thermodynamics & Heat', 'weight': '18%', 'importance': 'Medium'},
      {'topic': 'Wave Optics & Sound', 'weight': '16%', 'importance': 'Medium'},
      {'topic': 'Atomic & Modern Physics', 'weight': '12%', 'importance': 'Medium'},
    ],
    EduRiseSubjects.chemistry: [
      {'topic': 'Organic Chemistry & Reaction Mechanisms', 'weight': '30%', 'importance': 'High'},
      {'topic': 'Chemical Equilibrium & Kinetics', 'weight': '25%', 'importance': 'High'},
      {'topic': 'Electrochemistry & Redox', 'weight': '20%', 'importance': 'Medium'},
      {'topic': 'Atomic Structure & Periodic Table', 'weight': '15%', 'importance': 'Medium'},
      {'topic': 'Environmental & Industrial Chemistry', 'weight': '10%', 'importance': 'Medium'},
    ],
    EduRiseSubjects.biology: [
      {'topic': 'Genetics & Molecular Biology', 'weight': '28%', 'importance': 'High'},
      {'topic': 'Cell Physiology & Energy (Respiration/Photosynthesis)', 'weight': '26%', 'importance': 'High'},
      {'topic': 'Human Anatomy & Organ Systems', 'weight': '22%', 'importance': 'Medium'},
      {'topic': 'Ecology & Environmental Biology', 'weight': '14%', 'importance': 'Medium'},
      {'topic': 'Evolution & Microorganisms', 'weight': '10%', 'importance': 'Medium'},
    ],
    EduRiseSubjects.english: [
      {'topic': 'Reading Comprehension & Contextual Inference', 'weight': '35%', 'importance': 'High'},
      {'topic': 'Grammar & Sentence Structures', 'weight': '30%', 'importance': 'High'},
      {'topic': 'Vocabulary in Context & Antonyms/Synonyms', 'weight': '20%', 'importance': 'Medium'},
      {'topic': 'Paragraph Organization & Writing Skills', 'weight': '15%', 'importance': 'Medium'},
    ],
    EduRiseSubjects.satSubject: [
      {'topic': 'Logical & Analytical Reasoning', 'weight': '35%', 'importance': 'High'},
      {'topic': 'Quantitative & Numerical Ability', 'weight': '35%', 'importance': 'High'},
      {'topic': 'Verbal Reasoning & Analogies', 'weight': '30%', 'importance': 'High'},
    ],
    EduRiseSubjects.history: [
      {'topic': 'Modern Ethiopian History (19th-20th Century)', 'weight': '35%', 'importance': 'High'},
      {'topic': 'Ancient & Medieval Ethiopia', 'weight': '25%', 'importance': 'Medium'},
      {'topic': 'World Wars & Global History', 'weight': '25%', 'importance': 'Medium'},
      {'topic': 'African Decolonization & Pan-Africanism', 'weight': '15%', 'importance': 'Medium'},
    ],
    EduRiseSubjects.geography: [
      {'topic': 'Physical Geography of Ethiopia & Horn of Africa', 'weight': '35%', 'importance': 'High'},
      {'topic': 'Economic & Population Geography', 'weight': '30%', 'importance': 'High'},
      {'topic': 'Map Reading & GIS Fundamentals', 'weight': '20%', 'importance': 'Medium'},
      {'topic': 'Environmental Issues & Climatology', 'weight': '15%', 'importance': 'Medium'},
    ],
    EduRiseSubjects.economics: [
      {'topic': 'Microeconomics (Supply, Demand, Elasticity)', 'weight': '35%', 'importance': 'High'},
      {'topic': 'Macroeconomics (National Income, Inflation)', 'weight': '35%', 'importance': 'High'},
      {'topic': 'Ethiopian Economic Development & Policies', 'weight': '20%', 'importance': 'Medium'},
      {'topic': 'International Trade & Finance', 'weight': '10%', 'importance': 'Medium'},
    ],
  };

  Future<void> _startMockExam() async {
    setState(() {
      _isLoading = true;
    });

    final canonicalSub = EduRiseSubjects.canonicalize(_selectedSubject);
    final targetQuestionCount = EduRiseSubjects.getEntranceExamQuestionCount(canonicalSub);
    final targetDurationMinutes = EduRiseSubjects.getEntranceExamDuration(canonicalSub).inMinutes;

    try {
      final res = await _coachService.getPredictedMockExam(
        subject: canonicalSub,
        stream: _selectedStream,
        questionCount: targetQuestionCount,
        durationMinutes: targetDurationMinutes,
      );

      final qList = (res['questions'] as List<dynamic>?) ?? [];
      final pastQuestions = qList.map((q) {
        final qMap = Map<String, dynamic>.from(q as Map);
        final opts = Map<String, dynamic>.from(qMap['options'] as Map? ?? {});
        return PastExamQuestion(
          id: qMap['id']?.toString() ?? 'mock_${DateTime.now().millisecondsSinceEpoch}',
          questionNumber: (qMap['question_number'] as num?)?.toInt() ?? 1,
          questionText: qMap['question_text']?.toString() ?? '',
          optionA: opts['A']?.toString() ?? '',
          optionB: opts['B']?.toString() ?? '',
          optionC: opts['C']?.toString() ?? '',
          optionD: opts['D']?.toString() ?? '',
          correctAnswer: qMap['correct_answer']?.toString() ?? 'A',
          explanation: qMap['explanation']?.toString() ?? '',
        );
      }).toList();

      final mockExam = PastExam(
        id: 'mock_${canonicalSub.toLowerCase()}_${_selectedStream}_2018',
        year: '2018 Predicted Mock',
        stream: _selectedStream,
        subject: canonicalSub,
        durationMinutes: targetDurationMinutes,
        questions: pastQuestions,
      );

      // Save mock exam to local past exam cache so the standard ExamScreen engine works offline seamlessly
      PastExamService().injectMockExam(mockExam);

      if (mounted) {
        setState(() => _isLoading = false);

        context.push(
          '/past-entrance-exams/instructions?year=2018+Predicted&stream=$_selectedStream&subject=${Uri.encodeComponent(canonicalSub)}&round=Mock+Blueprint&questionCount=$targetQuestionCount&durationMinutes=$targetDurationMinutes',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load mock exam: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final availableSubjects = _streamSubjects[_selectedStream] ?? [];
    if (!availableSubjects.contains(_selectedSubject)) {
      _selectedSubject = availableSubjects.isNotEmpty ? availableSubjects.first : EduRiseSubjects.mathematics;
    }

    final currentBlueprint = _blueprints[_selectedSubject] ?? [];
    final targetQuestionCount = EduRiseSubjects.getEntranceExamQuestionCount(_selectedSubject);
    final targetDurationMinutes = EduRiseSubjects.getEntranceExamDuration(_selectedSubject).inMinutes;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Predicted Mock Exam'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandDarkBlue, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandDarkBlue.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'AI Blueprint Prediction',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Synthesized from 2013–2018 E.C. Ethiopian National University Entrance Examinations to simulate real exam pressure and weightings.',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Authoritative Stream Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedStream == 'social' ? Icons.public_rounded : Icons.science_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enrolled Stream',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                    Text(
                      EduRiseSubjects.displayStream(_selectedStream),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Subject Grid
          Text(
            'Select Subject',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableSubjects.map((sub) {
              final isSelected = _selectedSubject == sub;
              return ChoiceChip(
                label: Text(sub),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedSubject = sub);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Blueprint Analysis Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_selectedSubject National Exam Blueprint',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Historical Topic Distribution (2013 - 2018 EC)',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 14),
                ...currentBlueprint.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['topic'] as String,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['weight'] as String,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Exam Specification Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.quiz_outlined, color: AppColors.primary),
                      const SizedBox(height: 4),
                      const Text(
                        'Blueprint',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                      ),
                      Text(
                        '$targetQuestionCount Qs',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.primary),
                      const SizedBox(height: 4),
                      const Text(
                        'Simulation',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                      ),
                      Text(
                        '$targetDurationMinutes Mins',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
                      const SizedBox(height: 4),
                      const Text(
                        'AI Review',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                      ),
                      Text(
                        'Deep Analysis',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Start Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startMockExam,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _isLoading ? 'Preparing Mock Exam...' : 'Start $_selectedSubject Mock Exam ($targetQuestionCount Qs)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
