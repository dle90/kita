import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/pronunciation/domain/entities/phoneme_result.dart';
import 'package:kita_english/features/pronunciation/domain/entities/pronunciation_score.dart';

/// Shows rich pronunciation feedback: donut score, colored words,
/// tap-to-expand phoneme details, and L1 error tips in Vietnamese.
class PronunciationFeedback extends StatefulWidget {
  final PronunciationScore score;
  final String referenceText;

  const PronunciationFeedback({
    super.key,
    required this.score,
    required this.referenceText,
  });

  @override
  State<PronunciationFeedback> createState() => _PronunciationFeedbackState();
}

class _PronunciationFeedbackState extends State<PronunciationFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreAnim = Tween<double>(begin: 0, end: widget.score.pronunciationScore)
        .animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Group phonemes into per-word buckets (simple even distribution).
  List<List<PhonemeResult>> _groupPhonemesByWord() {
    final words = widget.referenceText.split(' ');
    final phonemes = widget.score.phonemes;
    if (phonemes.isEmpty || words.isEmpty) {
      return List.generate(words.length, (_) => <PhonemeResult>[]);
    }
    final perWord = (phonemes.length / words.length).ceil();
    return List.generate(words.length, (i) {
      final start = i * perWord;
      final end = ((i + 1) * perWord).clamp(0, phonemes.length);
      if (start >= phonemes.length) return <PhonemeResult>[];
      return phonemes.sublist(start, end);
    });
  }

  double _wordScore(List<PhonemeResult> wordPhonemes) {
    if (wordPhonemes.isEmpty) return widget.score.pronunciationScore;
    return wordPhonemes.map((p) => p.score).reduce((a, b) => a + b) /
        wordPhonemes.length;
  }

  void _showPhonemeSheet(
      BuildContext context, String word, List<PhonemeResult> phonemes) {
    final score = _wordScore(phonemes);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhonemeDetailSheet(
        word: word,
        phonemes: phonemes,
        wordScore: score,
        l1Errors: widget.score.l1Errors,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.referenceText.split(' ');
    final phonemeGroups = _groupPhonemesByWord();
    final overallScore = widget.score.pronunciationScore;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // -- Overall donut score --
          AnimatedBuilder(
            animation: _scoreAnim,
            builder: (context, _) => _DonutScore(
              score: _scoreAnim.value,
              emoji: _scoreEmoji(overallScore),
              label: _scoreLabel(overallScore),
            ),
          ),
          const SizedBox(height: 20),

          // -- Word-level coloring --
          Wrap(
            spacing: 6,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: List.generate(words.length, (i) {
              final ws = _wordScore(phonemeGroups[i]);
              return GestureDetector(
                onTap: () =>
                    _showPhonemeSheet(context, words[i], phonemeGroups[i]),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _scoreColor(ws).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _scoreColor(ws).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        words[i],
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor(ws),
                          height: 1.3,
                        ),
                      ),
                      Text(
                        '${ws.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _scoreColor(ws),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn vào từ để xem chi tiết',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textHint,
              fontSize: 13,
            ),
          ),

          // -- L1 error tips --
          if (widget.score.l1Errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            _L1ErrorTips(errors: widget.score.l1Errors),
          ],
        ],
      ),
    );
  }

  String _scoreEmoji(double score) {
    if (score >= 80) return '\u2B50'; // star
    if (score >= 60) return '\uD83D\uDC4D'; // thumbs up
    if (score >= 40) return '\uD83D\uDCAA'; // flexed biceps
    return '\uD83C\uDF1F'; // glowing star
  }

  String _scoreLabel(double score) {
    if (score >= 80) return 'Xu\u1EA5t s\u1EAFc!';
    if (score >= 60) return 'T\u1ED1t l\u1EAFm!';
    if (score >= 40) return 'C\u1ED1 l\u00EAn!';
    return 'Th\u1EED l\u1EA1i nh\u00E9!';
  }

  static Color _scoreColor(double score) {
    if (score >= 80) return AppColors.pronExcellent;
    if (score >= 50) return AppColors.pronGood;
    return AppColors.pronNeedsWork;
  }
}

// ---------------------------------------------------------------------------
// Donut score indicator
// ---------------------------------------------------------------------------
class _DonutScore extends StatelessWidget {
  final double score;
  final String emoji;
  final String label;

