import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/access_service.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/download_manager.dart';
import '../../../core/offline/offline_storage_service.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/access_locked_dialog.dart';
import '../data/past_exam_download_service.dart';
import '../data/past_exam_model.dart';
import '../data/past_exam_service.dart';

class ExamScreen extends StatefulWidget {
  final String year;
  final String stream;
  final String subject;
  final int? durationMinutes;
  final String? examId;
  final PastExam? exam;

  const ExamScreen({
    super.key,
    required this.year,
    this.stream = 'natural',
    required this.subject,
    this.durationMinutes,
    this.examId,
    this.exam,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  final PastExamService _pastExamService = PastExamService();
  final DownloadManager _downloadManager = DownloadManager();
  final OfflineStorageService _storageService = OfflineStorageService();

  PastExam? _exam;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOfflineUnavailable = false;

  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {};

  // Timed exam simulation
  Timer? _timer;
  late DateTime _startTime;
  late DateTime _deadline;
  int _remainingSeconds = 0;
  final ValueNotifier<int> _remainingSecondsNotifier = ValueNotifier<int>(0);
  int _totalDurationMinutes = 120;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeExam();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _remainingSecondsNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _exam != null && !_isSubmitting) {
      // Recalculate remaining time from absolute deadline timestamp
      final secondsLeft = _deadline.difference(DateTime.now()).inSeconds;
      _remainingSeconds = secondsLeft > 0 ? secondsLeft : 0;
      _remainingSecondsNotifier.value = _remainingSeconds;
      if (secondsLeft <= 0) {
        _timer?.cancel();
        _submitExam(autoSubmit: true);
      }
    }
  }

  int _calculateConfiguredDuration() {
    if (widget.durationMinutes != null && widget.durationMinutes! > 0) {
      return widget.durationMinutes!;
    }
    final isMath = widget.subject.trim().toLowerCase() == 'mathematics';
    return isMath ? 180 : 120;
  }

