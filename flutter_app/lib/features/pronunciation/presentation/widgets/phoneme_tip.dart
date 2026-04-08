import 'package:flutter/material.dart';
import 'package:kita_english/core/audio/tts_service.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';

/// A reusable card showing phoneme learning information with Vietnamese tips.
/// Displayed after wrong answers in phonics activities, in pronunciation
/// feedback when L1 errors are detected, and on the progress dashboard
/// for weak phonemes.
class PhonemeTip extends StatelessWidget {
  final String symbol;
  final String mouthPositionVi;
  final String? exampleWord;
  final String? commonSubstitution;
  final String? substitutionVi;
  final bool showPlayButton;

  const PhonemeTip({
    super.key,
    required this.symbol,
    required this.mouthPositionVi,
    this.exampleWord,
    this.commonSubstitution,
    this.substitutionVi,
    this.showPlayButton = true,
  });

  /// Create a PhonemeTip from an activity config map.
  factory PhonemeTip.fromConfig(Map<String, dynamic> config) {
    return PhonemeTip(
      symbol: config['symbol'] as String? ?? '',
      mouthPositionVi: config['mouth_position_vi'] as String? ?? '',
      exampleWord: config['example_word'] as String?,
      commonSubstitution: config['common_substitution'] as String?,
      substitutionVi: config['substitution_vi'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phoneme symbol big
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '/$symbol/',
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 28,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (showPlayButton && exampleWord != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => TtsService().speak(exampleWord!),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volume_up,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Example word with phoneme highlighted
          if (exampleWord != null && exampleWord!.isNotEmpty)
            Text(
              '"$exampleWord"',
              style: AppTypography.titleMedium.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

          const SizedBox(height: 12),

          // Mouth position tip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u{1F4A1}', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: $mouthPositionVi',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Common mistake warning
          if (commonSubstitution != null &&
              commonSubstitution!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('\u{26A0}\u{FE0F}', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      substitutionVi ??
                          'Kh\u00f4ng n\u00f3i /$commonSubstitution/!',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
