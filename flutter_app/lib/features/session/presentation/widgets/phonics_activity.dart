import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/pronunciation/presentation/widgets/phoneme_tip.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';
import 'package:kita_english/features/session/domain/entities/activity_type.dart';

/// Dual-mode phonics activity widget.
///
/// Mode 1 (phonics_listen): Minimal pair discrimination — play two words,
/// kid answers "Same or Different?"
///
/// Mode 2 (phonics_match): Sound-letter matching — play a word, kid picks
/// the correct grapheme from options.
class PhonicsActivity extends ConsumerStatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const PhonicsActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  ConsumerState<PhonicsActivity> createState() => _PhonicsActivityState();
}

class _PhonicsActivityState extends ConsumerState<PhonicsActivity>
    with TickerProviderStateMixin {
  final _tts = TtsService();
  bool _answered = false;
  bool _showTip = false;
  int? _selectedOptionIndex;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _tipSlideController;
  late Animation<Offset> _tipSlideAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _tipSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tipSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _tipSlideController,
        curve: Curves.easeOutBack,
      ),
    );

    // Auto-play the audio after a brief delay
    Future.delayed(const Duration(milliseconds: 500), _playAudio);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _tipSlideController.dispose();
    super.dispose();
  }

  bool get _isListenMode =>
      widget.activity.type == ActivityType.phonicsListen;

  Map<String, dynamic> get _config => widget.activity.config;

  Future<void> _playAudio() async {
    if (_isListenMode) {
      final word1 = _config['word1'] as String? ?? '';
      final word2 = _config['word2'] as String? ?? '';
      if (word1.isNotEmpty) await _tts.speak(word1);
      await Future.delayed(const Duration(milliseconds: 800));
      if (word2.isNotEmpty && mounted) await _tts.speak(word2);
    } else {
      final targetWord = _config['target_word'] as String? ?? '';
      if (targetWord.isNotEmpty) await _tts.speak(targetWord);
    }
  }

  void _onListenAnswer(bool answeredDifferent) {
    if (_answered) return;

    final areDifferent = _config['are_different'] as bool? ?? true;
    final isCorrect = answeredDifferent == areDifferent;

    if (isCorrect) {
      setState(() => _answered = true);
    } else {
      _shakeController.forward(from: 0);
      setState(() => _showTip = true);
      _tipSlideController.forward(from: 0);
    }

    // Shell owns sound and attempt tracking via onComplete
    widget.onComplete(
      isCorrect: isCorrect,
      metadata: {
        'phoneme_id': _config['phoneme_id'] ?? '',
        'mode': 'listen',
      },
    );
  }

  void _onMatchAnswer(int index) {
    if (_answered) return;

    final options = _config['options'] as List<dynamic>? ?? [];
    if (index >= options.length) return;

    final option = options[index] as Map<String, dynamic>? ?? {};
    final isCorrect = option['correct'] == true;

    setState(() => _selectedOptionIndex = index);

    if (isCorrect) {
      setState(() => _answered = true);
    } else {
      _shakeController.forward(from: 0);
      setState(() => _showTip = true);
      _tipSlideController.forward(from: 0);
      // Reset selection after shake so kid can try again
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _selectedOptionIndex = null);
      });
    }

    // Shell owns sound and attempt tracking via onComplete
    widget.onComplete(
      isCorrect: isCorrect,
      metadata: {
        'phoneme_id': _config['phoneme_id'] ?? '',
        'mode': 'match',
        'selected_grapheme': option['grapheme'] ?? '',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isListenMode) {
      return _buildListenMode();
    }
    return _buildMatchMode();
  }

  // ── Mode 1: Minimal Pair Discrimination ──

  Widget _buildListenMode() {
    final word1 = _config['word1'] as String? ?? '';
    final word2 = _config['word2'] as String? ?? '';
    final word1Meaning = _config['word1_meaning'] as String? ?? '';
    final word2Meaning = _config['word2_meaning'] as String? ?? '';
    final symbol = _config['symbol'] as String? ?? '';

    return Column(
      children: [
        // Title
        Text(
          'Gi\u1ed1ng hay kh\u00e1c? \u{1F442}',
          style: AppTypography.titleLarge.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '\u00c2m /$symbol/',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),

        // Play button
        GestureDetector(
          onTap: _playAudio,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volume_up, color: Colors.white, size: 36),
                Text(
                  'Nghe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Word labels
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _wordChip(word1, word1Meaning),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('vs', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            ),
            _wordChip(word2, word2Meaning),
          ],
        ),

        const Spacer(),

        // Same / Different buttons
        if (!_answered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _bigButton(
                    label: 'Gi\u1ed1ng \u{1F44D}',
                    color: AppColors.tertiary,
                    onTap: () => _onListenAnswer(false),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _bigButton(
                    label: 'Kh\u00e1c \u{1F44E}',
                    color: AppColors.secondary,
                    onTap: () => _onListenAnswer(true),
                  ),
                ),
              ],
            ),
          ),

        // Phoneme tip on wrong answer
        if (_showTip) ...[
          const SizedBox(height: 16),
          SlideTransition(
            position: _tipSlideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PhonemeTip.fromConfig(_config),
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _wordChip(String word, String meaning) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            word,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          if (meaning.isNotEmpty)
            Text(
              meaning,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  // ── Mode 2: Sound-Letter Matching ──

  Widget _buildMatchMode() {
    final targetWord = _config['target_word'] as String? ?? '';
    final symbol = _config['symbol'] as String? ?? '';
    final options = _config['options'] as List<dynamic>? ?? [];

    return Column(
      children: [
        // Title
        Text(
          '\u00c2m n\u00e0o \u0111\u00fang? \u{1F3B5}',
          style: AppTypography.titleLarge.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '\u00c2m /$symbol/',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),

        // Play button with target word
        GestureDetector(
          onTap: _playAudio,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_up, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  '"$targetWord"',
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        Text(
          'Ch\u1ecdn ch\u1eef c\u00e1i t\u1ea1o ra \u00e2m n\u00e0y:',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),

        const SizedBox(height: 20),

        // Grapheme options
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: List.generate(options.length, (index) {
            final option = options[index] as Map<String, dynamic>? ?? {};
            final grapheme = option['grapheme'] as String? ?? '';
            final isCorrectOption = option['correct'] == true;
            final isSelected = _selectedOptionIndex == index;
            final showCorrect = _answered && isCorrectOption;
            final showWrong = isSelected && !isCorrectOption && !_answered;

            return AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final offset =
                    showWrong ? _shakeAnimation.value : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () => _onMatchAnswer(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: showCorrect
                        ? AppColors.successLight.withValues(alpha: 0.3)
                        : isSelected
                            ? AppColors.errorLight.withValues(alpha: 0.25)
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: showCorrect
                          ? AppColors.success
                          : isSelected
                              ? AppColors.error
                              : AppColors.surfaceVariant,
                      width: (showCorrect || isSelected) ? 3 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: showCorrect
                            ? AppColors.success.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: showCorrect ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      grapheme,
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: showCorrect
                            ? AppColors.success
                            : isSelected
                                ? AppColors.error
                                : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const Spacer(),

        // Phoneme tip on wrong answer
        if (_showTip)
          SlideTransition(
            position: _tipSlideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PhonemeTip.fromConfig(_config),
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shared Helpers ──

  Widget _bigButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}
