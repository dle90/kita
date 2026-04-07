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
      'Tuyệt vời! Giỏi lắm!',
      'Xuất sắc! Bé làm tốt quá!',
      'Hay quá! Cố lên nhé!',
      'Siêu giỏi! Tiếp tục nào!',
    ];
    final encourageText =
        encouragements[Random().nextInt(encouragements.length)];

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF8F6FF),
                  Color(0xFFEDE7FF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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

                  // Stars animation
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _starsController,
                      curve: Curves.elasticOut,
                    ),
                    child: Column(
                      children: [
                        StarRating(stars: displayStars, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          '$totalStars',
                          style: AppTypography.displayLarge.copyWith(
                            color: AppColors.starFilled,
                            fontSize: 56,
                          ),
                        ),
                        Text(
                          'ngôi sao',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Encouragement message
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _messageController,
                      curve: Curves.easeIn,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Ngày ${widget.dayNumber} hoàn thành!',
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          encourageText,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Accuracy display
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.track_changes,
                                color: AppColors.success,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Độ chính xác: ${accuracy.toStringAsFixed(0)}%',
                                style: AppTypography.titleSmall.copyWith(
                                  color: AppColors.success,
                                ),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lưu tiến trình học của bé!',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
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
                    Text(
                      widget.dayNumber < 6
                          ? 'Ngày mai sẽ có bài học mới đang chờ bé!'
                          : 'Còn một ngày nữa! Sắp hoàn thành thử thách rồi!',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),

                  // Action buttons
                  if (isDay7) ...[
                    KitaButton(
                      label: 'Thu âm trình diễn',
                      onPressed: () => context.go(RoutePaths.day7Record),
                      icon: Icons.mic,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 12),
                  ],

                  KitaButton(
                    label: 'Về trang chính',
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
}
