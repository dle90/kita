import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Sentence Builder / Word Spelling activity: scrambled letter tiles that the
/// kid taps in correct order to spell a word.
class SentenceBuilderActivity extends ConsumerStatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const SentenceBuilderActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  ConsumerState<SentenceBuilderActivity> createState() =>
      _SentenceBuilderActivityState();
}

class _SentenceBuilderActivityState
    extends ConsumerState<SentenceBuilderActivity>
    with TickerProviderStateMixin {
  late String _targetWord;
  late String _vietnameseHint;
  late List<String> _correctLetters;
  late List<_LetterTile> _availableTiles;
  final List<_LetterTile?> _placedTiles = [];
  int _wrongAttempts = 0;
  bool _isComplete = false;
  bool _showHint = false;
  final _tts = TtsService();

  // Bounce animation for placed tiles
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  static const _fallbackWords = [
    {'word': 'cat', 'vi': 'con m\u00E8o'},
    {'word': 'dog', 'vi': 'con ch\u00F3'},
    {'word': 'fish', 'vi': 'con c\u00E1'},
    {'word': 'apple', 'vi': 'qu\u1EA3 t\u00E1o'},
    {'word': 'bird', 'vi': 'con chim'},
    {'word': 'milk', 'vi': 's\u1EEFa'},
    {'word': 'book', 'vi': 's\u00E1ch'},
    {'word': 'happy', 'vi': 'vui'},
    {'word': 'water', 'vi': 'n\u01B0\u1EDBc'},
    {'word': 'rice', 'vi': 'c\u01A1m'},
  ];

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    final config = widget.activity.config;

    // Read target word from config or activity
    _targetWord = (config['target_word'] as String? ??
            widget.activity.targetWord ??
            '')
        .trim()
        .toLowerCase();

    // Read Vietnamese hint
    _vietnameseHint = config['vi'] as String? ??
        config['vietnamese'] as String? ??
        widget.activity.vietnameseTranslation ??
        '';

    // Fallback if no word
    if (_targetWord.isEmpty) {
      final shuffled = List<Map<String, String>>.from(_fallbackWords)
        ..shuffle();
      final pick = shuffled.first;
      _targetWord = pick['word']!;
      if (_vietnameseHint.isEmpty) {
        _vietnameseHint = pick['vi']!;
      }
    }

    _correctLetters = _targetWord.split('');

    // Create tiles with unique IDs (handles duplicate letters)
    _availableTiles = [];
    for (int i = 0; i < _correctLetters.length; i++) {
      _availableTiles.add(_LetterTile(id: i, letter: _correctLetters[i]));
    }
    _availableTiles.shuffle();

    // Empty placement slots
    _placedTiles.addAll(List.filled(_correctLetters.length, null));

    // Play the word via TTS
    _tts.speak(_targetWord);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _onTileTap(_LetterTile tile) {
    if (_isComplete) return;

    // Find first empty slot
    final emptyIndex = _placedTiles.indexOf(null);
    if (emptyIndex == -1) return;

    ref.read(soundEffectsProvider).playTap();

    setState(() {
      _placedTiles[emptyIndex] = tile;
      _availableTiles.remove(tile);
      _showHint = false;
    });

    // Trigger bounce animation
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
      _availableTiles.add(tile);
    });
  }

  void _checkAnswer() {
    final spelled =
        _placedTiles.map((t) => t?.letter ?? '').join();

    if (spelled == _targetWord) {
      setState(() => _isComplete = true);
      ref.read(soundEffectsProvider).playCorrect();
      _tts.speak(_targetWord);
      widget.onComplete(
        isCorrect: true,
        metadata: {
          'word': _targetWord,
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
            'word': _targetWord,
            'wrongAttempts': _wrongAttempts,
          },
        );
      } else {
        // Reset tiles back to available pool
        setState(() {
          for (int i = 0; i < _placedTiles.length; i++) {
            final tile = _placedTiles[i];
            if (tile != null) {
              _availableTiles.add(tile);
              _placedTiles[i] = null;
            }
          }
          _availableTiles.shuffle();
        });
      }
    }
  }

  void _onHintTap() {
    setState(() => _showHint = true);
    // Auto-hide after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  /// Returns the index of the next correct letter tile in _availableTiles.
  int? _getNextHintIndex() {
    final emptyIndex = _placedTiles.indexOf(null);
    if (emptyIndex == -1) return null;
    final nextLetter = _correctLetters[emptyIndex];
    for (int i = 0; i < _availableTiles.length; i++) {
      if (_availableTiles[i].letter == nextLetter) return i;
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
          'X\u1EBFp ch\u1EEF c\u00E1i \u0111\u1EC3 gh\u00E9p t\u1EEB! \u{1F9E9}',
          style: AppTypography.titleLarge.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Vietnamese hint card
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
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.secondary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _vietnameseHint,
                    style: AppTypography.vietnameseHint
                        .copyWith(fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // Listen button + hint button row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _tts.speak(_targetWord),
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
                      'Nghe t\u1EEB',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_isComplete) ...[
              const SizedBox(width: 12),
              // Hint button
              GestureDetector(
                onTap: _onHintTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lightbulb,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'G\u1EE3i \u00FD',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),

        // Answer slots — outlined empty tiles
        Container(
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
              final isCorrectlyPlaced =
                  _isComplete || (tile != null && _checkLetterAt(index));

              return GestureDetector(
                onTap: () => _onSlotTap(index),
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    // Only apply bounce to the last placed tile
                    final lastPlacedIndex = _placedTiles.lastIndexWhere(
                        (t) => t != null);
                    final shouldBounce =
                        index == lastPlacedIndex && _bounceController.isAnimating;
                    return Transform.scale(
                      scale: shouldBounce ? _bounceAnimation.value : 1.0,
                      child: child,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 52,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tile != null
                          ? _isComplete
                              ? AppColors.success
                              : isCorrectlyPlaced
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
                                color: (_isComplete || isCorrectlyPlaced
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
                      tile?.letter.toUpperCase() ?? '',
                      style: AppTypography.titleMedium.copyWith(
                        color:
                            tile != null ? Colors.white : AppColors.textHint,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const Spacer(),

        // Available letter tiles — look like physical blocks
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
                  width: 56,
                  height: 62,
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
                      // Bottom shadow to create 3D block feel
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tile.letter.toUpperCase(),
                        style: AppTypography.titleMedium.copyWith(
                          color: isHinted
                              ? AppColors.warning
                              : AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isHinted)
                        const Text('\u{1F449}',
                            style: TextStyle(fontSize: 10)),
                    ],
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

  /// Check if the letter placed at [index] is correct so far.
  bool _checkLetterAt(int index) {
    final tile = _placedTiles[index];
    if (tile == null) return false;
    return tile.letter == _correctLetters[index];
  }
}

/// A letter tile with a unique ID (to handle duplicate letters correctly).
class _LetterTile {
  final int id;
  final String letter;

  const _LetterTile({required this.id, required this.letter});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _LetterTile && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
