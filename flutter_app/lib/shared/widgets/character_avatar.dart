import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';

/// Displays the selected character mascot with a floating idle animation
/// and optional speech bubble. Takes a [characterId] parameter to show
/// the correct mascot.
class CharacterAvatar extends StatefulWidget {
  final String characterId;
  final double size;
  final bool animate;
  final String? speechText;

  const CharacterAvatar({
    super.key,
    required this.characterId,
    this.size = 48,
    this.animate = true,
    this.speechText,
  });

  @override
  State<CharacterAvatar> createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _characterData(widget.characterId);

    Widget avatar = AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, widget.animate ? _bounceAnimation.value : 0),
          child: Transform.scale(
            scale: widget.animate ? _scaleAnimation.value : 1.0,
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              data.color.withValues(alpha: 0.3),
              data.color.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: data.color.withValues(alpha: 0.6),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            data.emoji,
            style: TextStyle(
              fontSize: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );

    // If there is speech text, wrap with a speech bubble
    if (widget.speechText != null && widget.speechText!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speech bubble
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: data.color.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              widget.speechText!,
              style: AppTypography.characterBubble.copyWith(
                fontSize: widget.size * 0.28 < 12 ? 12 : widget.size * 0.28,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Bubble pointer
          CustomPaint(
            size: const Size(16, 8),
            painter: _BubblePointerPainter(
              color: AppColors.surface,
              borderColor: data.color.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 2),
          avatar,
        ],
      );
    }

    return avatar;
  }

  _CharacterData _characterData(String id) {
    switch (id) {
      case 'mochi':
        return const _CharacterData(
          emoji: '\u{1F431}',
          color: AppColors.mochiCat,
        );
      case 'rong':
        return const _CharacterData(
          emoji: '\u{1F409}',
          color: AppColors.rongDragon,
        );
      case 'lua':
        return const _CharacterData(
          emoji: '\u{1F426}',
          color: AppColors.luaBird,
        );
      case 'bo':
        return const _CharacterData(
          emoji: '\u{1F916}',
          color: AppColors.boRobot,
        );
      default:
        return const _CharacterData(
          emoji: '\u{1F431}',
          color: AppColors.mochiCat,
        );
    }
  }
}

class _CharacterData {
  final String emoji;
  final Color color;

  const _CharacterData({required this.emoji, required this.color});
}

/// Paints a small downward-pointing triangle (speech bubble pointer).
class _BubblePointerPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _BubblePointerPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
