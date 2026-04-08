import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/pronunciation/presentation/providers/pronunciation_provider.dart';

/// Shows a bar chart of the last 10 pronunciation scores.
/// Bars are colored green/yellow/red based on score thresholds.
class ScoreTrend extends ConsumerWidget {
  const ScoreTrend({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(pronunciationHistoryProvider);
    final scores = history.recentScores
        .map((s) => s.pronunciationScore)
        .toList();

    if (scores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Column(
          children: [
            const Text('\uD83C\uDFAF', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              'Ch\u01B0a c\u00F3 d\u1EEF li\u1EC7u',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'H\u00E3y luy\u1EC7n ph\u00E1t \u00E2m \u0111\u1EC3 xem ti\u1EBFn b\u1ED9!',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\uD83D\uDCC8', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Ti\u1EBFn b\u1ED9 ph\u00E1t \u00E2m',
                style: AppTypography.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarChartPainter(scores: scores),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.pronExcellent, label: '\u226580'),
              const SizedBox(width: 16),
              _LegendDot(color: AppColors.pronGood, label: '50-79'),
              const SizedBox(width: 16),
              _LegendDot(color: AppColors.pronNeedsWork, label: '<50'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
      ],
    );
  }
}

/// Custom painter that draws vertical bars for each score.
class _BarChartPainter extends CustomPainter {
  final List<double> scores;

  _BarChartPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final count = scores.length;
    const maxScore = 100.0;
    final barWidth = math.min(28.0, (size.width - 20) / count - 6);
    final totalBarsWidth = count * (barWidth + 6) - 6;
    final startX = (size.width - totalBarsWidth) / 2;

    // Draw light grid lines
    final gridPaint = Paint()
      ..color = AppColors.surfaceVariant
      ..strokeWidth = 1;

    for (final level in [25.0, 50.0, 75.0, 100.0]) {
      final y = size.height - (level / maxScore) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw bars
    for (var i = 0; i < count; i++) {
      final score = scores[i].clamp(0.0, maxScore);
      final barHeight = (score / maxScore) * (size.height - 4);
      final x = startX + i * (barWidth + 6);
      final y = size.height - barHeight;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(
        barRect,
        Paint()..color = _barColor(score),
      );

      // Score text on top
      final textPainter = TextPainter(
        text: TextSpan(
          text: score.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _barColor(score),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, y - 14),
      );
    }
  }

  Color _barColor(double score) {
    if (score >= 80) return AppColors.pronExcellent;
    if (score >= 50) return AppColors.pronGood;
    return AppColors.pronNeedsWork;
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.scores != scores;
}
