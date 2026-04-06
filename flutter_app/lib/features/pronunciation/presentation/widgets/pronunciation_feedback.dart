import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/pronunciation/domain/entities/phoneme_result.dart';
import 'package:kita_english/features/pronunciation/domain/entities/pronunciation_score.dart';

/// Shows the reference text with each word colored by pronunciation score.
/// Green (>80), Yellow (50-80), Red (<50). Tap a word to see phoneme details.
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

class _PronunciationFeedbackState extends State<PronunciationFeedback> {
  int? _selectedWordIndex;

  @override
  Widget build(BuildContext context) {
    final words = widget.referenceText.split(' ');
    final phonemes = widget.score.phonemes;

    // Group phonemes by word (simplified — distribute evenly)
    final phonemesPerWord = phonemes.isNotEmpty && words.isNotEmpty
        ? (phonemes.length / words.length).ceil()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Overall score
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _scoreColor(widget.score.pronunciationScore).withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _scoreIcon(widget.score.pronunciationScore),
                color: _scoreColor(widget.score.pronunciationScore),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.score.ratingVietnamese} - ${widget.score.pronunciationScore.toStringAsFixed(0)} điểm',
                style: AppTypography.titleSmall.copyWith(
                  color: _scoreColor(widget.score.pronunciationScore),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Colored words
        Wrap(
          spacing: 6,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(words.length, (index) {
            // Calculate word score from its phonemes
            final startPhoneme = index * phonemesPerWord;
            final endPhoneme =
                ((index + 1) * phonemesPerWord).clamp(0, phonemes.length);
            final wordPhonemes = phonemesPerWord > 0 && startPhoneme < phonemes.length
                ? phonemes.sublist(startPhoneme, endPhoneme)
                : <PhonemeResult>[];

            double wordScore;
            if (wordPhonemes.isNotEmpty) {
              wordScore = wordPhonemes.map((p) => p.score).reduce((a, b) => a + b) /
                  wordPhonemes.length;
            } else {
              // Default to overall score if no phoneme data
              wordScore = widget.score.pronunciationScore;
            }

            final isSelected = _selectedWordIndex == index;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedWordIndex =
                      _selectedWordIndex == index ? null : index;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _scoreColor(wordScore).withValues(alpha:0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(
                          color: _scoreColor(wordScore),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Text(
                  words[index],
                  style: TextStyle(
                    // fontFamily: 'NunitoSans',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor(wordScore),
                    height: 1.3,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        // Phoneme details for selected word
        if (_selectedWordIndex != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chi tiết phát âm:',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPhonemeDetails(_selectedWordIndex!, phonemesPerWord),
              ],
            ),
          ),
        ],

        // L1 error hints
        if (widget.score.l1Errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: AppColors.warning, size: 20,),
                    const SizedBox(width: 8),
                    Text(
                      'Gợi ý:',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...widget.score.l1Errors.map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $error',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhonemeDetails(int wordIndex, int phonemesPerWord) {
    final phonemes = widget.score.phonemes;
    final startPhoneme = wordIndex * phonemesPerWord;
    final endPhoneme =
        ((wordIndex + 1) * phonemesPerWord).clamp(0, phonemes.length);

    if (phonemesPerWord == 0 || startPhoneme >= phonemes.length) {
      return Text(
        'Không có dữ liệu chi tiết',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textHint,
        ),
      );
    }

    final wordPhonemes = phonemes.sublist(startPhoneme, endPhoneme);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: wordPhonemes.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _scoreColor(p.score).withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '/${p.phoneme}/',
                style: AppTypography.titleSmall.copyWith(
                  color: _scoreColor(p.score),
                ),
              ),
              Text(
                '${p.score.toStringAsFixed(0)}%',
                style: AppTypography.bodySmall.copyWith(
                  color: _scoreColor(p.score),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.pronExcellent;
    if (score >= 50) return AppColors.pronGood;
    return AppColors.pronNeedsWork;
  }

  IconData _scoreIcon(double score) {
    if (score >= 80) return Icons.star;
    if (score >= 50) return Icons.thumb_up;
    return Icons.refresh;
  }
}
