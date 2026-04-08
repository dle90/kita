import 'package:flutter/material.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';

/// Large, rounded, colorful 3D button with satisfying press animation.
/// Has primary and secondary variants.
class KitaButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isLoading;
  final bool isSecondary;

  const KitaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
    this.isSecondary = false,
  });

  /// Secondary style variant.
  const KitaButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
  }) : isSecondary = true;

  @override
  State<KitaButton> createState() => _KitaButtonState();
}

class _KitaButtonState extends State<KitaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _translateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _translateAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final bgColor = widget.isSecondary
        ? Colors.transparent
        : (widget.color ?? AppColors.primary);
    final fgColor = widget.isSecondary
        ? (widget.color ?? AppColors.primary)
        : AppColors.textOnPrimary;

    // Darker shade for 3D bottom border
    final bottomColor = widget.isSecondary
        ? Colors.transparent
        : HSLColor.fromColor(bgColor)
            .withLightness(
                (HSLColor.fromColor(bgColor).lightness - 0.15).clamp(0.0, 1.0))
            .toColor();

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isDisabled
          ? null
          : () {
              SoundEffects().playTap();
              widget.onPressed!();
            },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _translateAnimation.value),
              child: child,
            ),
          );
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: widget.isSecondary
                  ? Border.all(
                      color: widget.color ?? AppColors.primary,
                      width: 2,
                    )
                  : Border(
                      bottom: BorderSide(
                        color: bottomColor,
                        width: 4,
                      ),
                    ),
              boxShadow: widget.isSecondary || isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: bgColor.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: widget.isLoading
                  ? _BouncingDots(color: fgColor)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: fgColor, size: 24),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.label,
                          style: AppTypography.labelLarge.copyWith(
                            color: fgColor,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouncing dots loading indicator for buttons.
class _BouncingDots extends StatefulWidget {
  final Color color;

  const _BouncingDots({required this.color});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Stagger the dots
            final delay = index * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final bounce = (t < 0.5)
                ? Curves.easeOut.transform(t * 2)
                : Curves.easeIn.transform((1.0 - t) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, -8 * bounce),
                child: child,
              ),
            );
          },
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
