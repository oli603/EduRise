import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../coach/data/coach_service.dart';
import '../data/book_model.dart';
import '../data/book_text_service.dart';

class UnitFlashcardsScreen extends StatefulWidget {
  final BookUnit unit;

  const UnitFlashcardsScreen({super.key, required this.unit});

  @override
  State<UnitFlashcardsScreen> createState() => _UnitFlashcardsScreenState();
}

class _UnitFlashcardsScreenState extends State<UnitFlashcardsScreen> {
  final CoachService _coachService = CoachService.instance;
  final BookTextService _textService = BookTextService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _flashcards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentIndex = 0;
      _isFlipped = false;
    });

    try {
      final textResult = await _textService.getUnitText(widget.unit);
      final contextWindow = textResult.hasUsableText
          ? _textService.prepareContextWindow(textResult.text)
          : null;

      final res = await _coachService.getUnitFlashcards(
        bookId: widget.unit.id,
        unitId: 'unit_${widget.unit.unitNumber}',
        unitTitle: widget.unit.unitName,
        subject: widget.unit.subject,
        grade: widget.unit.grade,
        unitNumber: widget.unit.unitNumber,
        unitContent: contextWindow,
        forceRefresh: forceRefresh,
      );

      final cards = (res['flashcards'] as List<dynamic>?) ?? [];
      final parsed = cards.map((c) => Map<String, dynamic>.from(c as Map)).toList();

      if (mounted) {
        setState(() {
          _flashcards = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _nextCard() {
    if (_currentIndex < _flashcards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  void _shuffleCards() {
    setState(() {
      _flashcards.shuffle();
      _currentIndex = 0;
      _isFlipped = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deck shuffled!'), duration: Duration(milliseconds: 900)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.eduColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Unit ${widget.unit.unitNumber} Flashcards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: 'Shuffle',
            onPressed: _flashcards.isNotEmpty ? _shuffleCards : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Regenerate',
            onPressed: () => _loadFlashcards(forceRefresh: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Creating Interactive Flashcards...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.eduColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Formulating active recall questions & answers',
              style: TextStyle(color: context.eduColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadFlashcards(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_flashcards.isEmpty) {
      return const Center(child: Text('No flashcards available for this unit.'));
    }

    final card = _flashcards[_currentIndex];
    final front = (card['front'] ?? card['question'] ?? '').toString();
    final back = (card['back'] ?? card['answer'] ?? '').toString();
    final category = (card['category'] ?? 'Core Concept').toString();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress & Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Card ${_currentIndex + 1} of ${_flashcards.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  category,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _flashcards.length,
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 24),

          // Flip Card Area
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isFlipped = !_isFlipped;
                });
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  final rotate = Tween(begin: pi, end: 0.0).animate(animation);
                  return AnimatedBuilder(
                    animation: rotate,
                    child: child,
                    builder: (context, child) {
                      final isUnder = (ValueKey(_isFlipped) != child?.key);
                      var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.002;
                      tilt *= isUnder ? -1.0 : 1.0;
                      final value = isUnder ? min(rotate.value, pi / 2) : rotate.value;
                      return Transform(
                        transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                  );
                },
                child: _isFlipped
                    ? _buildCardSide(
                        key: const ValueKey(true),
                        label: 'ANSWER / EXPLANATION',
                        text: back,
                        isFront: false,
                      )
                    : _buildCardSide(
                        key: const ValueKey(false),
                        label: 'QUESTION / TERM',
                        text: front,
                        isFront: true,
                      ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Navigation Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentIndex > 0 ? _previousCard : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _currentIndex < _flashcards.length - 1 ? _nextCard : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap card to flip • Active recall strengthens exam memory',
            style: TextStyle(fontSize: 12, color: context.eduColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSide({
    required Key key,
    required String label,
    required String text,
    required bool isFront,
  }) {
    final colors = context.eduColors;
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isFront
            ? colors.cardBackground
            : (colors.isDark
                ? colors.primary.withValues(alpha: 0.15)
                : colors.primary.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFront ? colors.border : colors.primary.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: isFront ? colors.textSecondary : colors.primary,
                ),
              ),
              Icon(
                Icons.touch_app_rounded,
                size: 18,
                color: colors.textMuted,
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isFront ? 22 : 18,
                    fontWeight: isFront ? FontWeight.bold : FontWeight.w500,
                    height: 1.5,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Text(
            isFront ? 'Tap to reveal answer' : 'Tap to see question',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
