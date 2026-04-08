import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Fill in the Blank activity: shows a sentence with one word missing,
/// kid picks the correct word from 4 options.
class FillBlankActivity extends ConsumerStatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const FillBlankActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  ConsumerState<FillBlankActivity> createState() => _FillBlankActivityState();
}

class _FillBlankActivityState extends ConsumerState<FillBlankActivity>
    with SingleTickerProviderStateMixin {
  late String _fullSentence;
  late String _displaySentence;
  late String _correctWord;
  late String _vietnameseHint;
  late List<String> _options;
  String? _selectedOption;
  int _wrongAttempts = 0;
  bool _isComplete = false;
  final _tts = TtsService();

  late AnimationController _feedbackController;
  late Animation<double> _feedbackScale;

  @override
  void initState() {
    super.initState();

    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _feedbackScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.elasticOut),
    );

    final config = widget.activity.config;

    _fullSentence = config['sentence'] as String? ?? '';
    _displaySentence = config['display_sentence'] as String? ?? '';
    _correctWord = config['correct_word'] as String? ?? '';
    _vietnameseHint = config['sentence_vi'] as String? ?? '';

    // Fallback
    if (_fullSentence.isEmpty) {
      _fullSentence = 'I like rice.';
      _displaySentence = 'I ___ rice.';
      _correctWord = 'like';
      _vietnameseHint = 'Toi thich com.';
    }

    if (_displaySentence.isEmpty && _correctWord.isNotEmpty) {
      _displaySentence = _fullSentence.replaceFirst(_correctWord, '___');
    }

    // Get options
    final configOptions = config['options'];
    if (configOptions is List && configOptions.isNotEmpty) {
      _options = configOptions.cast<String>().toList();
    } else {
      _options = [_correctWord, 'happy', 'big', 'run'];
    }
    _options.shuffle();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _onOptionTap(String option) {
    if (_isComplete || _selectedOption != null) return;

    setState(() => _selectedOption = option);
    _feedbackController.forward(from: 0);

    if (option.toLowerCase() == _correctWord.toLowerCase()) {
      setState(() => _isComplete = true);
      ref.read(soundEffectsProvider).playCorrect();
      _tts.speak(_fullSentence);
      widget.onComplete(
        isCorrect: true,
        metadata: {
          'sentence': _fullSentence,
          'correct_word': _correctWord,
          'wrongAttempts': _wrongAttempts,
        },
      );
    } else {
      _wrongAttempts++;
      ref.read(soundEffectsProvider).playWrong();

      if (_wrongAttempts >= 3) {
        widget.onComplete(
          isCorrect: false,
          metadata: {
            'sentence': _fullSentence,
            'correct_word': _correctWord,
            'wrongAttempts': _wrongAttempts,
          },
        );
      } else {
        // Reset selection after a brief delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() => _selectedOption = null);
          }
        });
      }
    }
  }

  Color _getOptionColor(String option) {
    if (_selectedOption == null) return AppColors.surface;
    if (option != _selectedOption) return AppColors.surface;
    if (option.toLowerCase() == _correctWord.toLowerCase()) {
      return AppColors.successLight.withValues(alpha: 0.3);
    }
    return AppColors.error.withValues(alpha: 0.15);
  }

  Color _getOptionBorderColor(String option) {
    if (_selectedOption == null) {
      return AppColors.primary.withValues(alpha: 0.3);
    }
    if (option != _selectedOption) {
      return AppColors.primary.withValues(alpha: 0.15);
    }
    if (option.toLowerCase() == _correctWord.toLowerCase()) {
      return AppColors.success;
    }
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instruction
        Text(
          '\u0110i\u1EC1n t\u1EEB c\u00F2n thi\u1EBFu! \u270D\uFE0F',
          style: AppTypography.titleLarge.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Vietnamese hint
        if (_vietnameseHint.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondaryLight.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.secondary, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _vietnameseHint,
                    style: AppTypography.vietnameseHint.copyWith(fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // Listen button
        GestureDetector(
          onTap: () => _tts.speak(_fullSentence),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_up,
                    color: AppColors.secondary, size: 22),
                const SizedBox(width: 6),
                Text(
                  'Nghe c\u00E2u',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Sentence with blank
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _isComplete
                ? AppColors.successLight.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isComplete ? AppColors.success : AppColors.surfaceVariant,
              width: _isComplete ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            _isComplete
                ? _fullSentence
                : _displaySentence,
            style: AppTypography.titleLarge.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _isComplete ? AppColors.success : AppColors.textPrimary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const Spacer(),

        // Word options (2x2 grid)
        if (!_isComplete)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _options.map((option) {
                return GestureDetector(
                  onTap: () => _onOptionTap(option),
                  child: AnimatedBuilder(
                    animation: _feedbackScale,
                    builder: (context, child) {
                      final shouldAnimate = _selectedOption == option &&
                          _feedbackController.isAnimating;
                      return Transform.scale(
                        scale: shouldAnimate ? _feedbackScale.value : 1.0,
                        child: child,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      constraints: const BoxConstraints(minWidth: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: _getOptionColor(option),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _getOptionBorderColor(option),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        option,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _selectedOption == option &&
                                  option.toLowerCase() ==
                                      _correctWord.toLowerCase()
                              ? AppColors.success
                              : _selectedOption == option
                                  ? AppColors.error
                                  : AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        if (_isComplete)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.successLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Ch\u00EDnh x\u00E1c! \u{1F389}',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.success,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }
}
