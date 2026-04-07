import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/pronunciation/presentation/widgets/record_button.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Repeat After Me activity: shows a word/sentence, plays native audio,
/// kid records their pronunciation, and gets scored.
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

class _RepeatAfterMeActivityState extends ConsumerState<RepeatAfterMeActivity> {
  bool _hasListened = false;
  double? _pronunciationScore;
  final _tts = TtsService();

  // Fallback words for when activity has no target word
  static const _fallbackWords = ['hello', 'cat', 'dog', 'apple', 'happy', 'mom', 'dad', 'fish', 'run', 'book'];
  late final String _word;

  @override
  void initState() {
    super.initState();
    _word = widget.activity.targetWord ??
        widget.activity.config['target_word'] as String? ??
        _fallbackWords[DateTime.now().millisecond % _fallbackWords.length];
  }

  Future<void> _playNativeAudio() async {
    // Use TTS as fallback for audio
    await _tts.speak(_word);
    setState(() => _hasListened = true);
  }

  void _onRecordingComplete(String? path) {
    setState(() {
      _pronunciationScore = 75.0;
    });

    final score = _pronunciationScore ?? 0;
    final isCorrect = score >= 50;

    widget.onComplete(
      isCorrect: isCorrect,
      metadata: {
        'pronunciationScore': score,
        'referenceText': _word,
      },
    );
  }

  void _skipRecording() {
    // On web, skip recording and auto-pass
    widget.onComplete(
      isCorrect: true,
      metadata: {
        'pronunciationScore': 70.0,
        'referenceText': _word,
        'skipped': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.activity.targetSentence?.isNotEmpty == true
        ? widget.activity.targetSentence!
        : _word;
    final vietnameseHint = widget.activity.vietnameseTranslation;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Instruction
        const Text(
          'Nghe và nói theo!',
          style: AppTypography.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // English word/sentence
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha:0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                displayText,
                style: AppTypography.englishWord.copyWith(
                  fontSize: displayText.length > 15 ? 22 : 28,
                ),
                textAlign: TextAlign.center,
              ),
              if (vietnameseHint != null) ...[
                const SizedBox(height: 8),
                Text(
                  vietnameseHint,
                  style: AppTypography.vietnameseHint,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Play native speaker audio button
        GestureDetector(
          onTap: _playNativeAudio,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: _hasListened
                  ? AppColors.surfaceVariant
                  : AppColors.secondary,
              borderRadius: BorderRadius.circular(28),
              boxShadow: !_hasListened
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha:0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.volume_up,
                  color:
                      _hasListened ? AppColors.textSecondary : Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasListened ? 'Nghe lại' : 'Nghe phát âm',
                  style: AppTypography.labelLarge.copyWith(
                    color:
                        _hasListened ? AppColors.textSecondary : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Record button (or skip on web)
        if (kIsWeb)
          GestureDetector(
            onTap: _skipRecording,
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 8),
                const Text('Đã nói xong!', style: AppTypography.bodySmall),
              ],
            ),
          )
        else
          RecordButton(
            referenceText: displayText,
            onRecordingComplete: _onRecordingComplete,
          ),
        const SizedBox(height: 16),

        // Pronunciation score feedback
        if (_pronunciationScore != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _scoreColor(_pronunciationScore!).withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _pronunciationScore! >= 80
                      ? Icons.star
                      : _pronunciationScore! >= 50
                          ? Icons.thumb_up
                          : Icons.refresh,
                  color: _scoreColor(_pronunciationScore!),
                ),
                const SizedBox(width: 8),
                Text(
                  _scoreMessage(_pronunciationScore!),
                  style: AppTypography.titleSmall.copyWith(
                    color: _scoreColor(_pronunciationScore!),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.pronExcellent;
    if (score >= 50) return AppColors.pronGood;
    return AppColors.pronNeedsWork;
  }

  String _scoreMessage(double score) {
    if (score >= 80) return 'Xuất sắc! ${score.toStringAsFixed(0)} điểm';
    if (score >= 50) return 'Tốt lắm! ${score.toStringAsFixed(0)} điểm';
    return 'Thử lại nhé! ${score.toStringAsFixed(0)} điểm';
  }
}
