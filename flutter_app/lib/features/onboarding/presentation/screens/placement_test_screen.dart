import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/core/router/app_router.dart';
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
    with SingleTickerProviderStateMixin {
  int _currentRound = 0;
  final List<Map<String, dynamic>> _answers = [];
  late final AnimationController _encourageController;
  late final Animation<double> _encourageAnimation;
  String _encourageText = 'Bắt đầu nhé!';
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
    _encourageController.forward();
  }

  @override
  void dispose() {
    _encourageController.dispose();
    super.dispose();
  }

  void _showEncouragement(String text) {
    setState(() => _encourageText = text);
    _encourageController.reset();
    _encourageController.forward();
  }

  void _submitAnswer(Map<String, dynamic> answer) {
    _answers.add(answer);

    // Always show encouragement — no right/wrong feedback
    final encouragements = [
      'Tuyệt vời!',
      'Giỏi lắm!',
      'Hay quá!',
      'Bé làm tốt lắm!',
      'Cố lên nào!',
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
            content: Text('Đã xảy ra lỗi. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khám phá cùng bạn!'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _isSubmitting
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text(
                      'Đang chuẩn bị bài học cho bé...',
                      style: AppTypography.bodyLarge,
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      children: List.generate(4, (index) {
                        return Expanded(
                          child: Container(
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: index <= _currentRound
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Buddy encouragement bubble
                  ScaleTransition(
                    scale: _encourageAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha:0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🐱', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _encourageText,
                              style: AppTypography.characterBubble.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Current round
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildRound(_currentRound),
                    ),
                  ),
                ],
              ),
      ),
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

// --- Round 1: Listen & Tap ---
class _ListenAndTapRound extends StatefulWidget {
  final void Function(Map<String, dynamic> answer) onAnswer;

  const _ListenAndTapRound({required this.onAnswer});

  @override
  State<_ListenAndTapRound> createState() => _ListenAndTapRoundState();
}

class _ListenAndTapRoundState extends State<_ListenAndTapRound> {
  int? _selectedIndex;
  final int _correctIndex = 1; // "apple" is at index 1

  final _options = [
    {'label': 'Cat', 'emoji': '🐱'},
    {'label': 'Apple', 'emoji': '🍎'},
    {'label': 'Car', 'emoji': '🚗'},
    {'label': 'Book', 'emoji': '📖'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Nghe và chọn hình đúng:',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Play button — speaks the word aloud using TTS
        ElevatedButton.icon(
          onPressed: () {
            ref.read(ttsProvider).speak('apple');
          },
          icon: const Icon(Icons.volume_up, size: 28),
          label: const Text('Nghe'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = index);
                  Future.delayed(const Duration(milliseconds: 400), () {
                    widget.onAnswer({
                      'round': 1,
                      'type': 'listen_tap',
                      'selected': option['label'],
                      'correct': index == _correctIndex,
                    });
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight.withValues(alpha:0.3)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [
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
                      Text(
                        option['emoji']!,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option['label']!,
                        style: AppTypography.titleSmall,
                      ),
                    ],
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Hello!',
          style: AppTypography.englishWord,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Nói "Hello!" thật to nhé!',
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
            width: _isRecording ? 120 : 100,
            height: _isRecording ? 120 : 100,
            decoration: BoxDecoration(
              color: _isRecording
                  ? AppColors.error
                  : _hasRecorded
                      ? AppColors.success
                      : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? AppColors.error : AppColors.primary)
                      .withValues(alpha:0.4),
                  blurRadius: _isRecording ? 24 : 12,
                  spreadRadius: _isRecording ? 4 : 0,
                ),
              ],
            ),
            child: Icon(
              _hasRecorded
                  ? Icons.check
                  : _isRecording
                      ? Icons.stop
                      : Icons.mic,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isRecording
              ? 'Đang nghe...'
              : _hasRecorded
                  ? 'Tuyệt vời!'
                  : 'Nhấn để nói',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// --- Round 3: Read "cat" → tap matching picture ---
class _ReadAndMatchRound extends StatefulWidget {
  final void Function(Map<String, dynamic> answer) onAnswer;

  const _ReadAndMatchRound({required this.onAnswer});

  @override
  State<_ReadAndMatchRound> createState() => _ReadAndMatchRoundState();
}

class _ReadAndMatchRoundState extends State<_ReadAndMatchRound> {
  int? _selectedIndex;
  final int _correctIndex = 2; // "cat" is at index 2

  final _options = [
    {'emoji': '🐶', 'label': 'Dog'},
    {'emoji': '🐟', 'label': 'Fish'},
    {'emoji': '🐱', 'label': 'Cat'},
    {'emoji': '🐰', 'label': 'Rabbit'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Đọc từ này:',
          style: AppTypography.titleLarge,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'CAT',
            style: AppTypography.englishWord,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn hình phù hợp:',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = index);
                  Future.delayed(const Duration(milliseconds: 400), () {
                    widget.onAnswer({
                      'round': 3,
                      'type': 'read_match',
                      'selected': option['label'],
                      'correct': index == _correctIndex,
                    });
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight.withValues(alpha:0.3)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      option['emoji']!,
                      style: const TextStyle(fontSize: 56),
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

// --- Round 4: Phonics — which starts with same sound as "ball"? ---
class _PhonicsRound extends StatefulWidget {
  final void Function(Map<String, dynamic> answer) onAnswer;

  const _PhonicsRound({required this.onAnswer});

  @override
  State<_PhonicsRound> createState() => _PhonicsRoundState();
}

class _PhonicsRoundState extends State<_PhonicsRound> {
  int? _selectedIndex;
  final int _correctIndex = 0; // "banana" starts with "b" like "ball"

  final _options = [
    {'emoji': '🍌', 'label': 'Banana'},
    {'emoji': '🐱', 'label': 'Cat'},
    {'emoji': '🐶', 'label': 'Dog'},
    {'emoji': '🐟', 'label': 'Fish'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Từ nào bắt đầu giống\nâm của "Ball"?',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Illustration for "ball"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚽', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Text(
                'Ball',
                style: AppTypography.englishWord.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = index);
                  Future.delayed(const Duration(milliseconds: 400), () {
                    widget.onAnswer({
                      'round': 4,
                      'type': 'phonics',
                      'selected': option['label'],
                      'correct': index == _correctIndex,
                    });
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight.withValues(alpha:0.3)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        option['emoji']!,
                        style: const TextStyle(fontSize: 44),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option['label']!,
                        style: AppTypography.titleSmall,
                      ),
                    ],
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
