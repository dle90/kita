import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';
import 'package:kita_english/features/session/domain/entities/activity_type.dart';

/// Listen & Tap activity: plays audio of a word, kid taps the matching image.
/// Also handles flashcard_intro (show words one-by-one) and listen_and_choose.
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

  // Flashcard intro state
  bool _isFlashcardMode = false;
  late List<Map<String, dynamic>> _flashcardWords;
  int _flashcardIndex = 0;

  // Fallback word data when no options are provided
  static const _fallbackWords = [
    {'word': 'hello', 'emoji': '\u{1F44B}', 'vi': 'xin ch\u00E0o'},
    {'word': 'cat', 'emoji': '\u{1F431}', 'vi': 'con m\u00E8o'},
    {'word': 'dog', 'emoji': '\u{1F436}', 'vi': 'con ch\u00F3'},
    {'word': 'apple', 'emoji': '\u{1F34E}', 'vi': 'qu\u1EA3 t\u00E1o'},
    {'word': 'happy', 'emoji': '\u{1F60A}', 'vi': 'vui'},
    {'word': 'sad', 'emoji': '\u{1F622}', 'vi': 'bu\u1ED3n'},
    {'word': 'mom', 'emoji': '\u{1F469}', 'vi': 'm\u1EB9'},
    {'word': 'dad', 'emoji': '\u{1F468}', 'vi': 'b\u1ED1'},
    {'word': 'fish', 'emoji': '\u{1F41F}', 'vi': 'con c\u00E1'},
    {'word': 'bird', 'emoji': '\u{1F426}', 'vi': 'con chim'},
    {'word': 'milk', 'emoji': '\u{1F95B}', 'vi': 's\u1EEFa'},
    {'word': 'rice', 'emoji': '\u{1F35A}', 'vi': 'c\u01A1m'},
    {'word': 'water', 'emoji': '\u{1F4A7}', 'vi': 'n\u01B0\u1EDBc'},
    {'word': 'run', 'emoji': '\u{1F3C3}', 'vi': 'ch\u1EA1y'},
    {'word': 'jump', 'emoji': '\u{1F938}', 'vi': 'nh\u1EA3y'},
    {'word': 'book', 'emoji': '\u{1F4D6}', 'vi': 's\u00E1ch'},
  ];

  List<Map<String, dynamic>> _quizOptions = [];
  String _targetWord = '';

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

    final config = widget.activity.config;

    // Check if this is flashcard_intro mode
    if (widget.activity.type == ActivityType.flashcardIntro) {
      _isFlashcardMode = true;
      _flashcardWords = _buildFlashcardWords(config);
      _flashcardIndex = 0;
      _targetWord = _flashcardWords.isNotEmpty
          ? (_flashcardWords[0]['word'] as String? ?? '')
          : '';
      _playAudio();
      return;
    }

    // Quiz mode: try config['options'] first
    final configOptions = config['options'];
    if (configOptions is List && configOptions.isNotEmpty) {
      _quizOptions = [];
      for (final opt in configOptions) {
        if (opt is Map) {
          _quizOptions.add(Map<String, dynamic>.from(opt));
        }
      }
      _targetWord = config['target_word'] as String? ??
          widget.activity.targetWord ??
          '';

      // Find the correct index
      for (int i = 0; i < _quizOptions.length; i++) {
        if (_quizOptions[i]['correct'] == true) {
          _correctIndex = i;
          break;
        }
      }
      // If no explicit correct flag, match by target_word
      if (_correctIndex == null && _targetWord.isNotEmpty) {
        for (int i = 0; i < _quizOptions.length; i++) {
          if ((_quizOptions[i]['word'] as String?)?.toLowerCase() ==
              _targetWord.toLowerCase()) {
            _correctIndex = i;
            break;
          }
        }
      }
      _correctIndex ??= 0;
    } else if (widget.activity.options.isNotEmpty) {
      // Use ActivityOption objects from parsed options
      _quizOptions = [];
      for (int i = 0; i < widget.activity.options.length; i++) {
        final opt = widget.activity.options[i];
        _quizOptions.add({
          'word': opt.text,
          'emoji': '',
          'correct': opt.isCorrect,
        });
        if (opt.isCorrect) {
          _correctIndex = i;
        }
      }
      _targetWord = widget.activity.targetWord ?? '';
      _correctIndex ??= 0;
    } else {
      // Fallback mode: generate quiz from fallback words
      final shuffled = List<Map<String, dynamic>>.from(
        _fallbackWords.map((w) => Map<String, dynamic>.from(w)),
      )..shuffle();
      _quizOptions = shuffled.take(4).toList();
      _targetWord = _quizOptions[0]['word'] as String;
      _quizOptions.shuffle();
      for (int i = 0; i < _quizOptions.length; i++) {
        if (_quizOptions[i]['word'] == _targetWord) {
          _correctIndex = i;
          break;
        }
      }
    }

    _playAudio();
  }

  List<Map<String, dynamic>> _buildFlashcardWords(
      Map<String, dynamic> config) {
    // Try config['words'] first (list of word objects)
    final words = config['words'];
    if (words is List && words.isNotEmpty) {
      return words
          .whereType<Map>()
          .map((w) => Map<String, dynamic>.from(w))
          .toList();
    }

    // Try config['options']
    final options = config['options'];
    if (options is List && options.isNotEmpty) {
      return options
          .whereType<Map>()
          .map((w) => Map<String, dynamic>.from(w))
          .toList();
    }

    // Single word from config
    final targetWord = config['target_word'] as String? ??
        widget.activity.targetWord;
    if (targetWord != null && targetWord.isNotEmpty) {
      return [
        {
          'word': targetWord,
          'emoji': config['emoji'] as String? ?? '',
          'vi': config['vi'] as String? ??
              config['vietnamese'] as String? ??
              widget.activity.vietnameseTranslation ??
              '',
        }
      ];
    }

    // Fallback
    final shuffled = List<Map<String, dynamic>>.from(
      _fallbackWords.map((w) => Map<String, dynamic>.from(w)),
    )..shuffle();
    return shuffled.take(3).toList();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_isFlashcardMode && _flashcardWords.isNotEmpty) {
      final word =
          _flashcardWords[_flashcardIndex]['word'] as String? ?? '';
      if (word.isNotEmpty) await _tts.speak(word);
    } else if (_targetWord.isNotEmpty) {
      await _tts.speak(_targetWord);
    }
  }

  void _onFlashcardNext() {
    ref.read(soundEffectsProvider).playTap();
    if (_flashcardIndex < _flashcardWords.length - 1) {
      setState(() {
        _flashcardIndex++;
      });
      _playAudio();
    } else {
      // All flashcards viewed
      ref.read(soundEffectsProvider).playCorrect();
      widget.onComplete(
        isCorrect: true,
        metadata: {'flashcardsViewed': _flashcardWords.length},
      );
    }
  }

  void _onOptionTap(int index) {
    if (_answered) return;

    setState(() => _selectedIndex = index);

    final isCorrect = index == _correctIndex;
    final selectedWord = _quizOptions[index]['word'] as String? ?? '';

    if (isCorrect) {
      ref.read(soundEffectsProvider).playCorrect();
      setState(() => _answered = true);
      widget.onComplete(
        isCorrect: true,
        metadata: {'selectedOption': selectedWord},
      );
    } else {
      ref.read(soundEffectsProvider).playWrong();
      _shakeController.forward(from: 0);
      widget.onComplete(
        isCorrect: false,
        metadata: {'selectedOption': selectedWord},
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _selectedIndex = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFlashcardMode) {
      return _buildFlashcardView();
    }
    return _buildQuizView();
  }

  Widget _buildFlashcardView() {
    if (_flashcardWords.isEmpty) {
      return const Center(child: Text('No words available'));
    }

    final current = _flashcardWords[_flashcardIndex];
    final word = current['word'] as String? ?? '';
    final emoji = current['emoji'] as String? ?? '';
    final vi = current['vi'] as String? ??
        current['vietnamese'] as String? ??
        '';
    final isLast = _flashcardIndex >= _flashcardWords.length - 1;

    return Column(
      children: [
        const Text(
          'H\u1ECDc t\u1EEB m\u1EDBi!',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Progress indicator
        Text(
          '${_flashcardIndex + 1} / ${_flashcardWords.length}',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textHint,
          ),
        ),
        const Spacer(),
        // Flashcard
        GestureDetector(
          onTap: _playAudio,
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji.isNotEmpty)
                  Text(emoji, style: const TextStyle(fontSize: 72)),
                if (emoji.isNotEmpty) const SizedBox(height: 16),
                Text(
                  word,
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: 32,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_up,
                        color: AppColors.secondary, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      'Ch\u1EA1m \u0111\u1EC3 nghe',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                if (vi.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    vi,
                    style: AppTypography.vietnameseHint.copyWith(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        const Spacer(),
        // Next button
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: SizedBox(
            width: 200,
            height: 52,
            child: ElevatedButton(
              onPressed: _onFlashcardNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: Text(
                isLast ? 'Ho\u00E0n t\u1EA5t \u2714' : 'Ti\u1EBFp theo \u2192',
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizView() {
    return Column(
      children: [
        // Instruction
        const Text(
          'Nghe v\u00E0 ch\u1ECDn h\u00ECnh \u0111\u00FAng!',
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
                  'Nghe l\u1EA1i',
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
            itemCount: _quizOptions.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              final isCorrectAnswer = _answered && index == _correctIndex;

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
                          ? AppColors.successLight.withValues(alpha: 0.3)
                          : isSelected
                              ? AppColors.errorLight.withValues(alpha: 0.3)
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
                                color:
                                    AppColors.success.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: _buildOptionContent(index, isCorrectAnswer),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionContent(int index, bool isCorrectAnswer) {
    final option = _quizOptions[index];
    final emoji = option['emoji'] as String? ?? '';
    final word = option['word'] as String? ?? '';
    final vi = option['vi'] as String? ??
        option['vietnamese'] as String? ??
        '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (emoji.isNotEmpty)
          Text(emoji, style: const TextStyle(fontSize: 48))
        else
          Text(
            word.isNotEmpty ? word[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 8),
        Text(
          word,
          style: AppTypography.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (vi.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            vi,
            style: AppTypography.vietnameseHint,
            textAlign: TextAlign.center,
          ),
        ],
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
