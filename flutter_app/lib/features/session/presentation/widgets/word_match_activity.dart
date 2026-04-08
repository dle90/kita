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
  // Color coding for matched pairs
  final Map<int, Color> _matchedLeftColors = {};
  final Map<int, Color> _matchedRightColors = {};
  int _wrongAttempts = 0;
  bool _wrongFlash = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  static const _matchColors = [
    Color(0xFF4A90D9), // blue
    Color(0xFF7CD992), // green
    Color(0xFFFF8C42), // orange
    Color(0xFFAB7BF7), // purple
    Color(0xFFFF9FB0), // pink
    Color(0xFFFFD166), // gold
  ];

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
          final english =
              p['english'] as String? ?? '';
          final match =
              p['match'] as String? ?? p['vietnamese'] as String? ?? '';
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
      // Correct match — assign a color
      ref.read(soundEffectsProvider).playCorrect();
      final colorIndex =
          _matchedLeftIndices.length % _matchColors.length;
      final matchColor = _matchColors[colorIndex];
      _matchedLeftIndices.add(_selectedLeftIndex!);
      _matchedRightIndices.add(_selectedRightIndex!);
      _matchedLeftColors[_selectedLeftIndex!] = matchColor;
      _matchedRightColors[_selectedRightIndex!] = matchColor;
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
    final matched = _matchedLeftIndices.length;
    final total = _pairs.length;

    return Column(
      children: [
        Text(
          'N\u1ED1i t\u1EEB ti\u1EBFng Anh v\u1EDBi ngh\u0129a ti\u1EBFng Vi\u1EC7t! \u{1F517}',
          style: AppTypography.titleLarge.copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),

        // Progress indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 6),
              Text(
                '$matched / $total c\u1EB7p \u0111\u00E3 n\u1ED1i',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              // Mini progress bar
              SizedBox(
                width: 60,
                height: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? matched / total : 0,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '\u{1F1EC}\u{1F1E7} English',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 44),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '\u{1F1FB}\u{1F1F3} Ti\u1EBFng Vi\u1EC7t',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: English words (blue tint background)
              Expanded(
                child: ListView.separated(
                  itemCount: _pairs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final isMatched = _matchedLeftIndices.contains(index);
                    final isSelected = _selectedLeftIndex == index;
                    final isWrongSelected = isSelected && _wrongFlash;
                    final matchColor = _matchedLeftColors[index];

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
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isMatched
                                ? matchColor?.withValues(alpha: 0.15) ??
                                    AppColors.successLight
                                        .withValues(alpha: 0.2)
                                : isWrongSelected
                                    ? AppColors.errorLight
                                        .withValues(alpha: 0.25)
                                    : isSelected
                                        ? AppColors.primaryLight
                                            .withValues(alpha: 0.25)
                                        : AppColors.primaryLight
                                            .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isMatched
                                  ? matchColor ?? AppColors.success
                                  : isWrongSelected
                                      ? AppColors.error
                                      : isSelected
                                          ? AppColors.primary
                                          : AppColors.primary
                                              .withValues(alpha: 0.2),
                              width: (isMatched || isSelected) ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected && !isWrongSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isMatched)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(Icons.check_circle,
                                      color: matchColor ?? AppColors.success,
                                      size: 18),
                                ),
                              Flexible(
                                child: Text(
                                  _pairs[index].english,
                                  style: AppTypography.titleSmall.copyWith(
                                    color: isMatched
                                        ? (matchColor ?? AppColors.success)
                                        : AppColors.primary,
                                    fontSize: 16,
                                    decoration: isMatched
                                        ? TextDecoration.none
                                        : null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Connection indicator column
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pairs.length,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _matchedLeftIndices.contains(i)
                          ? Icon(
                              Icons.check_circle,
                              key: ValueKey('check_$i'),
                              color:
                                  _matchedLeftColors[i] ?? AppColors.success,
                              size: 22,
                            )
                          : Icon(
                              Icons.link,
                              key: ValueKey('link_$i'),
                              color: AppColors.textHint.withValues(alpha: 0.5),
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Right column: Vietnamese translations (orange tint background)
              Expanded(
                child: ListView.separated(
                  itemCount: _shuffledRight.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final isMatched = _matchedRightIndices.contains(index);
                    final isSelected = _selectedRightIndex == index;
                    final isWrongSelected = isSelected && _wrongFlash;
                    final matchColor = _matchedRightColors[index];

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
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isMatched
                                ? matchColor?.withValues(alpha: 0.15) ??
                                    AppColors.successLight
                                        .withValues(alpha: 0.2)
                                : isWrongSelected
                                    ? AppColors.errorLight
                                        .withValues(alpha: 0.25)
                                    : isSelected
                                        ? AppColors.secondaryLight
                                            .withValues(alpha: 0.25)
                                        : AppColors.secondaryLight
                                            .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isMatched
                                  ? matchColor ?? AppColors.success
                                  : isWrongSelected
                                      ? AppColors.error
                                      : isSelected
                                          ? AppColors.secondary
                                          : AppColors.secondary
                                              .withValues(alpha: 0.2),
                              width: (isMatched || isSelected) ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected && !isWrongSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isMatched)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(Icons.check_circle,
                                      color: matchColor ?? AppColors.success,
                                      size: 18),
                                ),
                              Flexible(
                                child: Text(
                                  _shuffledRight[index],
                                  style: AppTypography.titleSmall.copyWith(
                                    color: isMatched
                                        ? (matchColor ?? AppColors.success)
                                        : AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
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