  const _DonutScore({
    required this.score,
    required this.emoji,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = _color(score);
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(130, 130),
            painter: _DonutPainter(
              progress: score / 100,
              color: color,
              trackColor: color.withValues(alpha: 0.15),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              Text(
                '${score.toStringAsFixed(0)}',
                style: AppTypography.displayMedium.copyWith(
                  color: color,
                  fontSize: 28,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _color(double s) {
    if (s >= 80) return AppColors.pronExcellent;
    if (s >= 50) return AppColors.pronGood;
    return AppColors.pronNeedsWork;
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _DonutPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = trackColor,
    );

    // Progress
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// Phoneme detail bottom sheet
// ---------------------------------------------------------------------------
class _PhonemeDetailSheet extends StatelessWidget {
  final String word;
  final List<PhonemeResult> phonemes;
  final double wordScore;
  final List<Map<String, dynamic>> l1Errors;

  const _PhonemeDetailSheet({
    required this.word,
    required this.phonemes,
    required this.wordScore,
    required this.l1Errors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Word header
          Text(
            word,
            style: AppTypography.displaySmall.copyWith(
              color: _scoreColor(wordScore),
            ),
          ),
          Text(
            '${wordScore.toStringAsFixed(0)}% \u2014 ${_wordLabel(wordScore)}',
            style: AppTypography.bodySmall.copyWith(
              color: _scoreColor(wordScore),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Phoneme grid
          if (phonemes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Kh\u00F4ng c\u00F3 d\u1EEF li\u1EC7u chi ti\u1EBFt',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textHint),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: phonemes.map((p) => _PhonemeChip(phoneme: p)).toList(),
            ),

          // Relevant L1 tips for this word
          ..._relevantTips(),
        ],
      ),
    );
  }

  List<Widget> _relevantTips() {
    // Show all L1 error tips since we can't precisely map errors to words
    if (l1Errors.isEmpty) return [];
    final tips = l1Errors
        .where((e) =>
            e['suggestion_vi'] != null &&
            (e['suggestion_vi'] as String).isNotEmpty)
        .toList();
    if (tips.isEmpty) return [];
    return [
      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 8),
      ...tips.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\uD83D\uDCA1 ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    e['suggestion_vi'] as String,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )),
    ];
  }

  String _wordLabel(double s) {
    if (s >= 80) return 'Tuy\u1EC7t v\u1EDDi!';
    if (s >= 50) return 'C\u1EA7n luy\u1EC7n th\u00EAm';
    return 'Th\u1EED l\u1EA1i nh\u00E9';
  }

  Color _scoreColor(double s) {
    if (s >= 80) return AppColors.pronExcellent;
    if (s >= 50) return AppColors.pronGood;
    return AppColors.pronNeedsWork;
  }
}

// ---------------------------------------------------------------------------
// Single phoneme chip with colored circle
// ---------------------------------------------------------------------------
class _PhonemeChip extends StatelessWidget {
  final PhonemeResult phoneme;

  const _PhonemeChip({required this.phoneme});

  @override
  Widget build(BuildContext context) {
    final color = _color(phoneme.score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colored circle indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '/${phoneme.phoneme}/',
            style: AppTypography.titleSmall.copyWith(
              color: color,
              fontSize: 18,
            ),
          ),
          if (phoneme.expected != null && phoneme.actual != null) ...[
            const SizedBox(height: 2),
            Text(
              '${phoneme.expected} \u2192 ${phoneme.actual}',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          Text(
            '${phoneme.score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _color(double s) {
    if (s >= 80) return AppColors.pronExcellent;
    if (s >= 50) return AppColors.pronGood;
    return AppColors.pronNeedsWork;
  }
}

// ---------------------------------------------------------------------------
// L1 Error Tips section
// ---------------------------------------------------------------------------
class _L1ErrorTips extends StatelessWidget {
  final List<Map<String, dynamic>> errors;

  const _L1ErrorTips({required this.errors});

  @override
  Widget build(BuildContext context) {
    final tips = errors
        .where((e) =>
            e['suggestion_vi'] != null &&
            (e['suggestion_vi'] as String).isNotEmpty)
        .toList();
    if (tips.isEmpty) {
      // Fallback: show error type descriptions
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warningLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('\uD83D\uDCA1', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'G\u1EE3i \u00FD:',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...errors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '\u2022 ${_errorTypeLabel(e['type'] as String? ?? '')}',
                    style: AppTypography.bodySmall,
                  ),
                )),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\uD83D\uDCA1', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'G\u1EE3i \u00FD luy\u1EC7n ph\u00E1t \u00E2m:',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map((e) {
            final severity = e['severity'] as String? ?? 'low';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: severity == 'high'
                          ? AppColors.pronNeedsWork
                          : severity == 'medium'
                              ? AppColors.pronGood
                              : AppColors.pronExcellent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e['expected_phoneme'] != null &&
                            e['actual_phoneme'] != null)
                          Text(
                            '/${e['expected_phoneme']}/ \u2192 /${e['actual_phoneme']}/',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        Text(
                          e['suggestion_vi'] as String,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _errorTypeLabel(String type) {
    switch (type) {
      case 'th_substitution':
        return 'L\u1ED7i \u00E2m "th" \u2014 c\u1EA7n \u0111\u1EB7t l\u01B0\u1EE1i gi\u1EEFa hai h\u00E0m r\u0103ng';
      case 'final_consonant_drop':
        return 'Thi\u1EBFu \u00E2m cu\u1ED1i \u2014 nh\u1EDB ph\u00E1t \u00E2m r\u00F5 ph\u1EA5t \u00E2m cu\u1ED1i';
      case 'r_l_confusion':
        return 'L\u1EABn r/l \u2014 cu\u1ED9n l\u01B0\u1EE1i cho \u00E2m "r"';
      case 'vowel_length':
        return 'L\u1ED7i \u0111\u1ED9 d\u00E0i nguy\u00EAn \u00E2m';
      case 'cluster_simplification':
        return 'C\u1EE5m ph\u1EE5 \u00E2m \u2014 ph\u00E1t \u00E2m \u0111\u1EA7y \u0111\u1EE7 c\u00E1c \u00E2m';
      case 'w_v_confusion':
        return 'L\u1EABn w/v \u2014 m\u00F4i tr\u00F2n cho \u00E2m "w"';
      default:
        return type;
    }
  }
}
