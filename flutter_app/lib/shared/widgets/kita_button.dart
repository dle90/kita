import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';

/// Large, rounded, colorful button with press animation (scale down).
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: widget.isSecondary
                  ? Border.all(
                      color: widget.color ?? AppColors.primary,
                      width: 2,
                    )
                  : null,
              boxShadow: widget.isSecondary || isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: bgColor.withValues(alpha:0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: fgColor,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: fgColor, size: 24),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: AppTypography.labelLarge.copyWith(
                            color: fgColor,
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