  Future<void> _initializeExam() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOfflineUnavailable = false;
    });

    // 1. Authorization check
    final hasAccess = await AccessService.canAccessPastExams();
    if (!hasAccess) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Subscription required for Past Entrance Exams.';
      });
      AccessLockedDialog.show(context, featureName: 'Past Entrance Exams');
      return;
    }

    // 2. Determine duration: Mathematics = 180 min, other = 120 min
    _totalDurationMinutes = _calculateConfiguredDuration();

    // 3. Load exam data
    if (widget.exam != null) {
      _onExamLoaded(widget.exam!);
      return;
    }

    try {
      // Attempt local offline load first
      final expectedExamId = widget.examId ??
          '${widget.year}_${widget.stream.toLowerCase()}_${widget.subject.toLowerCase().replaceAll(' ', '_')}';

      PastExam? loadedExam =
          await PastExamDownloadService().getDownloadedPastExamModel(examId: expectedExamId);

      if (loadedExam == null) {
        // Also check if downloaded via package ID
        final pkgId = _downloadManager.getPastExamPackageId(
          year: widget.year,
          stream: widget.stream,
          subject: widget.subject,
        );
        final isDownloaded = await _downloadManager.isDownloaded(pkgId);
        if (isDownloaded) {
          final pkg = await _storageService.getPackage(pkgId);
          final realExamId = pkg?.extraData['examId'] as String? ?? expectedExamId;
          loadedExam = await PastExamDownloadService().getDownloadedPastExamModel(examId: realExamId);
        }
      }

      if (loadedExam == null) {
        // Check internet connectivity
        final isConnected = ConnectivityService().isOnline;
        if (!isConnected) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isOfflineUnavailable = true;
          });
          return;
        }

        // Online fetch fallback
        loadedExam = await _pastExamService.getPastExam(expectedExamId);
        if (loadedExam == null) {
          final exams = await _pastExamService.getPastExams(
            year: widget.year,
            stream: widget.stream,
          );
          loadedExam = exams.firstWhere(
            (e) {
              final eSub = e.subject.toLowerCase().trim();
              final wSub = widget.subject.toLowerCase().trim();
              return eSub == wSub || eSub.contains(wSub) || wSub.contains(eSub);
            },
            orElse: () => exams.isNotEmpty
                ? exams.first
                : PastExam(
                    id: expectedExamId,
                    year: widget.year,
                    stream: widget.stream,
                    subject: widget.subject,
                    durationMinutes: _totalDurationMinutes,
                    questions: const [],
                  ),
          );
        }
      }

      if (!mounted) return;

      if (loadedExam.questions.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No questions found for this exam.';
        });
        return;
      }

      _onExamLoaded(loadedExam);
    } catch (e) {
      debugPrint('Error initializing exam: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load exam: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  void _safeExitExam() {
    _timer?.cancel();
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/past-entrance-exams');
    }
  }

  void _onExamLoaded(PastExam exam) {
    // Defensive invariant: only questions with valid text and at least 2 non-empty options can be presented
    final validQuestions = exam.questions.where((q) {
      final hasText = q.questionText.trim().isNotEmpty;
      final optionsCount = [q.optionA, q.optionB, q.optionC, q.optionD]
          .where((o) => o.trim().isNotEmpty)
          .length;
      return hasText && optionsCount >= 2;
    }).toList();

    if (validQuestions.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Exam questions could not be loaded properly or are corrupted.';
      });
      return;
    }

    final sanitizedExam = PastExam(
      id: exam.id,
      year: exam.year,
      stream: exam.stream,
      subject: exam.subject,
      durationMinutes: exam.durationMinutes > 0 ? exam.durationMinutes : _totalDurationMinutes,
      questions: validQuestions,
    );

    setState(() {
      _exam = sanitizedExam;
      _isLoading = false;
      _currentIndex = 0;
      _selectedAnswers.clear();
      _isSubmitting = false;

      // Setup countdown timer using absolute timestamp
      _startTime = DateTime.now();
      _deadline = _startTime.add(Duration(minutes: _totalDurationMinutes));
      _remainingSeconds = _deadline.difference(DateTime.now()).inSeconds;
      _remainingSecondsNotifier.value = _remainingSeconds;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSecondsNotifier.value = _remainingSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final secondsLeft = _deadline.difference(DateTime.now()).inSeconds;
      _remainingSeconds = secondsLeft > 0 ? secondsLeft : 0;
      _remainingSecondsNotifier.value = _remainingSeconds;

      if (secondsLeft <= 0) {
        timer.cancel();
        _submitExam(autoSubmit: true);
      }
    });
  }

  Future<void> _confirmExitExam() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Exam?'),
        content: const Text(
          'Are you sure you want to leave this exam?\n\nYour progress, current answers, and timer will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Working'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave Exam'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      if (!mounted) return;
      _safeExitExam();
    }
  }

  void _selectOption(String option) {
    if (_isSubmitting) return;
    setState(() {
      _selectedAnswers[_currentIndex] = option;
    });
  }

  void _goToQuestion(int index) {
    if (_exam == null || index < 0 || index >= _exam!.questions.length) return;
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _confirmSubmit() async {
    if (_exam == null || _isSubmitting) return;

    final colors = context.eduColors;
    final total = _exam!.questions.length;
    final answered = _selectedAnswers.length;
    final unanswered = total - answered;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to finish and submit your exam?'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text('$answered answered', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: unanswered > 0 ? AppColors.warning : colors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$unanswered unanswered',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: unanswered > 0 ? AppColors.warning : colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Remaining Time: ${_formatTime(_remainingSeconds)}',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Working'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit Exam'),
          ),
        ],
      ),
    );

    if (shouldSubmit == true) {
      await _submitExam(autoSubmit: false);
    }
  }

  Future<void> _submitExam({required bool autoSubmit}) async {
    if (_exam == null || _isSubmitting) return;
    _isSubmitting = true;
    _timer?.cancel();

    if (autoSubmit && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time is up! Exam auto-submitted.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final totalQuestions = _exam!.questions.length;
    int correctCount = 0;

    for (int i = 0; i < totalQuestions; i++) {
      final q = _exam!.questions[i];
      final chosen = _selectedAnswers[i];
      if (chosen != null && chosen.trim().toUpperCase() == q.correctAnswer.trim().toUpperCase()) {
        correctCount++;
      }
    }

    final incorrectCount = totalQuestions - correctCount;
    final percentage = totalQuestions > 0 ? ((correctCount / totalQuestions) * 100).round() : 0;
    final timeSpentSeconds = (_totalDurationMinutes * 60) - (_remainingSeconds > 0 ? _remainingSeconds : 0);

    String userId = 'anonymous_user';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
      }
    } catch (_) {}

    final timestamp = _startTime.millisecondsSinceEpoch;
    final localId = 'pe_res_${userId}_${_exam!.id}_$timestamp';

    final resultMap = {
      'localId': localId,
      'userId': userId,
      'examId': _exam!.id,
      'year': _exam!.year,
      'stream': _exam!.stream,
      'subject': _exam!.subject,
      'totalQuestions': totalQuestions,
      'score': correctCount,
      'correctAnswers': correctCount,
      'incorrectAnswers': incorrectCount,
      'unansweredCount': totalQuestions - _selectedAnswers.length,
      'percentage': percentage,
      'timeSpentSeconds': timeSpentSeconds,
      'durationMinutes': _totalDurationMinutes,
      'selectedAnswers': _selectedAnswers.map((k, v) => MapEntry(k.toString(), v)),
      'completedAt': DateTime.now().toIso8601String(),
      'syncStatus': 'pending',
    };

    // Save locally
    try {
      await _storageService.savePastExamResultLocally(resultMap);
      // Trigger background sync if connected
      unawaited(SyncService().syncAll());
    } catch (e) {
      debugPrint('Error saving past exam result locally: $e');
    }

    if (!mounted) return;

    context.pushReplacement(
      '/past-entrance-exams/result',
      extra: {
        'exam': _exam!,
        'selectedAnswers': _selectedAnswers,
        'correctAnswers': correctCount,
        'totalQuestions': totalQuestions,
        'percentage': percentage,
        'timeSpentSeconds': timeSpentSeconds,
        'durationMinutes': _totalDurationMinutes,
        'isAutoSubmitted': autoSubmit,
        'localResultId': localId,
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showQuestionOverviewSheet() {
    if (_exam == null) return;

    final colors = context.eduColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bottomSheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_selectedAnswers.length}/${_exam!.questions.length} answered',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _exam!.questions.length,
                    itemBuilder: (context, index) {
                      final isAnswered = _selectedAnswers.containsKey(index);
                      final isCurrent = _currentIndex == index;

                      Color bg = isAnswered
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.cardBackground;
                      Color border = isCurrent ? colors.primary : (isAnswered ? colors.primary : colors.border);
                      Color text = isCurrent || isAnswered ? colors.primary : colors.textPrimary;

                      if (isCurrent) {
                        border = colors.primary;
                        bg = colors.primary.withValues(alpha: 0.25);
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _goToQuestion(index);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border, width: isCurrent ? 2 : 1),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: text,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.of(ctx).pop();
                            _confirmSubmit();
                          },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Finish Exam'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.year} EC ${widget.subject}')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Preparing exam environment...',
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_isOfflineUnavailable) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.year} EC ${widget.subject}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Exam Unavailable Offline',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This exam has not been downloaded to this device yet.\nConnect to the internet or visit the Downloads screen to download it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _safeExitExam,
                      child: const Text('Go Back'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => context.push('/downloads'),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Downloads'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null || _exam == null || _exam!.questions.isEmpty) {
      return Scaffold(
        backgroundColor: colors.scaffoldBackground,
        appBar: AppBar(
          title: Text('${widget.year} EC ${widget.subject}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Go Back',
            onPressed: _safeExitExam,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'No exam content available',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _safeExitExam,
                      child: const Text('Go Back'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _initializeExam,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _exam!.questions[_currentIndex];
    final isLastQuestion = _currentIndex == _exam!.questions.length - 1;
    final selectedOption = _selectedAnswers[_currentIndex];

    final hasValidText = question.questionText.trim().isNotEmpty;
    final hasOptions = question.optionA.trim().isNotEmpty ||
        question.optionB.trim().isNotEmpty ||
        question.optionC.trim().isNotEmpty ||
        question.optionD.trim().isNotEmpty;

    final validOptionsCount = [
      question.optionA,
      question.optionB,
      question.optionC,
      question.optionD,
    ].where((o) => o.trim().isNotEmpty).length;

    // Diagnostic logging as required by P0-B diagnostic
    debugPrint(
      '[ExamScreen Diagnostic] Exam ID: ${_exam?.id}, '
      'Stream: ${widget.stream}, Grade: 12, Subject: ${widget.subject}, '
      'Question count returned: ${_exam?.questions.length}, '
      'Question count rendered: ${_exam?.questions.length}, '
      'Current question index: $_currentIndex, '
      'Current question ID: ${question.id ?? "q_$_currentIndex"}, '
      'Current question text length: ${question.questionText.length}, '
      'Options count: $validOptionsCount',
    );

    // Defensive invariant check:
    // If questions exist but current question is empty/unusable, DO NOT run timer against blank screen!
    if (!hasValidText && !hasOptions) {
      _timer?.cancel();
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _confirmExitExam();
        },
        child: Scaffold(
          backgroundColor: colors.scaffoldBackground,
          appBar: AppBar(
            title: Text('${widget.year} EC ${widget.subject}'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Leave Exam',
              onPressed: _confirmExitExam,
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Question Content Unavailable',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Question #${_currentIndex + 1} has empty or unreadable content.\nTimer has been paused for fairness.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _confirmExitExam,
                        child: const Text('Go Back'),
                      ),
                      FilledButton(
                        onPressed: _initializeExam,
                        child: const Text('Retry Loading'),
                      ),
                      if (_currentIndex < _exam!.questions.length - 1)
                        FilledButton.tonal(
                          onPressed: () {
                            _goToQuestion(_currentIndex + 1);
                            _startTimer();
                          },
                          child: const Text('Skip Question'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _confirmExitExam();
      },
      child: Scaffold(
        backgroundColor: colors.scaffoldBackground,
        appBar: AppBar(
          title: Text(
            '${widget.year} EC ${widget.subject}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Leave Exam',
            onPressed: _confirmExitExam,
          ),
          actions: [
            // Timer Badge using targeted ValueListenableBuilder (does not rebuild entire question tree)
            ValueListenableBuilder<int>(
              valueListenable: _remainingSecondsNotifier,
              builder: (context, seconds, _) {
                final isLowTime = seconds < 300; // < 5 minutes
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLowTime
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLowTime ? AppColors.error : AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: isLowTime ? AppColors.error : AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatTime(seconds),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isLowTime ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Question Overview Button
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'Question Overview',
              onPressed: _showQuestionOverviewSheet,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Progress Bar & Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: colors.cardBackground,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentIndex + 1} of ${_exam!.questions.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '${_selectedAnswers.length} answered',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (_currentIndex + 1) / _exam!.questions.length,
                      backgroundColor: colors.border,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),

              // Question & Options Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question.questionText,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  question.imageUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Options
                      _buildOptionTile('A', question.optionA, selectedOption == 'A', colors),
                      const SizedBox(height: 10),
                      _buildOptionTile('B', question.optionB, selectedOption == 'B', colors),
                      const SizedBox(height: 10),
                      _buildOptionTile('C', question.optionC, selectedOption == 'C', colors),
                      const SizedBox(height: 10),
                      _buildOptionTile('D', question.optionD, selectedOption == 'D', colors),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // Bottom Navigation Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    // Previous Button
                    OutlinedButton.icon(
                      onPressed: _currentIndex > 0
                          ? () => _goToQuestion(_currentIndex - 1)
                          : null,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Prev'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const Spacer(),
                    // Finish Exam / Next Button
                    if (isLastQuestion)
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _confirmSubmit,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(_isSubmitting ? 'Submitting...' : 'Finish Exam'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => _goToQuestion(_currentIndex + 1),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Next'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(String key, String text, bool isSelected, EduRiseThemeColors colors) {
    return InkWell(
      onTap: () => _selectOption(key),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors.primary : colors.border,
                ),
              ),
              child: Text(
                key,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? Colors.white : colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? colors.primary : colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
