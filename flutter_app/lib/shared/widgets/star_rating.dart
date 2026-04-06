import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';

/// Shows 0-3 stars with fill animation.
class StarRating extends StatefulWidget {
  final int stars;
  final double size;
  final bool animate;

  const StarRating({
    super.key,
    required this.stars,
    this.size = 28,
    this.animate = true,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(StarRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stars != widget.stars && widget.animate) {
      _controller.reset();
      _controller.forward();
    }
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
        final isFilled = index < widget.stars;
        // Stagger each star's animation
        final delay = index * 0.25;
        final starAnimation = CurvedAnimation(
          parent: _controller,
          curve: Interval(
            delay,
            (delay + 0.5).clamp(0.0, 1.0),
            curve: Curves.elasticOut,
          ),
        );

        return AnimatedBuilder(
          animation: starAnimation,
          builder: (context, child) {
            final scale = isFilled ? starAnimation.value : 1.0;
            return Transform.scale(
              scale: scale.clamp(0.0, 1.2),
              child: child,
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size * 0.05),
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFilled ? AppColors.starFilled : AppColors.starEmpty,
              size: widget.size,
            ),
          ),
        );
      }),
    );
  }
}
