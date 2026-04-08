import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';

/// A radar/spider chart showing the 4 language skill scores.
class SkillRadar extends StatelessWidget {
  final double listening;
  final double speaking;
  final double reading;
  final double writing;

  const SkillRadar({
    super.key,
    required this.listening,
    required this.speaking,
    required this.reading,
    required this.writing,
  });

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Ky nang ngon ngu',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: CustomPaint(
              size: const Size(double.infinity, 220),
              painter: _RadarPainter(
                values: [listening, speaking, reading, writing],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _SkillLabel(
                icon: Icons.headphones_rounded,
                label: 'Nghe',
                score: listening,
                color: AppColors.primary,
              ),
              _SkillLabel(
                icon: Icons.mic_rounded,
                label: 'Noi',
                score: speaking,
                color: AppColors.secondary,
              ),
              _SkillLabel(
                icon: Icons.menu_book_rounded,
                label: 'Doc',
                score: reading,
                color: AppColors.success,
              ),
              _SkillLabel(
                icon: Icons.edit_rounded,
                label: 'Viet',
                score: writing,
                color: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final double score;
  final Color color;

  const _SkillLabel({
    required this.icon,
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          '$label ${score.toStringAsFixed(0)}%',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> values; // [listening, speaking, reading, writing]

  _RadarPainter({required this.values});

  static const List<String> _labels = ['Nghe', 'Noi', 'Doc', 'Viet'];
  static const List<Color> _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.success,
    Color(0xFFE6A800), // darker accent for visibility
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 30;
    final sides = values.length;
    final angle = (2 * math.pi) / sides;

    // Draw grid rings at 25%, 50%, 75%, 100%
    final gridPaint = Paint()
      ..color = AppColors.surfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final ringRadius = radius * ring / 4;
      final path = Path();
      for (var i = 0; i < sides; i++) {
        final theta = -math.pi / 2 + angle * i;
        final x = center.dx + ringRadius * math.cos(theta);
        final y = center.dy + ringRadius * math.sin(theta);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines
    for (var i = 0; i < sides; i++) {
      final theta = -math.pi / 2 + angle * i;
      final x = center.dx + radius * math.cos(theta);
      final y = center.dy + radius * math.sin(theta);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // Draw filled data polygon
    final dataPath = Path();
    final dataPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final dataStrokePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (var i = 0; i < sides; i++) {
      final theta = -math.pi / 2 + angle * i;
      final value = (values[i] / 100).clamp(0.0, 1.0);
      final x = center.dx + radius * value * math.cos(theta);
      final y = center.dy + radius * value * math.sin(theta);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, dataStrokePaint);

    // Draw data points and labels
    for (var i = 0; i < sides; i++) {
      final theta = -math.pi / 2 + angle * i;
      final value = (values[i] / 100).clamp(0.0, 1.0);
      final x = center.dx + radius * value * math.cos(theta);
      final y = center.dy + radius * value * math.sin(theta);

      // Data point dot
      final dotPaint = Paint()
        ..color = _colors[i]
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Axis label
      final labelX = center.dx + (radius + 18) * math.cos(theta);
      final labelY = center.dy + (radius + 18) * math.sin(theta);
      final textPainter = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelX - textPainter.width / 2,
          labelY - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
