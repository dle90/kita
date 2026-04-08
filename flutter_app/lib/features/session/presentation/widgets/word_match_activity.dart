import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Word Match activity: match English words with Vietnamese translations.
/// Tap to select pairs -- correct matches light up green.
class WordMatchActivity extends ConsumerStatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const WordMatchActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  ConsumerState<WordMatchActivity> createState() => _WordMatchActivityState();
}

class _WordMatchActivityState extends ConsumerState<WordMatchActivity>
    with SingleTickerProviderStateMixin {
  late List<_MatchPair> _pairs;
  late List<String> _shuffledRight;

  int? _selectedLeftIndex;
  int? _selectedRightIndex;
  final Set<int> _matchedLeftIndices = {};
  final Set<int> _matchedRightIndices = {};
  int _wrongAttempts = 0;
  bool _wrongFlash = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _buildPairs();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _buildPairs() {
    final config = widget.activity.config;
    _pairs = [];

    // Try config['pairs'] first (backend format: [{english, match}])
    final configPairs = config['pairs'];
    if (configPairs is List && configPairs.isNotEmpty) {
      for (final p in configPairs) {
        if (p is Map) {
          final english = p['english'] as String? ?? '';
          final match = p['match'] as String? ?? p['vietnamese'] as String? ?? '';
          if (english.isNotEmpty && match.isNotEmpty) {
            _pairs.add(_MatchPair(english: english, vietnamese: match));
          }
        }
      }
    }

    // Try options + translations fallback
    if (_pairs.isEmpty) {
      final options = widget.activity.options;
      if (options.isNotEmpty) {
        _pairs = options.map((opt) {
          final vietnamese =
              config['translations']?[opt.text] as String? ?? opt.text;
          return _MatchPair(english: opt.text, vietnamese: vietnamese);
        }).toList();
      }
    }

    // Final fallback
    if (_pairs.isEmpty) {
      _pairs = [
        const _MatchPair(english: 'Cat', vietnamese: 'Con m\u00E8o'),
        const _MatchPair(english: 'Dog', vietnamese: 'Con ch\u00F3'),
        const _MatchPair(english: 'Fish', vietnamese: 'Con c\u00E1'),
        const _MatchPair(english: 'Bird', vietnamese: 'Con chim'),
      ];
    }

    _shuffledRight = _pairs.map((p) => p.vietnamese).toList()..shuffle();
  }

  void _onLeftTap(int index) {
    if (_matchedLeftIndices.contains(index) || _wrongFlash) return;
    ref.read(soundEffectsProvider).playTap();
    setState(() {
      _selectedLeftIndex = index;
      _checkMatch();
    });
  }

  void _onRightTap(int index) {
    if (_matchedRightIndices.contains(index) || _wrongFlash) return;
    ref.read(soundEffectsProvider).playTap();
    setState(() {
      _selectedRightIndex = index;
      _checkMatch();
    });
  }

  void _checkMatch() {
    if (_selectedLeftIndex == null || _selectedRightIndex == null) return;

    final leftPair = _pairs[_selectedLeftIndex!];
    final rightText = _shuffledRight[_selectedRightIndex!];

    if (leftPair.vietnamese == rightText) {
      // Correct match
      ref.read(soundEffectsProvider).playCorrect();
      _matchedLeftIndices.add(_selectedLeftIndex!);
      _matchedRightIndices.add(_selectedRightIndex!);
      _selectedLeftIndex = null;
      _selectedRightIndex = null;

      // Check if all matched
      if (_matchedLeftIndices.length == _pairs.length) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            widget.onComplete(
              isCorrect: true,
              metadata: {'wrongAttempts': _wrongAttempts},
            );
          }
        });
      }
    } else {
      // Wrong match - shake and reset
      _wrongAttempts++;
      ref.read(soundEffectsProvider).playWrong();
      _shakeController.forward(from: 0);
      setState(() => _wrongFlash = true);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _selectedLeftIndex = null;
            _selectedRightIndex = null;
            _wrongFlash = false;
          });
        }
      });

      if (_wrongAttempts >= 6) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            widget.onComplete(
              isCorrect: false,
              metadata: {'wrongAttempts': _wrongAttempts},
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'N\u1ED1i t\u1EEB ti\u1EBFng Anh v\u1EDBi ngh\u0129a ti\u1EBFng Vi\u1EC7t!',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: English words
              Expanded(
                child: ListView.separated(
                  itemCount: _pairs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final isMatched = _matchedLeftIndices.contains(index);
                    final isSelected = _selectedLeftIndex == index;
                    final isWrongSelected = isSelected && _wrongFlash;

                    return GestureDetector(
                      onTap: () => _onLeftTap(index),
                      child: AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          final offset = isWrongSelected
                              ? _shakeAnimation.value
                              : 0.0;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isMatched
                                ? AppColors.successLight.withValues(alpha: 0.3)
                                : isWrongSelected
                                    ? AppColors.errorLight.withValues(alpha: 0.3)
                                    : isSelected
                                        ? AppColors.primaryLight
                                            .withValues(alpha: 0.3)
                                        : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMatched
                                  ? AppColors.success
                                  : isWrongSelected
                                      ? AppColors.error
                                      : isSelected
                                          ? AppColors.primary
                                          : AppColors.surfaceVariant,
                              width: (isMatched || isSelected) ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            _pairs[index].english,
                            style: AppTypography.titleSmall.copyWith(
                              color: isMatched
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Connection indicator
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pairs.length,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Icon(
                      _matchedLeftIndices.contains(i)
                          ? Icons.check_circle
                          : Icons.arrow_forward,
                      color: _matchedLeftIndices.contains(i)
                          ? AppColors.success
                          : AppColors.textHint,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Right column: Vietnamese translations
              Expanded(
                child: ListView.separated(
                  itemCount: _shuffledRight.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final isMatched = _matchedRightIndices.contains(index);
                    final isSelected = _selectedRightIndex == index;
                    final isWrongSelected = isSelected && _wrongFlash;

                    return GestureDetector(
                      onTap: () => _onRightTap(index),
                      child: AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          final offset = isWrongSelected
                              ? -_shakeAnimation.value
                              : 0.0;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isMatched
                                ? AppColors.successLight.withValues(alpha: 0.3)
                                : isWrongSelected
                                    ? AppColors.errorLight.withValues(alpha: 0.3)
                                    : isSelected
                                        ? AppColors.secondaryLight
                                            .withValues(alpha: 0.3)
                                        : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMatched
                                  ? AppColors.success
                                  : isWrongSelected
                                      ? AppColors.error
                                      : isSelected
                                          ? AppColors.secondary
                                          : AppColors.surfaceVariant,
                              width: (isMatched || isSelected) ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            _shuffledRight[index],
                            style: AppTypography.titleSmall.copyWith(
                              color: isMatched
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchPair {
  final String english;
  final String vietnamese;

  const _MatchPair({required this.english, required this.vietnamese});
}
