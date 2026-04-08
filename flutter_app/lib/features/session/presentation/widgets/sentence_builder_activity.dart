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
    extends ConsumerState<SentenceBuilderActivity> {
  late String _targetWord;
  late String _vietnameseHint;
  late List<String> _correctLetters;
  late List<_LetterTile> _availableTiles;
  final List<_LetterTile?> _placedTiles = [];
  int _wrongAttempts = 0;
  bool _isComplete = false;
  final _tts = TtsService();

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

  void _onTileTap(_LetterTile tile) {
    if (_isComplete) return;

    // Find first empty slot
    final emptyIndex = _placedTiles.indexOf(null);
    if (emptyIndex == -1) return;

    ref.read(soundEffectsProvider).playTap();

    setState(() {
      _placedTiles[emptyIndex] = tile;
      _availableTiles.remove(tile);
    });

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instruction
        const Text(
          'X\u1EBFp c\u00E1c ch\u1EEF c\u00E1i \u0111\u1EC3 gh\u00E9p t\u1EEB!',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Vietnamese hint
        if (_vietnameseHint.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight.withValues(alpha: 0.15),
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
                    _vietnameseHint,
                    style: AppTypography.vietnameseHint,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // Listen button
        GestureDetector(
          onTap: () => _tts.speak(_targetWord),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
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
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Answer slots
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isComplete
                ? AppColors.successLight.withValues(alpha: 0.2)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isComplete ? AppColors.success : AppColors.surfaceVariant,
              width: _isComplete ? 2 : 1,
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(_placedTiles.length, (index) {
              final tile = _placedTiles[index];

              return GestureDetector(
                onTap: () => _onSlotTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tile != null
                        ? _isComplete
                            ? AppColors.success
                            : AppColors.primary
                        : AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: tile == null
                        ? Border.all(
                            color: AppColors.textHint.withValues(alpha: 0.3),
                          )
                        : null,
                  ),
                  child: Text(
                    tile?.letter.toUpperCase() ?? '_',
                    style: AppTypography.titleMedium.copyWith(
                      color: tile != null ? Colors.white : AppColors.textHint,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }),
          ),
        ),

        const Spacer(),

        // Available letter tiles
        if (!_isComplete)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _availableTiles.map((tile) {
              return GestureDetector(
                onTap: () => _onTileTap(tile),
                child: Container(
                  width: 52,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    tile.letter.toUpperCase(),
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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
                    color: AppColors.success, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Ch\u00EDnh x\u00E1c! \u{1F389}',
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
