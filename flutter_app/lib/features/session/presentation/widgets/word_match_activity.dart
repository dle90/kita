import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Word Match activity: match English words with Vietnamese translations.
/// Tap to select pairs — correct matches light up green.
class WordMatchActivity extends StatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const WordMatchActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  State<WordMatchActivity> createState() => _WordMatchActivityState();
}

class _WordMatchActivityState extends State<WordMatchActivity> {
  // Pairs: each option contains text (English) and config has Vietnamese
  late List<_MatchPair> _pairs;
  late List<String> _shuffledRight;

  int? _selectedLeftIndex;
  int? _selectedRightIndex;
  final Set<int> _matchedLeftIndices = {};
  final Set<int> _matchedRightIndices = {};
  int _wrongAttempts = 0;

  @override
  void initState() {
    super.initState();
    _buildPairs();
  }

  void _buildPairs() {
    final options = widget.activity.options;
    _pairs = options.map((opt) {
      final vietnamese =
          widget.activity.config['translations']?[opt.text] as String? ??
              opt.text;
      return _MatchPair(english: opt.text, vietnamese: vietnamese);
    }).toList();

    // If no translations from config, create simple pairs
    if (_pairs.isEmpty) {
      _pairs = [
        const _MatchPair(english: 'Cat', vietnamese: 'Con mèo'),
        const _MatchPair(english: 'Dog', vietnamese: 'Con chó'),
        const _MatchPair(english: 'Fish', vietnamese: 'Con cá'),
        const _MatchPair(english: 'Bird', vietnamese: 'Con chim'),
      ];
    }

    _shuffledRight =
        _pairs.map((p) => p.vietnamese).toList()..shuffle();
  }

  void _onLeftTap(int index) {
    if (_matchedLeftIndices.contains(index)) return;
    setState(() {
      _selectedLeftIndex = index;
      _checkMatch();
    });
  }

  void _onRightTap(int index) {
    if (_matchedRightIndices.contains(index)) return;
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
      // Match found
      _matchedLeftIndices.add(_selectedLeftIndex!);
      _matchedRightIndices.add(_selectedRightIndex!);
      _selectedLeftIndex = null;
      _selectedRightIndex = null;

      // Check if all matched
      if (_matchedLeftIndices.length == _pairs.length) {
        Future.delayed(const Duration(milliseconds: 600), () {
          widget.onComplete(
            isCorrect: true,
            metadata: {'wrongAttempts': _wrongAttempts},
          );
        });
      }
    } else {
      // Wrong match
      _wrongAttempts++;

      // Brief red highlight then reset
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _selectedLeftIndex = null;
            _selectedRightIndex = null;
          });
        }
      });

      if (_wrongAttempts >= 6) {
        widget.onComplete(
          isCorrect: false,
          metadata: {'wrongAttempts': _wrongAttempts},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Nối từ tiếng Anh với nghĩa tiếng Việt!',
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

                    return GestureDetector(
                      onTap: () => _onLeftTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? AppColors.successLight.withValues(alpha:0.3)
                              : isSelected
                                  ? AppColors.primaryLight.withValues(alpha:0.3)
                                  : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMatched
                                ? AppColors.success
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

                    return GestureDetector(
                      onTap: () => _onRightTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? AppColors.successLight.withValues(alpha:0.3)
                              : isSelected
                                  ? AppColors.secondaryLight.withValues(alpha:0.3)
                                  : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMatched
                                ? AppColors.success
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
