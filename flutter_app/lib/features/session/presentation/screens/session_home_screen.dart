import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/features/session/domain/entities/session.dart';
import 'package:kita_english/features/session/presentation/providers/session_provider.dart';
import 'package:kita_english/shared/widgets/character_avatar.dart';
import 'package:kita_english/shared/widgets/kita_button.dart';
import 'package:kita_english/shared/widgets/star_rating.dart';

class SessionHomeScreen extends ConsumerStatefulWidget {
  final int? initialDay;

  const SessionHomeScreen({super.key, this.initialDay});

  @override
  ConsumerState<SessionHomeScreen> createState() => _SessionHomeScreenState();
}

class _SessionHomeScreenState extends ConsumerState<SessionHomeScreen> {
  int _currentDay = 1;

  @override
  void initState() {
    super.initState();
    if (widget.initialDay != null) {
      _currentDay = widget.initialDay!;
    }
  }

  final _buddyMessages = const [
    'Ngày 1! Bắt đầu hành trình nào!',
    'Ngày 2! Hôm nay học về động vật nhé!',
    'Ngày 3! Cùng khám phá đồ ăn!',
    'Ngày 4! Học về màu sắc thôi!',
    'Ngày 5! Hôm nay học về gia đình!',
    'Ngày 6! Sắp hoàn thành rồi!',
    'Ngày 7! Ngày cuối cùng - thật tuyệt!',
  ];

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with progress button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CharacterAvatar(
                    characterId: 'mochi',
                    size: 48,
                  ),
                  Text(
                    'Kita English',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push(RoutePaths.progress),
                    icon: const Icon(
                      Icons.bar_chart_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Character buddy with speech bubble
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CharacterAvatar(characterId: 'mochi', size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _buddyMessages[(_currentDay - 1).clamp(0, 6)],
                        style: AppTypography.characterBubble,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Day circles path
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) => _buildDayPath(sessions),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildDayPath([]),
              ),
            ),

            // Start button
            Padding(
              padding: const EdgeInsets.all(24),
              child: KitaButton(
                label: 'Bắt đầu Ngày $_currentDay!',
                onPressed: () async {
                  await ref.read(sessionProvider.notifier).startSession(_currentDay);
                  if (mounted) {
                    context.push('/session/$_currentDay');
                  }
                },
                icon: Icons.play_arrow_rounded,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPath(List<Session> sessions) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: List.generate(7, (index) {
            final dayNumber = index + 1;
            final session = sessions.isNotEmpty && sessions.length > index
                ? sessions[index]
                : null;
            final isCompleted = session?.isCompleted ?? false;
            final isCurrent = dayNumber == _currentDay;
            final isLocked = dayNumber > _currentDay && !isCompleted;
            final stars = session?.totalStars ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Offset alternating circles for path effect
                  SizedBox(width: (index % 2 == 0) ? 0 : 60),
                  Expanded(
                    child: GestureDetector(
                      onTap: isLocked
                          ? null
                          : () {
                              setState(() => _currentDay = dayNumber);
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.primary
                              : isCompleted
                                  ? AppColors.successLight.withValues(alpha:0.3)
                                  : isLocked
                                      ? AppColors.surfaceVariant
                                      : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.primaryDark
                                : isCompleted
                                    ? AppColors.success
                                    : AppColors.surfaceVariant,
                            width: isCurrent ? 3 : 1,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha:0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Day circle
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.textOnPrimary
                                    : isCompleted
                                        ? AppColors.success
                                        : AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 24,
                                      )
                                    : isLocked
                                        ? const Icon(
                                            Icons.lock,
                                            color: AppColors.textHint,
                                            size: 20,
                                          )
                                        : Text(
                                            '$dayNumber',
                                            style: AppTypography.titleMedium
                                                .copyWith(
                                              color: isCurrent
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ngày $dayNumber',
                                    style: AppTypography.titleSmall.copyWith(
                                      color: isCurrent
                                          ? AppColors.textOnPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (dayNumber == 7)
                                    Text(
                                      'Ngày trình diễn!',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isCurrent
                                            ? AppColors.textOnPrimary
                                                .withValues(alpha:0.8)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isCompleted)
                              StarRating(
                                stars: (stars / 3).round().clamp(0, 3),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: (index % 2 == 0) ? 60 : 0),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
