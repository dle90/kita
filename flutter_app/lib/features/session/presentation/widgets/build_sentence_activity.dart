import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Build Sentence activity: scrambled WORD tiles that the kid taps in correct
/// order to build a complete English sentence.
class BuildSentenceActivity extends ConsumerStatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const BuildSentenceActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  ConsumerState<BuildSentenceActivity> createState() =>
      _BuildSentenceActivityState();
}

class _BuildSentenceActivityState extends ConsumerState<BuildSentenceActivity>
    with TickerProviderStateMixin {
  late String _fullSentence;
  late String _vietnameseHint;
  late List<String> _correctWords;
  late List<_WordTile> _availableTiles;
  final List<_WordTile?> _placedTiles = [];
  int _wrongAttempts = 0;
  bool _isComplete = false;
  bool _showHint = false;
  final _tts = TtsService();

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    final config = widget.activity.config;

    // Read sentence from config
    _fullSentence = (config['sentence'] as String? ?? '').trim();
    _vietnameseHint = config['sentence_vi'] as String? ?? '';

    // Fallback
    if (_fullSentence.isEmpty) {
      _fullSentence = 'I am happy.';
      if (_vietnameseHint.isEmpty) _vietnameseHint = 'Toi vui.';
    }

    // Get correct word order from config or derive from sentence
    final configCorrect = config['correct_order'];
    if (configCorrect is List && configCorrect.isNotEmpty) {
      _correctWords = configCorrect.cast<String>().toList();
    } else {
      // Strip trailing punctuation and split
      final cleaned = _fullSentence.replaceAll(RegExp(r'[.!?]+$'), '');
      _correctWords = cleaned.split(RegExp(r'\s+'));
    }

    // Get scrambled words from config or shuffle ourselves
    List<String> scrambled;
    final configScrambled = config['scrambled_words'];
    if (configScrambled is List && configScrambled.isNotEmpty) {
      scrambled = configScrambled.cast<String>().toList();
    } else {
      scrambled = List<String>.from(_correctWords)..shuffle();
      // Ensure it's actually shuffled for >1 word
      if (_correctWords.length > 1) {
        for (int i = 0; i < 10; i++) {
          bool same = true;
          for (int j = 0; j < scrambled.length; j++) {
            if (scrambled[j] != _correctWords[j]) {
              same = false;
              break;
            }
          }
          if (!same) break;
          scrambled.shuffle();
        }
      }
    }

    // Create tiles
    _availableTiles = [];
    for (int i = 0; i < scrambled.length; i++) {
      _availableTiles.add(_WordTile(id: i, word: scrambled[i]));
    }

    // Empty placement slots
    _placedTiles.addAll(List.filled(_correctWords.length, null));

    _tts.speak(_fullSentence);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onTileTap(_WordTile tile) {
    if (_isComplete) return;

    final emptyIndex = _placedTiles.indexOf(null);
    if (emptyIndex == -1) return;

    ref.read(soundEffectsProvider).playTap();

    setState(() {
      _placedTiles[emptyIndex] = tile;
      _availableTiles.remove(tile);
      _showHint = false;
    });

    _bounceController.forward(from: 0);

    // Check if all slots filled
    if (!_placedTiles.contains(null)) {
      _checkAnswer();
    }
  }

  void _onSlotTap(int index) {
    if (_isComplete) return;
    final tile = _placedTiles[index];
    if (tile == null) return;

    setState(() {
      _placedTiles[index] = null;
      // Remove all tiles after this index too (natural sentence building)
      for (int i = index + 1; i < _placedTiles.length; i++) {
        final laterTile = _placedTiles[i];
        if (laterTile != null) {
          _availableTiles.add(laterTile);
          _placedTiles[i] = null;
        }
      }
      _availableTiles.add(tile);
    });
  }

  void _checkAnswer() {
    final built = _placedTiles.map((t) => t?.word ?? '').toList();

    bool correct = true;
    for (int i = 0; i < _correctWords.length; i++) {
      if (i >= built.length ||
          built[i].toLowerCase() != _correctWords[i].toLowerCase()) {
        correct = false;
        break;
      }
    }

    if (correct) {
      setState(() => _isComplete = true);
      ref.read(soundEffectsProvider).playCorrect();
      _tts.speak(_fullSentence);
      widget.onComplete(
        isCorrect: true,
        metadata: {
          'sentence': _fullSentence,
          'wrongAttempts': _wrongAttempts,
        },
      );
    } else {
      _wrongAttempts++;
      ref.read(soundEffectsProvider).playWrong();
      _shakeController.forward(from: 0);

      if (_wrongAttempts >= 3) {
        widget.onComplete(
          isCorrect: false,
          metadata: {
            'sentence': _fullSentence,
            'wrongAttempts': _wrongAttempts,
          },
        );
      } else {
        // Reset tiles back
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() {
            for (int i = 0; i < _placedTiles.length; i++) {
              final tile = _placedTiles[i];
              if (tile != null) {
                _availableTiles.add(tile);
                _placedTiles[i] = null;
              }
            }
            _availableTiles.shuffle();
            _showHint = true;
          });
          // Auto-hide hint
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showHint = false);
          });
        });
      }
    }
  }

  int? _getNextHintIndex() {
    final emptyIndex = _placedTiles.indexOf(null);
    if (emptyIndex == -1) return null;
    final nextWord = _correctWords[emptyIndex];
    for (int i = 0; i < _availableTiles.length; i++) {
      if (_availableTiles[i].word.toLowerCase() == nextWord.toLowerCase()) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hintTileIndex = _showHint ? _getNextHintIndex() : null;

    return Column(
      children: [
        // Instruction
        Text(
          'X\u1EBFp t\u1EEB \u0111\u1EC3 t\u1EA1o c\u00E2u! \u{1F9E9}',
          style: AppTypography.titleLarge.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _tts.speak(_fullSentence),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          ],
        ),
        const SizedBox(height: 20),

        // Answer slots
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _shakeController.isAnimating
                    ? _shakeAnimation.value *
                        ((_shakeController.value * 10).toInt().isEven ? 1 : -1)
                    : 0,
                0,
              ),
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isComplete
                  ? AppColors.successLight.withValues(alpha: 0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color:
                    _isComplete ? AppColors.success : AppColors.surfaceVariant,
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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(_placedTiles.length, (index) {
                final tile = _placedTiles[index];

                return GestureDetector(
                  onTap: () => _onSlotTap(index),
                  child: AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      final lastPlacedIndex =
                          _placedTiles.lastIndexWhere((t) => t != null);
                      final shouldBounce = index == lastPlacedIndex &&
                          _bounceController.isAnimating;
                      return Transform.scale(
                        scale: shouldBounce ? _bounceAnimation.value : 1.0,
                        child: child,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      constraints: const BoxConstraints(minWidth: 60),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tile != null
                            ? _isComplete
                                ? AppColors.success
                                : AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: tile == null
                            ? Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 2,
                                strokeAlign: BorderSide.strokeAlignInside,
                              )
                            : null,
                        boxShadow: tile != null
                            ? [
                                BoxShadow(
                                  color: (_isComplete
                                          ? AppColors.success
                                          : AppColors.primary)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        tile?.word ?? '___',
                        style: AppTypography.titleMedium.copyWith(
                          color: tile != null
                              ? Colors.white
                              : AppColors.textHint,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        const Spacer(),

        // Available word tiles
        if (!_isComplete)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: List.generate(_availableTiles.length, (i) {
              final tile = _availableTiles[i];
              final isHinted = hintTileIndex == i;

              return GestureDetector(
                onTap: () => _onTileTap(tile),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minWidth: 60),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isHinted
                        ? AppColors.warningLight.withValues(alpha: 0.4)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isHinted
                          ? AppColors.warning
                          : AppColors.primary.withValues(alpha: 0.35),
                      width: isHinted ? 2.5 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isHinted
                            ? AppColors.warning.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    tile.word,
                    style: AppTypography.titleMedium.copyWith(
                      color:
                          isHinted ? AppColors.warning : AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
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

class _WordTile {
  final int id;
  final String word;

  const _WordTile({required this.id, required this.word});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _WordTile && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
