import 'package:flutter/material.dart';
import 'package:kita_english/core/constants/app_colors.dart';

/// Displays the selected character mascot with a simple idle animation.
/// Takes a [characterId] parameter to show the correct mascot.
class CharacterAvatar extends StatefulWidget {
  final String characterId;
  final double size;
  final bool animate;

  const CharacterAvatar({
    super.key,
    required this.characterId,
    this.size = 48,
    this.animate = true,
  });

  @override
  State<CharacterAvatar> createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -4).animate(
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

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, widget.animate ? _bounceAnimation.value : 0),
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: data.color.withValues(alpha:0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: data.color.withValues(alpha:0.5),
            width: 2,
          ),
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
  }

  _CharacterData _characterData(String id) {
    switch (id) {
      case 'mochi':
        return const _CharacterData(
          emoji: '🐱',
          color: AppColors.mochiCat,
        );
      case 'rong':
        return const _CharacterData(
          emoji: '🐉',
          color: AppColors.rongDragon,
        );
      case 'lua':
        return const _CharacterData(
          emoji: '🐦',
          color: AppColors.luaBird,
        );
      case 'bo':
        return const _CharacterData(
          emoji: '🤖',
          color: AppColors.boRobot,
        );
      default:
        return const _CharacterData(
          emoji: '🐱',
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
