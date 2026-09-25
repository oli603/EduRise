import 'package:flutter/material.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/data/profile_service.dart';
import '../data/coach_service.dart';

class CoachChatScreen extends StatefulWidget {
  final String? initialSubject;
  final String? initialGrade;

  const CoachChatScreen({
    super.key,
    this.initialSubject,
    this.initialGrade,
  });

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  final CoachService _coachService = CoachService.instance;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String? _selectedSubject;
  String _stream = 'natural';
  Map<String, dynamic>? _quotaStatus;

  final List<String> _quickPrompts = const [
    "How to prepare for Ethiopian Entrance Exam?",
    "Explain Newton's laws of motion with everyday examples",
    "What are the most frequent topics in Grade 12 Maths national exams?",
    "How do I solve dimensional analysis problems in Physics?",
    "Give me active recall techniques for Biology diagrams",
  ];

  List<String> get _subjects {
    final streamSubs = EduRiseSubjects.getPracticeSubjects(stream: _stream);
    return ['All Subjects', ...streamSubs];
  }

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.initialSubject ?? 'All Subjects';
    _loadStatus();
    // Initial welcome message from EduRise Coach
    _messages.add({
      'role': 'assistant',
      'content':
          'Hello! I am your **EduRise AI Coach**, tailored specifically for the Ethiopian Secondary and National Entrance Examination curriculum.\n\nAsk me any concept explanation, exam strategy question, or clarification from your textbooks!',
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final profile = await ProfileService().getProfile();
      if (profile != null && profile.stream.isNotEmpty) {
        _stream = EduRiseSubjects.canonicalizeStream(profile.stream);
      }
    } catch (_) {}

    try {
      final status = await _coachService.getCoachStatus();
      if (mounted) {
        setState(() {
          _quotaStatus = status;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (quickText == null) {
      _inputController.clear();
    }

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Build history excluding the very first assistant greeting
      final history = _messages
          .skip(1)
          .take(_messages.length - 2)
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();

      final res = await _coachService.sendCoachChat(
        message: text,
        history: history,
        subject: _selectedSubject == 'All Subjects' ? null : _selectedSubject,
        grade: widget.initialGrade,
      );

      final reply = res['reply'] as String? ?? 'I am here to help you study.';
      final quota = res['quota'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
          _isLoading = false;
          if (quota != null) {
            _quotaStatus = quota;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '⚠️ ${e.toString()}',
          });
          _isLoading = false;
        });
      }
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EduRise Coach',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'Ethiopian Curriculum Tutor',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_quotaStatus != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${_quotaStatus!['quota_remaining'] ?? 0} Left Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Subject Filter Selector
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final sub = _subjects[index];
                final isSelected = _selectedSubject == sub;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      sub,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : colors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colors.primary,
                    checkmarkColor: Colors.white,
                    backgroundColor: colors.surfaceSubtle,
                    side: BorderSide(color: colors.border),
                    onSelected: (val) {
                      setState(() {
                        _selectedSubject = sub;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          Divider(height: 1, color: colors.border),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final content = msg['content'] ?? '';

                return _buildMessageBubble(content: content, isUser: isUser);
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'EduRise Coach is thinking...',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),

          // Suggested quick prompts when 1 message
          if (_messages.length <= 1)
            Container(
              height: 42,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickPrompts.length,
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: colors.surfaceSubtle,
                      side: BorderSide(color: colors.border),
                      label: Text(
                        prompt,
                        style: TextStyle(fontSize: 12, color: colors.textPrimary),
                      ),
                      onPressed: () => _sendMessage(prompt),
                    ),
                  );
                },
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.eduColors.cardBackground,
              border: Border(top: BorderSide(color: context.eduColors.border)),
              boxShadow: [
                BoxShadow(
                  color: context.eduColors.isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      style: TextStyle(fontSize: 14, color: context.eduColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ask your coach any question...',
                        hintStyle: TextStyle(fontSize: 14, color: context.eduColors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: context.eduColors.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.eduColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.eduColors.border),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: context.eduColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String content, required bool isUser}) {
    final colors = context.eduColors;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? colors.primary : colors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'EduRise Coach',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isUser ? Colors.white : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
