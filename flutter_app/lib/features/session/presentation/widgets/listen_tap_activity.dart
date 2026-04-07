import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Listen & Tap activity: plays audio of a word, kid taps the matching image.
/// Falls back to TTS + emoji when no audio/image URLs are available.
class ListenTapActivity extends ConsumerStatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const ListenTapActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  ConsumerState<ListenTapActivity> createState() => _ListenTapActivityState();
}

class _ListenTapActivityState extends ConsumerState<ListenTapActivity>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  int? _correctIndex;
  bool _answered = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final _tts = TtsService();

  // Fallback word data when no options are provided
  static const _fallbackWords = [
    {'word': 'hello', 'emoji': '👋', 'vi': 'xin chào'},
    {'word': 'cat', 'emoji': '🐱', 'vi': 'con mèo'},
    {'word': 'dog', 'emoji': '🐶', 'vi': 'con chó'},
    {'word': 'apple', 'emoji': '🍎', 'vi': 'quả táo'},
    {'word': 'happy', 'emoji': '😊', 'vi': 'vui'},
    {'word': 'sad', 'emoji': '😢', 'vi': 'buồn'},
    {'word': 'mom', 'emoji': '👩', 'vi': 'mẹ'},
    {'word': 'dad', 'emoji': '👨', 'vi': 'bố'},
    {'word': 'fish', 'emoji': '🐟', 'vi': 'con cá'},
    {'word': 'bird', 'emoji': '🐦', 'vi': 'con chim'},
    {'word': 'milk', 'emoji': '🥛', 'vi': 'sữa'},
    {'word': 'rice', 'emoji': '🍚', 'vi': 'cơm'},
    {'word': 'water', 'emoji': '💧', 'vi': 'nước'},
    {'word': 'run', 'emoji': '🏃', 'vi': 'chạy'},
    {'word': 'jump', 'emoji': '🤸', 'vi': 'nhảy'},
    {'word': 'book', 'emoji': '📖', 'vi': 'sách'},
  ];

  late final List<Map<String, String>> _quizOptions;
  late final int _correctQuizIndex;
  late final String _targetWord;

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

    if (widget.activity.options.isNotEmpty) {
      // Original mode with options
      for (int i = 0; i < widget.activity.options.length; i++) {
        if (widget.activity.options[i].isCorrect) {
          _correctIndex = i;
          break;
        }
      }
      _quizOptions = [];
      _correctQuizIndex = 0;
      _targetWord = widget.activity.targetWord ?? '';
    } else {
      // Fallback mode: generate quiz from fallback words
      final shuffled = List<Map<String, String>>.from(_fallbackWords)..shuffle();
      _quizOptions = shuffled.take(4).toList();
      _correctQuizIndex = 0; // first one is the answer
      _targetWord = _quizOptions[0]['word']!;
      _quizOptions.shuffle(); // re-shuffle so answer isn't always first
      // find where the correct answer ended up
      for (int i = 0; i < _quizOptions.length; i++) {
        if (_quizOptions[i]['word'] == _targetWord) {
          _correctIndex = i;
          break;
        }
      }
    }

    _playAudio();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_targetWord.isNotEmpty) {
      await _tts.speak(_targetWord);
    }
  }

  void _onOptionTap(int index) {
    if (_answered) return;

    setState(() => _selectedIndex = index);

    final isCorrect = index == _correctIndex;
    final selectedId = widget.activity.options.isNotEmpty
        ? widget.activity.options[index].id
        : (_quizOptions.isNotEmpty ? _quizOptions[index]['word'] ?? '' : '');

    if (isCorrect) {
      ref.read(soundEffectsProvider).playCorrect();
      setState(() => _answered = true);
      widget.onComplete(
        isCorrect: true,
        metadata: {'selectedOption': selectedId},
      );
    } else {
      ref.read(soundEffectsProvider).playWrong();
      _shakeController.forward(from: 0);
      widget.onComplete(
        isCorrect: false,
        metadata: {'selectedOption': selectedId},
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _selectedIndex = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use original options or fallback quiz
    final hasOriginalOptions = widget.activity.options.isNotEmpty;

    return Column(
      children: [
        // Instruction
        const Text(
          'Nghe và chọn hình đúng!',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Play button
        GestureDetector(
          onTap: _playAudio,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_up, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Nghe lại',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Options grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: hasOriginalOptions
                ? widget.activity.options.length
                : _quizOptions.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              final isCorrectAnswer =
                  _answered && index == _correctIndex;

              return _ShakeWrapper(
                animation: _shakeAnimation,
                shouldShake: isSelected && !_answered,
                direction: (index % 2 == 0) ? 1 : -1,
                child: GestureDetector(
                  onTap: () => _onOptionTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: isCorrectAnswer
                          ? AppColors.successLight.withValues(alpha:0.3)
                          : isSelected
                              ? AppColors.errorLight.withValues(alpha:0.3)
                              : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCorrectAnswer
                            ? AppColors.success
                            : isSelected
                                ? AppColors.error
                                : AppColors.surfaceVariant,
                        width: (isSelected || isCorrectAnswer) ? 3 : 1,
                      ),
                      boxShadow: isCorrectAnswer
                          ? [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha:0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: _buildOptionContent(
                      index,
                      hasOriginalOptions,
                      isCorrectAnswer,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionContent(
    int index,
    bool hasOriginalOptions,
    bool isCorrectAnswer,
  ) {
    if (hasOriginalOptions) {
      final option = widget.activity.options[index];
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            option.text.isNotEmpty ? option.text[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(option.text, style: AppTypography.titleSmall, textAlign: TextAlign.center),
          if (isCorrectAnswer)
            const Icon(Icons.star, color: AppColors.starFilled, size: 24),
        ],
      );
    }

    // Fallback quiz mode with emoji
    final quizOption = _quizOptions[index];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          quizOption['emoji'] ?? '❓',
          style: const TextStyle(fontSize: 48),
        ),
        const SizedBox(height: 8),
        Text(
          quizOption['word'] ?? '',
          style: AppTypography.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          quizOption['vi'] ?? '',
          style: AppTypography.vietnameseHint,
          textAlign: TextAlign.center,
        ),
        if (isCorrectAnswer)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.star, color: AppColors.starFilled, size: 24),
          ),
      ],
    );
  }
}

/// A widget that applies a horizontal shake effect.
class _ShakeWrapper extends StatelessWidget {
  final Animation<double> animation;
  final bool shouldShake;
  final int direction;
  final Widget child;

  const _ShakeWrapper({
    required this.animation,
    required this.shouldShake,
    required this.direction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final offset = shouldShake ? animation.value * direction : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: child,
    );
  }
}
