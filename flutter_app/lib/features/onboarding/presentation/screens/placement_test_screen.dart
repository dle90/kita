import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/features/onboarding/presentation/providers/onboarding_provider.dart';


/// A quick stealth-assessment placement test with 4 mini games.
class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  ConsumerState<PlacementTestScreen> createState() =>
      _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen>
    with TickerProviderStateMixin {
  int _currentRound = 0;
  final List<Map<String, dynamic>> _answers = [];
  late final AnimationController _encourageController;
  late final Animation<double> _encourageAnimation;
  late final AnimationController _sparkleController;
  String _encourageText = 'Bat dau nhe! \u{1F31F}';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _encourageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _encourageAnimation = CurvedAnimation(
      parent: _encourageController,
      curve: Curves.elasticOut,
    );
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _encourageController.forward();
  }

  @override
  void dispose() {
    _encourageController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _showEncouragement(String text) {
    setState(() => _encourageText = text);
    _encourageController.reset();
    _encourageController.forward();
  }

  void _playSparkle() {
    _sparkleController.reset();
    _sparkleController.forward();
  }

  void _submitAnswer(Map<String, dynamic> answer) {
    final isCorrect = answer['correct'] == true;

    if (isCorrect) {
      ref.read(soundEffectsProvider).playCorrect();
      _playSparkle();
      _answers.add(answer);
      final encouragements = [
        'Tuyet voi! \u{2B50}',
        'Gioi lam! \u{1F389}',
        'Dung roi! \u{2728}',
        'Hay qua! \u{1F44F}',
      ];
      _showEncouragement(
        encouragements[Random().nextInt(encouragements.length)],
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        if (_currentRound < 3) {
          setState(() => _currentRound++);
        } else {
          _finishPlacement();
        }
      });
    } else {
      ref.read(soundEffectsProvider).playWrong();
      // Gentle wrong-answer feedback -- don't record, let them retry
      final nudges = [
        'Gan dung roi! Thu lai nha! \u{1F4AA}',
        'Chua dung, thu lan nua nhe! \u{1F60A}',
        'Khong sao, chon lai nha! \u{1F31F}',
      ];
      _showEncouragement(
        nudges[Random().nextInt(nudges.length)],
      );
    }
  }

  Future<void> _finishPlacement() async {
    setState(() => _isSubmitting = true);

    // Calculate a simple score based on answers
    int correctCount = 0;
    for (final answer in _answers) {
      if (answer['correct'] == true) correctCount++;
    }
    final score = (correctCount * 25).clamp(0, 100);

    ref.read(onboardingProvider.notifier).setPlacementScore(score);
    await ref.read(onboardingProvider.notifier).submitPlacementResults(
      answers: _answers,
    );

    // Submit the full onboarding
    final success =
        await ref.read(onboardingProvider.notifier).submitOnboarding();

    if (mounted) {
      if (success) {
        context.go(RoutePaths.home);
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Da xay ra loi. Vui long thu lai.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F6FF), Color(0xFFEDE7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isSubmitting
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Dang chuan bi bai hoc cho be... \u{1F4DA}',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cho chut nhe!',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Column(
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded,
                                    color: AppColors.primary),
                                onPressed: () => context.pop(),
                              ),
                              const Spacer(),
                              _buildStepIndicator(3, 3),
                              const Spacer(),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),

                        // Progress bar - round pills
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: Row(
                            children: List.generate(4, (index) {
                              final isComplete = index < _currentRound;
                              final isCurrent = index == _currentRound;
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutBack,
                                  height: 10,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    gradient: (isComplete || isCurrent)
                                        ? LinearGradient(
                                            colors: isCurrent
                                                ? [
                                                    AppColors.primary,
                                                    AppColors.primaryLight,
                                                  ]
                                                : [
                                                    AppColors.success,
                                                    AppColors.successLight,
                                                  ],
                                          )
                                        : null,
                                    color: (isComplete || isCurrent)
                                        ? null
                                        : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Round counter
                        Text(
                          'Cau ${_currentRound + 1} / 4',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),

                        // Buddy encouragement bubble - more prominent
                        ScaleTransition(
                          scale: _encourageAnimation,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 10,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryLight.withValues(alpha: 0.15),
                                  AppColors.mochiCatAccent
                                      .withValues(alpha: 0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.mochiCat
                                        .withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text('\u{1F431}',
                                        style: TextStyle(fontSize: 28)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _encourageText,
                                    style:
                                        AppTypography.characterBubble.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Current round
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildRound(_currentRound),
                          ),
                        ),
                      ],
                    ),

                    // Sparkle overlay on correct answers
                    if (_sparkleController.isAnimating)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _sparkleController,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _SparklePainter(
                                  progress: _sparkleController.value,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isActive = index < current;
        final isCurrent = index == current - 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 32 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildRound(int round) {
    switch (round) {
      case 0:
        return _ListenAndTapRound(onAnswer: _submitAnswer);
      case 1:
        return _SayHelloRound(onAnswer: _submitAnswer);
      case 2:
        return _ReadAndMatchRound(onAnswer: _submitAnswer);
      case 3:
        return _PhonicsRound(onAnswer: _submitAnswer);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Sparkle particle painter for correct answers.
class _SparklePainter extends CustomPainter {
  final double progress;
  _SparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (int i = 0; i < 12; i++) {
      final startX = rng.nextDouble() * size.width;
      final startY = rng.nextDouble() * size.height * 0.6 + size.height * 0.2;
      final dx = (rng.nextDouble() - 0.5) * 100 * progress;
      final dy = -rng.nextDouble() * 150 * progress;
      final radius = (3.0 + rng.nextDouble() * 4) * (1.0 - progress * 0.5);

      final colors = [
        AppColors.starFilled,
        AppColors.secondary,
        AppColors.mochiCat,
        AppColors.success,
      ];
      paint.color = colors[i % colors.length].withValues(alpha: opacity);

      canvas.drawCircle(
        Offset(startX + dx, startY + dy),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- Round 1: Listen & Tap ---
class _ListenAndTapRound extends StatefulWidget {
  final void Function(Map<String, dynamic> answer) onAnswer;

  const _ListenAndTapRound({required this.onAnswer});

  @override
  State<_ListenAndTapRound> createState() => _ListenAndTapRoundState();
}

class _ListenAndTapRoundState extends State<_ListenAndTapRound> {
  int? _selectedIndex;
  bool? _lastCorrect;
  bool _answered = false;
  final int _correctIndex = 1; // "apple" is at index 1
  final _tts = TtsService();

  final _options = [
    {'label': 'Cat', 'emoji': '\u{1F431}'},
    {'label': 'Apple', 'emoji': '\u{1F34E}'},
    {'label': 'Car', 'emoji': '\u{1F697}'},
    {'label': 'Book', 'emoji': '\u{1F4D6}'},
  ];

  void _onTap(int index) {
    if (_answered) return;
    final isCorrect = index == _correctIndex;
    setState(() {
      _selectedIndex = index;
      _lastCorrect = isCorrect;
    });
    if (isCorrect) {
      SoundEffects().playCorrect();
      _answered = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        widget.onAnswer({
          'round': 1,
          'type': 'listen_tap',
          'selected': _options[index]['label'],
          'correct': true,
        });
      });
    } else {
      SoundEffects().playWrong();
      // Wrong -- flash red, then clear for retry
      widget.onAnswer({
        'round': 1,
        'type': 'listen_tap',
        'selected': _options[index]['label'],
        'correct': false,
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() { _selectedIndex = null; _lastCorrect = null; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Nghe va chon hinh dung:',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        // Big friendly speaker button
        GestureDetector(
          onTap: () => _tts.speak('apple'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_up_rounded, size: 32, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'Nghe \u{1F50A}',
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              final isSelected = _selectedIndex == index;
              final isCorrectAnswer = isSelected && _lastCorrect == true;
              final isWrongAnswer = isSelected && _lastCorrect == false;
              return GestureDetector(
                onTap: () => _onTap(index),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 1.0,
                    end: isSelected ? 0.95 : 1.0,
                  ),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: isCorrectAnswer
                          ? AppColors.successLight.withValues(alpha: 0.3)
                          : isWrongAnswer
                              ? AppColors.errorLight.withValues(alpha: 0.3)
                              : AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isCorrectAnswer
                            ? AppColors.success
                            : isWrongAnswer
                                ? AppColors.error
                                : AppColors.surfaceVariant,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isCorrectAnswer
                              ? AppColors.success.withValues(alpha: 0.2)
                              : isWrongAnswer
                                  ? AppColors.error.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.06),
                          blurRadius: isSelected ? 16 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          option['emoji']!,
                          style: const TextStyle(fontSize: 52),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          option['label']!,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
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
    );
  }
}

// --- Round 2: Say "Hello!" (mic test) ---
class _SayHelloRound extends StatefulWidget {
  final void Function(Map<String, dynamic> answer) onAnswer;

  const _SayHelloRound({required this.onAnswer});

  @override
  State<_SayHelloRound> createState() => _SayHelloRoundState();
}

class _SayHelloRoundState extends State<_SayHelloRound> {
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _submitted = false;
  final _tts = TtsService();

  void _toggleRecording() {
    if (_isRecording) {
      // Stop recording
      setState(() {
        _isRecording = false;
        _hasRecorded = true;
      });
      // Auto-submit after recording
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onAnswer({
          'round': 2,
          'type': 'say_hello',
          'recorded': true,
          'correct': true, // Mic test always passes
        });
      });
    } else {
      // Start recording
      setState(() => _isRecording = true);
      // Auto-stop after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isRecording) {
          _toggleRecording();
        }
      });
    }
  }

  void _onWebDone() {
    widget.onAnswer({
      'round': 2,
      'type': 'say_hello',
      'recorded': true,
      'correct': true,
    });
  }

  Future<void> _onMicTap() async {
    if (_submitted) return;
    setState(() => _isRecording = true);
    try { _tts.speak('Hello'); } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() { _isRecording = false; _hasRecorded = true; _submitted = true; });
    try { SoundEffects().playCorrect(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _onWebDone();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big Hello text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              'Hello! \u{1F44B}',
              style: AppTypography.englishWord.copyWith(
                color: Colors.white,
                fontSize: 36,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Noi "Hello!" that to nhe!',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          // TTS play button - big friendly speaker
          GestureDetector(
            onTap: () => _tts.speak('Hello'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.secondaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_up_rounded, size: 32, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Nghe \u{1F50A}',
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Big mic button
          GestureDetector(
            onTap: _submitted ? null : _onMicTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: _isRecording ? 130 : 110,
              height: _isRecording ? 130 : 110,
              decoration: BoxDecoration(
                gradient: _submitted
                    ? const LinearGradient(
                        colors: [AppColors.success, AppColors.successLight],
                      )
                    : _isRecording
                        ? const LinearGradient(
                            colors: [AppColors.error, AppColors.errorLight],
                          )
                        : AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? AppColors.error : AppColors.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: _isRecording ? 30 : 16,
                    spreadRadius: _isRecording ? 6 : 0,
                  ),
                ],
              ),
              child: Icon(
                _submitted
                    ? Icons.check_rounded
                    : _isRecording
                        ? Icons.hearing_rounded
                        : Icons.mic_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording
                ? 'Dang nghe... \u{1F442}'
                : _submitted
                    ? 'Tuyet voi! \u{1F389}'
                    : 'Nhan de noi \u{1F3A4}',
            style: AppTypography.bodyLarge.copyWith(
              color: _submitted ? AppColors.success : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            'Hello! \u{1F44B}',
            style: AppTypography.englishWord.copyWith(
              color: Colors.white,
              fontSize: 36,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Noi "Hello!" that to nhe!',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 40),

        // Big mic button
        GestureDetector(
          onTap: _hasRecorded ? null : _toggleRecording,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: _isRecording ? 130 : 110,
            height: _isRecording ? 130 : 110,
            decoration: BoxDecoration(
              gradient: _isRecording
                  ? const LinearGradient(
                      colors: [AppColors.error, AppColors.errorLight],
                    )
                  : _hasRecorded
                      ? const LinearGradient(
                          colors: [AppColors.success, AppColors.successLight],
                        )
                      : AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? AppColors.error : AppColors.primary)
                      .withValues(alpha: 0.4),
                  blurRadius: _isRecording ? 30 : 16,
                  spreadRadius: _isRecording ? 6 : 0,
                ),
              ],
            ),
            child: Icon(
              _hasRecorded
                  ? Icons.check_rounded
                  : _isRecording
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isRecording
              ? 'Dang nghe... \u{1F442}'
              : _hasRecorded
                  ? 'Tuyet voi! \u{1F389}'
                  : 'Nhan de noi \u{1F3A4}',
          style: AppTypography.bodyLarge.copyWith(
            color: _hasRecorded ? AppColors.success : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// --- Round 3: Read "cat" -> tap matching picture ---
class _ReadAndMatchRound extends StatefulWidget {
  final void Function(Map<String, dynamic> answer) onAnswer;

  const _ReadAndMatchRound({required this.onAnswer});

  @override
  State<_ReadAndMatchRound> createState() => _ReadAndMatchRoundState();
}

class _ReadAndMatchRoundState extends State<_ReadAndMatchRound> {
  int? _selectedIndex;
  bool? _lastCorrect;
  bool _answered = false;
  final int _correctIndex = 2; // "cat" is at index 2

  final _options = [
    {'emoji': '\u{1F436}', 'label': 'Dog'},
    {'emoji': '\u{1F41F}', 'label': 'Fish'},
    {'emoji': '\u{1F431}', 'label': 'Cat'},
    {'emoji': '\u{1F430}', 'label': 'Rabbit'},
  ];

  void _onTap(int index) {
    if (_answered) return;
    final isCorrect = index == _correctIndex;
    setState(() { _selectedIndex = index; _lastCorrect = isCorrect; });
    if (isCorrect) {
      SoundEffects().playCorrect();
      _answered = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        widget.onAnswer({'round': 3, 'type': 'read_match', 'selected': _options[index]['label'], 'correct': true});
      });
    } else {
      SoundEffects().playWrong();
      widget.onAnswer({'round': 3, 'type': 'read_match', 'selected': _options[index]['label'], 'correct': false});
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() { _selectedIndex = null; _lastCorrect = null; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Doc tu nay:',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryLight.withValues(alpha: 0.2),
                AppColors.primary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Text(
            'CAT \u{1F431}',
            style: AppTypography.englishWord.copyWith(fontSize: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Chon hinh phu hop:',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              final isSelected = _selectedIndex == index;
              final isCorrectAnswer = isSelected && _lastCorrect == true;
              final isWrongAnswer = isSelected && _lastCorrect == false;
              return GestureDetector(
                onTap: () => _onTap(index),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 1.0,
                    end: isSelected ? 0.95 : 1.0,
                  ),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: isCorrectAnswer
                          ? AppColors.successLight.withValues(alpha: 0.3)
                          : isWrongAnswer
                              ? AppColors.errorLight.withValues(alpha: 0.3)
                              : AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isCorrectAnswer
                            ? AppColors.success
                            : isWrongAnswer
                                ? AppColors.error
                                : AppColors.surfaceVariant,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isCorrectAnswer
                              ? AppColors.success.withValues(alpha: 0.2)
                              : isWrongAnswer
                                  ? AppColors.error.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.06),
                          blurRadius: isSelected ? 16 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        option['emoji']!,
                        style: const TextStyle(fontSize: 60),
                      ),
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

// --- Round 4: Phonics -- which starts with same sound as "ball"? ---
class _PhonicsRound extends StatefulWidget {
  final void Function(Map<String, dynamic> answer) onAnswer;

  const _PhonicsRound({required this.onAnswer});

  @override
  State<_PhonicsRound> createState() => _PhonicsRoundState();
}

class _PhonicsRoundState extends State<_PhonicsRound> {
  int? _selectedIndex;
  bool? _lastCorrect;
  bool _answered = false;
  final int _correctIndex = 0; // "banana" starts with "b" like "ball"

  final _options = [
    {'emoji': '\u{1F34C}', 'label': 'Banana'},
    {'emoji': '\u{1F431}', 'label': 'Cat'},
    {'emoji': '\u{1F436}', 'label': 'Dog'},
    {'emoji': '\u{1F41F}', 'label': 'Fish'},
  ];

  void _onTap(int index) {
    if (_answered) return;
    final isCorrect = index == _correctIndex;
    setState(() { _selectedIndex = index; _lastCorrect = isCorrect; });
    if (isCorrect) {
      SoundEffects().playCorrect();
      _answered = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        widget.onAnswer({'round': 4, 'type': 'phonics', 'selected': _options[index]['label'], 'correct': true});
      });
    } else {
      SoundEffects().playWrong();
      widget.onAnswer({'round': 4, 'type': 'phonics', 'selected': _options[index]['label'], 'correct': false});
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() { _selectedIndex = null; _lastCorrect = null; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Tu nao bat dau giong\nam cua "Ball"?',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondaryLight.withValues(alpha: 0.25),
                AppColors.secondary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u{26BD}', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Text(
                'Ball',
                style: AppTypography.englishWord.copyWith(
                  color: AppColors.secondary,
                  fontSize: 32,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              final isSelected = _selectedIndex == index;
              final isCorrectAnswer = isSelected && _lastCorrect == true;
              final isWrongAnswer = isSelected && _lastCorrect == false;
              return GestureDetector(
                onTap: () => _onTap(index),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 1.0,
                    end: isSelected ? 0.95 : 1.0,
                  ),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: isCorrectAnswer
                          ? AppColors.successLight.withValues(alpha: 0.3)
                          : isWrongAnswer
                              ? AppColors.errorLight.withValues(alpha: 0.3)
                              : AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isCorrectAnswer
                            ? AppColors.success
                            : isWrongAnswer
                                ? AppColors.error
                                : AppColors.surfaceVariant,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isCorrectAnswer
                              ? AppColors.success.withValues(alpha: 0.2)
                              : isWrongAnswer
                                  ? AppColors.error.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.06),
                          blurRadius: isSelected ? 16 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          option['emoji']!,
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          option['label']!,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
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
    );
  }
}
