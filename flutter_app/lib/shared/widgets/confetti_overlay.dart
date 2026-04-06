import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';

/// Full-screen confetti animation triggered on achievements.
class ConfettiOverlay extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;

  const ConfettiOverlay({
    super.key,
    this.onComplete,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiPiece> _pieces;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _pieces = List.generate(60, (_) => _generatePiece());
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  _ConfettiPiece _generatePiece() {
    final colors = [
      AppColors.mochiCat,
      AppColors.rongDragon,
      AppColors.luaBird,
      AppColors.boRobot,
      AppColors.primary,
      AppColors.secondary,
      AppColors.starFilled,
      AppColors.success,
    ];

    return _ConfettiPiece(
      x: _random.nextDouble(),
      y: -_random.nextDouble() * 0.5,
      size: _random.nextDouble() * 8 + 4,
      color: colors[_random.nextInt(colors.length)],
      speed: _random.nextDouble() * 0.5 + 0.5,
      drift: (_random.nextDouble() - 0.5) * 0.3,
      rotation: _random.nextDouble() * 2 * pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 4,
      shape: _random.nextInt(3), // 0=circle, 1=square, 2=rectangle
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(
              pieces: _pieces,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiPiece {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double speed;
  final double drift;
  final double rotation;
  final double rotationSpeed;
  final int shape;

  const _ConfettiPiece({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final t = progress * piece.speed;
      final currentX =
          piece.x * size.width + sin(t * 3 + piece.drift * 10) * 40;
      final currentY = piece.y * size.height + t * size.height * 1.3;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      if (currentY > size.height || opacity <= 0) continue;

      final paint = Paint()
        ..color = piece.color.withValues(alpha:opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(piece.rotation + progress * piece.rotationSpeed * pi);

      switch (piece.shape) {
        case 0: // Circle
          canvas.drawCircle(Offset.zero, piece.size / 2, paint);
          break;
        case 1: // Square
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size,
              height: piece.size,
            ),
            paint,
          );
          break;
        case 2: // Rectangle (ribbon)
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size * 0.4,
              height: piece.size * 1.5,
            ),
            paint,
          );
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
