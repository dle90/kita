import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Sentence Builder activity: scrambled word tiles that the kid
/// drags/taps into the correct sentence order.
class SentenceBuilderActivity extends StatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const SentenceBuilderActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  State<SentenceBuilderActivity> createState() =>
      _SentenceBuilderActivityState();
}

class _SentenceBuilderActivityState extends State<SentenceBuilderActivity> {
  late List<String> _correctOrder;
  late List<String> _availableWords;
  final List<String?> _placedWords = [];
  int _wrongAttempts = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();

    // Build the correct sentence from the activity
    final sentence = widget.activity.targetSentence ??
        widget.activity.targetWord ??
        'I like cats';
    _correctOrder = sentence.split(' ');

    // Initialize empty slots
    _placedWords.addAll(List.filled(_correctOrder.length, null));

    // Shuffle words for the available pool
    _availableWords = List.from(_correctOrder)..shuffle();
  }

  void _onWordTap(String word) {
    if (_isComplete) return;

    // Find the first empty slot
    final emptyIndex = _placedWords.indexOf(null);
    if (emptyIndex == -1) return;

    setState(() {
      _placedWords[emptyIndex] = word;
      _availableWords.remove(word);
    });

    // Check if all slots are filled
    if (!_placedWords.contains(null)) {
      _checkAnswer();
    }
  }

  void _onSlotTap(int index) {
    if (_isComplete) return;
    final word = _placedWords[index];
    if (word == null) return;

    setState(() {
      _placedWords[index] = null;
      _availableWords.add(word);
    });
  }

  void _checkAnswer() {
    bool allCorrect = true;
    for (int i = 0; i < _correctOrder.length; i++) {
      if (_placedWords[i] != _correctOrder[i]) {
        allCorrect = false;
        break;
      }
    }

    if (allCorrect) {
      setState(() => _isComplete = true);
      widget.onComplete(
        isCorrect: true,
        metadata: {'wrongAttempts': _wrongAttempts},
      );
    } else {
      _wrongAttempts++;
      if (_wrongAttempts >= 3) {
        widget.onComplete(
          isCorrect: false,
          metadata: {'wrongAttempts': _wrongAttempts},
        );
      } else {
        // Reset placed words back to available
        setState(() {
          for (int i = 0; i < _placedWords.length; i++) {
            final word = _placedWords[i];
            if (word != null) {
              _availableWords.add(word);
              _placedWords[i] = null;
            }
          }
          _availableWords.shuffle();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vietnameseHint = widget.activity.vietnameseTranslation;

    return Column(
      children: [
        // Instruction
        const Text(
          'Xếp các từ thành câu đúng!',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Vietnamese translation hint
        if (vietnameseHint != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    vietnameseHint,
                    style: AppTypography.vietnameseHint,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),

        // Answer slots at top
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isComplete
                ? AppColors.successLight.withValues(alpha:0.2)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isComplete
                  ? AppColors.success
                  : AppColors.surfaceVariant,
              width: _isComplete ? 2 : 1,
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(_placedWords.length, (index) {
              final word = _placedWords[index];
              final isCorrectPosition = _isComplete;

              return GestureDetector(
                onTap: () => _onSlotTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minWidth: 60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: word != null
                        ? isCorrectPosition
                            ? AppColors.success
                            : AppColors.primary
                        : AppColors.surfaceVariant.withValues(alpha:0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: word == null
                        ? Border.all(
                            color: AppColors.textHint.withValues(alpha:0.3),
                            style: BorderStyle.solid,
                          )
                        : null,
                  ),
                  child: Text(
                    word ?? '___',
                    style: AppTypography.titleSmall.copyWith(
                      color: word != null
                          ? Colors.white
                          : AppColors.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }),
          ),
        ),

        const Spacer(),

        // Available word tiles at bottom
        if (!_isComplete)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _availableWords.map((word) {
              return GestureDetector(
                onTap: () => _onWordTap(word),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha:0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha:0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    word,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

        if (_isComplete)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 28,),
                const SizedBox(width: 8),
                Text(
                  'Chính xác!',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }
}
