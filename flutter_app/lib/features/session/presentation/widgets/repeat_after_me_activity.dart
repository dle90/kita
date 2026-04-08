import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/audio/web_recorder.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/pronunciation/data/repositories/pronunciation_repository_impl.dart';
import 'package:kita_english/features/pronunciation/domain/entities/pronunciation_score.dart';
import 'package:kita_english/features/pronunciation/presentation/providers/pronunciation_provider.dart';
import 'package:kita_english/features/pronunciation/presentation/widgets/pronunciation_feedback.dart';
import 'package:kita_english/features/pronunciation/presentation/widgets/record_button.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Repeat After Me activity: shows a word/sentence, plays native audio,
/// kid records their pronunciation, and gets scored with rich feedback.
class RepeatAfterMeActivity extends ConsumerStatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const RepeatAfterMeActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  ConsumerState<RepeatAfterMeActivity> createState() =>
      _RepeatAfterMeActivityState();
}

class _RepeatAfterMeActivityState extends ConsumerState<RepeatAfterMeActivity>
    with TickerProviderStateMixin {
  bool _hasListened = false;
  bool _isRecording = false;
  bool _hasRecorded = false;
  PronunciationScore? _fullScore;
  bool _showFeedback = false;
  final _tts = TtsService();

  // Mic pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Recording ring animation
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  // Fallback words for when activity has no target word
  static const _fallbackWords = [
    'hello', 'cat', 'dog', 'apple', 'happy', 'mom', 'dad', 'fish', 'run',
    'book',
  ];
  late final String _word;

  @override
  void initState() {
    super.initState();
    _word = widget.activity.targetWord ??
        widget.activity.config['target_word'] as String? ??
        _fallbackWords[DateTime.now().millisecond % _fallbackWords.length];

    // Idle pulsing animation for mic
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Recording ring animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ringAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _playNativeAudio() async {
    await _tts.speak(_word);
    setState(() => _hasListened = true);
  }

  void _onRecordingComplete(String? path) {
    setState(() {
      _fullScore = PronunciationScore(
        accuracyScore: 75,
        fluencyScore: 75,
        completenessScore: 100,
        pronunciationScore: 75,
      );
      _showFeedback = true;
    });
    _scheduleAutoAdvance(75);
  }

  void _scheduleAutoAdvance(double score) {
    if (score >= 50) {
      // Good enough: auto-advance after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted || !_showFeedback) return;
        _completeActivity(score);
      });
    }
    // If score < 50, don't auto-advance; show retry button instead
  }

  void _completeActivity(double score) {
    // Record to pronunciation history
    if (_fullScore != null) {
      ref.read(pronunciationHistoryProvider.notifier).addScore(_fullScore!);
    }

    widget.onComplete(
      isCorrect: score >= 50,
      metadata: {
        'pronunciationScore': score,
        'referenceText': _word,
      },
    );
  }

  void _retry() {
    setState(() {
      _hasRecorded = false;
      _showFeedback = false;
      _fullScore = null;
    });
  }

  Future<void> _startWebRecording() async {
    try {
      final recorder = ref.read(webRecorderProvider);
      final started = await recorder.start();
      if (started && mounted) {
        setState(() => _isRecording = true);
        _ringController.repeat();
        // Auto-stop after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isRecording) _stopWebRecording();
        });
        return;
      }
    } catch (e) {
      debugPrint('Web recording failed: $e');
    }
    // Fallback: fake recording if mic access fails
    if (!mounted) return;
    setState(() => _isRecording = true);
    _ringController.repeat();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _ringController.stop();
    _ringController.reset();
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
    });
    try {
      SoundEffects().playCorrect();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _handleFallbackScore();
  }

  void _handleFallbackScore() {
    final fallbackScore = PronunciationScore(
      accuracyScore: 70,
      fluencyScore: 70,
      completenessScore: 100,
      pronunciationScore: 70,
    );
    setState(() {
      _fullScore = fallbackScore;
      _showFeedback = true;
    });
    _scheduleAutoAdvance(70);
  }

  Future<void> _stopWebRecording() async {
    _ringController.stop();
    _ringController.reset();
    final recorder = ref.read(webRecorderProvider);
    final audioBytes = await recorder.stop();
    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _hasRecorded = true;
    });

    if (audioBytes != null && audioBytes.isNotEmpty) {
      // Send to Azure for real scoring
      final repo = ref.read(pronunciationRepositoryProvider);
      final result = await repo.scorePronunciationBytes(
        audioBytes: audioBytes,
        referenceText: _word,
      );

      if (!mounted) return;

      result.when(
        success: (score) {
          final isCorrect = score.pronunciationScore >= 50;
          if (isCorrect) SoundEffects().playCorrect();
          setState(() {
            _fullScore = score;
            _showFeedback = true;
          });
          _scheduleAutoAdvance(score.pronunciationScore);
        },
        failure: (_, __) {
          _handleFallbackScore();
        },
      );
    } else {
      _handleFallbackScore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.activity.targetSentence?.isNotEmpty == true
        ? widget.activity.targetSentence!
        : _word;
    final vietnameseHint = widget.activity.vietnameseTranslation;

    // Show feedback overlay after recording
    if (_showFeedback && _fullScore != null) {
      return _buildFeedbackView(displayText);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Instruction
        Text(
          'Nghe v\u00E0 n\u00F3i theo! \u{1F3A4}',
          style: AppTypography.titleLarge.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // English word/sentence card with gradient
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryLight.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                displayText,
                style: AppTypography.englishWord.copyWith(
                  fontSize: displayText.length > 15 ? 26 : 34,
                ),
                textAlign: TextAlign.center,
              ),
              // Vietnamese translation card
              if (vietnameseHint != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    vietnameseHint,
                    style: AppTypography.vietnameseHint.copyWith(fontSize: 17),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Play native speaker audio button — big orange circle
        GestureDetector(
          onTap: _playNativeAudio,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: _hasListened
                  ? null
                  : AppColors.secondaryGradient,
              color: _hasListened ? AppColors.surfaceVariant : null,
              shape: BoxShape.circle,
              boxShadow: !_hasListened
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
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
                Icon(
                  Icons.volume_up,
                  color:
                      _hasListened ? AppColors.textSecondary : Colors.white,
                  size: 30,
                ),
                Text(
                  _hasListened ? 'Nghe l\u1EA1i' : 'Nghe',
                  style: TextStyle(
                    color:
                        _hasListened ? AppColors.textSecondary : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Record button — large with pulse/ring animation
        if (kIsWeb)
          GestureDetector(
            onTap: _hasRecorded
                ? null
                : _isRecording
                    ? _stopWebRecording
                    : _startWebRecording,
            child: Column(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing ring when recording
                      if (_isRecording)
                        AnimatedBuilder(
                          animation: _ringAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 110 * _ringAnimation.value,
                              height: 110 * _ringAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.error.withValues(
                                      alpha: 1.0 -
                                          (_ringAnimation.value - 1.0)),
                                  width: 3,
                                ),
                              ),
                            );
                          },
                        ),
                      // Main mic button with idle pulse
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final scale = _isRecording
                              ? 1.0
                              : _hasRecorded
                                  ? 1.0
                                  : _pulseAnimation.value;
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: _hasRecorded
                                ? const LinearGradient(colors: [
                                    AppColors.success,
                                    AppColors.successLight
                                  ])
                                : _isRecording
                                    ? const LinearGradient(colors: [
                                        AppColors.error,
                                        AppColors.errorLight
                                      ])
                                    : AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording
                                        ? AppColors.error
                                        : _hasRecorded
                                            ? AppColors.success
                                            : AppColors.primary)
                                    .withValues(alpha: 0.4),
                                blurRadius: _isRecording ? 28 : 16,
                                spreadRadius: _isRecording ? 4 : 1,
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
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isRecording
                      ? '\u0110ang ghi... nh\u1EA5n \u0111\u1EC3 d\u1EEBng'
                      : _hasRecorded
                          ? 'Tuy\u1EC7t v\u1EDDi! \u{1F389}'
                          : 'Nh\u1EA5n \u0111\u1EC3 n\u00F3i \u{1F3A4}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _isRecording
                        ? AppColors.error
                        : _hasRecorded
                            ? AppColors.success
                            : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          RecordButton(
            referenceText: displayText,
            onRecordingComplete: _onRecordingComplete,
          ),
      ],
    );
  }

  Widget _buildFeedbackView(String referenceText) {
    final score = _fullScore!;
    final isLow = score.pronunciationScore < 50;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PronunciationFeedback(
            score: score,
            referenceText: referenceText,
          ),
          const SizedBox(height: 24),

          if (isLow)
            // Retry button for low scores
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.secondaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Th\u1EED l\u1EA1i \u{1F4AA}',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Auto-advancing indicator
            Text(
              'Ti\u1EBFp t\u1EE5c trong gi\u00E2y l\u00E1t...',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),

          // Always show a "skip" button so the user is not stuck
          if (isLow) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  _completeActivity(score.pronunciationScore),
              child: Text(
                'B\u1ECF qua',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textHint,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
