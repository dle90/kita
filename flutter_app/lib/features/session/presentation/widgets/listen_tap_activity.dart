import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/audio_player.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Listen & Tap activity: plays audio of a word, kid taps the matching image.
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

  @override
  void initState() {
    super.initState();
    // Find the correct option index
    for (int i = 0; i < widget.activity.options.length; i++) {
      if (widget.activity.options[i].isCorrect) {
        _correctIndex = i;
        break;
      }
    }

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Auto-play the audio when the activity loads
    _playAudio();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    final audioUrl = widget.activity.audioUrl;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        final player = ref.read(audioPlayerProvider);
        await player.play(audioUrl);
      } catch (_) {
        // Audio playback failure is non-fatal
      }
    }
  }

  void _onOptionTap(int index) {
    if (_answered) return;

    setState(() => _selectedIndex = index);

    final isCorrect = index == _correctIndex;
    if (isCorrect) {
      setState(() => _answered = true);
      widget.onComplete(
        isCorrect: true,
        metadata: {'selectedOption': widget.activity.options[index].id},
      );
    } else {
      // Shake animation for wrong answer
      _shakeController.forward(from: 0);
      widget.onComplete(
        isCorrect: false,
        metadata: {'selectedOption': widget.activity.options[index].id},
      );
      // Reset selection after shake
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _selectedIndex = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.activity.options;

    return Column(
      children: [
        // Instruction
        const Text(
          'Nghe và chọn hình đúng!',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        if (widget.activity.vietnameseTranslation != null)
          Text(
            widget.activity.vietnameseTranslation!,
            style: AppTypography.vietnameseHint,
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
                  color: AppColors.secondary.withValues(alpha:0.3),
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
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Image or emoji placeholder
                        if (option.imageUrl != null &&
                            option.imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              option.imageUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.image,
                                  size: 40,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                option.text.isNotEmpty
                                    ? option.text[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          option.text,
                          style: AppTypography.titleSmall,
                          textAlign: TextAlign.center,
                        ),
                        if (isCorrectAnswer)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child:
                                Icon(Icons.star, color: AppColors.starFilled, size: 24),
                          ),
                      ],
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
