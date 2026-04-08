import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/features/session/presentation/providers/session_provider.dart';
import 'package:kita_english/shared/widgets/confetti_overlay.dart';
import 'package:kita_english/shared/widgets/kita_button.dart';
import 'package:kita_english/shared/widgets/star_rating.dart';

class SessionCompleteScreen extends ConsumerStatefulWidget {
  final int dayNumber;

  const SessionCompleteScreen({super.key, required this.dayNumber});

  @override
  ConsumerState<SessionCompleteScreen> createState() =>
      _SessionCompleteScreenState();
}

class _SessionCompleteScreenState extends ConsumerState<SessionCompleteScreen>
    with TickerProviderStateMixin {
  late final AnimationController _starsController;
  late final AnimationController _messageController;
  late final AnimationController _glowController;
  bool _showConfetti = true;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _messageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Play celebration sound
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) SoundEffects().playCelebration();
    });

    // Stagger animations
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _starsController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _messageController.forward();
    });
  }

  @override
  void dispose() {
    _starsController.dispose();
    _messageController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final totalStars = sessionState.totalStarsEarned;
    final accuracy = sessionState.accuracyPct;
    final isDay7 = widget.dayNumber == 7;

    // Calculate 0-3 display stars
    final maxPossible = (sessionState.session?.activityCount ?? 5) * 3;
    final displayStars = maxPossible > 0
        ? ((totalStars / maxPossible) * 3).round().clamp(0, 3)
        : 0;

    final encouragements = [
      'Tuyệt vời! Giỏi lắm! \u{1F31F}',
      'Xuất sắc! Bé làm tốt quá! \u{1F389}',
      'Hay quá! Cố lên nhé! \u{1F4AA}',
      'Siêu giỏi! Tiếp tục nào! \u{1F680}',
    ];
    final encourageText =
        encouragements[Random().nextInt(encouragements.length)];

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient - more celebratory
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF8F6FF),
                  Color(0xFFEDE7FF),
                  Color(0xFFFFF8E1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),

                  // Stars animation with glow
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _starsController,
                      curve: Curves.elasticOut,
                    ),
                    child: Column(
                      children: [
                        // Glowing star container
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.starFilled.withValues(
                                      alpha: 0.2 + _glowController.value * 0.15,
                                    ),
                                    blurRadius:
                                        20 + _glowController.value * 20,
                                    spreadRadius: _glowController.value * 8,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: StarRating(stars: displayStars, size: 52),
                        ),
                        const SizedBox(height: 20),
                        // Big star count
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFFFA000),
                              Color(0xFFFFD700),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            '$totalStars',
                            style: AppTypography.displayLarge.copyWith(
                              color: Colors.white,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ngôi sao \u{2B50}',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Encouragement message
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _messageController,
                      curve: Curves.easeIn,
                    ),
                    child: Column(
                      children: [
                        // Day complete badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Bài ${widget.dayNumber} hoàn thành! \u{1F3C6}',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Encouragement text with gradient
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.celebrationGradient
                                  .createShader(bounds),
                          child: Text(
                            encourageText,
                            style: AppTypography.headlineMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Progress summary card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Accuracy
                              _buildStatItem(
                                icon: Icons.track_changes_rounded,
                                color: AppColors.success,
                                value:
                                    '${accuracy.toStringAsFixed(0)}%',
                                label: 'Chính xác',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppColors.surfaceVariant,
                              ),
                              // Stars
                              _buildStatItem(
                                icon: Icons.star_rounded,
                                color: AppColors.starFilled,
                                value: '$totalStars',
                                label: 'Sao',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppColors.surfaceVariant,
                              ),
                              // Lesson
                              _buildStatItem(
                                icon: Icons.calendar_today_rounded,
                                color: AppColors.primary,
                                value: '${widget.dayNumber}/7',
                                label: 'Bài',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Day 1 account link prompt
                  if (widget.dayNumber == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            AppColors.primaryLight.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Lưu tiến trình học của bé! \u{1F4BE}',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          KitaButton(
                            label: 'Tạo tài khoản',
                            onPressed: () =>
                                context.push(RoutePaths.accountLink),
                            icon: Icons.person_add_outlined,
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Teaser message
                  if (!isDay7)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.dayNumber < 6
                            ? 'Bài tiếp theo đang chờ bé! \u{1F4DA}'
                            : 'Còn một bài nữa! Sắp hoàn thành thử thách rồi! \u{1F525}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Action buttons
                  if (isDay7) ...[
                    KitaButton(
                      label: 'Thu âm trình diễn \u{1F3A4}',
                      onPressed: () => context.go(RoutePaths.day7Record),
                      icon: Icons.mic_rounded,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 12),
                  ],

                  KitaButton(
                    label: 'Về trang chính \u{1F3E0}',
                    onPressed: () {
                      ref.read(sessionProvider.notifier).reset();
                      ref.invalidate(allSessionsProvider);
                      context.go(RoutePaths.home);
                    },
                    icon: Icons.home_rounded,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Confetti overlay
          if (_showConfetti)
            ConfettiOverlay(
              onComplete: () {
                setState(() => _showConfetti = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
