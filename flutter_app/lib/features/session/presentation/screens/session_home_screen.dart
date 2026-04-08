import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
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

class _SessionHomeScreenState extends ConsumerState<SessionHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentDay = 1;
  late final AnimationController _buddyController;
  late final Animation<double> _buddyAnimation;

  static const _dayThemes = [
    {'icon': '\u{1F44B}', 'label': 'Chao hoi'},
    {'icon': '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}', 'label': 'Gia dinh'},
    {'icon': '\u{1F34E}', 'label': 'Do an'},
    {'icon': '\u{1F3C3}', 'label': 'Hanh dong'},
    {'icon': '\u{2600}\u{FE0F}', 'label': 'Thoi tiet'},
    {'icon': '\u{1F504}', 'label': 'On tap'},
    {'icon': '\u{1F389}', 'label': 'Trinh dien!'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDay != null) {
      _currentDay = widget.initialDay!;
    }
    _buddyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _buddyAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _buddyController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _buddyController.dispose();
    super.dispose();
  }

  final _buddyMessages = const [
    'Ngay 1! Bat dau hanh trinh nao! \u{1F680}',
    'Ngay 2! Hom nay hoc ve gia dinh nhe! \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}',
    'Ngay 3! Cung kham pha do an! \u{1F34E}',
    'Ngay 4! Hoc ve hanh dong thoi! \u{1F3C3}',
    'Ngay 5! Hom nay hoc ve thoi tiet! \u{2600}\u{FE0F}',
    'Ngay 6! Sap hoan thanh roi! \u{1F4AA}',
    'Ngay 7! Ngay cuoi cung - that tuyet! \u{1F389}',
  ];

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F6FF), Color(0xFFEDE7FF), Color(0xFFF5F0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with progress button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const CharacterAvatar(
                      characterId: 'mochi',
                      size: 48,
                    ),
                    Column(
                      children: [
                        Text(
                          'Kita English',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Thu thach 7 ngay \u{2728}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => context.push(RoutePaths.progress),
                        icon: const Icon(
                          Icons.bar_chart_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Character buddy with speech bubble - bigger
              AnimatedBuilder(
                animation: _buddyAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _buddyAnimation.value),
                    child: child,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryLight.withValues(alpha: 0.12),
                        AppColors.mochiCatAccent.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CharacterAvatar(characterId: 'mochi', size: 64),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _buddyMessages[(_currentDay - 1).clamp(0, 6)],
                            style: AppTypography.characterBubble.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Day circles path
              Expanded(
                child: sessionsAsync.when(
                  data: (sessions) {
                    // Auto-set current day to first incomplete session
                    if (widget.initialDay == null && sessions.isNotEmpty) {
                      final firstIncompleteDay = sessions
                          .where((s) => !s.isCompleted)
                          .map((s) => s.dayNumber)
                          .fold<int?>(null, (prev, day) =>
                              prev == null || day < prev ? day : prev);
                      final targetDay =
                          firstIncompleteDay ?? sessions.length + 1;
                      if (targetDay != _currentDay) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(
                                () => _currentDay = targetDay.clamp(1, 7));
                          }
                        });
                      }
                    }
                    return _buildDayPath(sessions);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _buildDayPath([]),
                ),
              ),

              // Start button - big play style
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: KitaButton(
                  label: 'Bat dau Ngay $_currentDay! \u{25B6}\u{FE0F}',
                  onPressed: () async {
                    ref.read(soundEffectsProvider).playTap();
                    await ref
                        .read(sessionProvider.notifier)
                        .startSession(_currentDay);
                    if (mounted) {
                      context.push('/session/$_currentDay');
                    }
                  },
                  icon: Icons.play_arrow_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayPath(List<Session> sessions) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
            final theme = _dayThemes[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // Winding path offset
                  SizedBox(width: (index % 2 == 0) ? 0 : 50),
                  Expanded(
                    child: GestureDetector(
                      onTap: isLocked
                          ? null
                          : () {
                              setState(() => _currentDay = dayNumber);
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        transform: isCurrent
                            ? Matrix4.diagonal3Values(1.03, 1.03, 1.0)
                            : Matrix4.identity(),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: isCurrent
                              ? AppColors.primaryGradient
                              : isCompleted
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.successLight
                                            .withValues(alpha: 0.25),
                                        AppColors.success
                                            .withValues(alpha: 0.1),
                                      ],
                                    )
                                  : null,
                          color: isCurrent || isCompleted
                              ? null
                              : isLocked
                                  ? AppColors.surfaceVariant
                                      .withValues(alpha: 0.6)
                                  : AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.primaryDark
                                : isCompleted
                                    ? AppColors.success
                                        .withValues(alpha: 0.5)
                                    : AppColors.surfaceVariant,
                            width: isCurrent ? 2.5 : 1.5,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            // Day theme icon circle
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : isCompleted
                                        ? AppColors.success
                                            .withValues(alpha: 0.15)
                                        : AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: Colors.white
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: isCompleted
                                    ? Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Text(
                                            theme['icon']!,
                                            style: const TextStyle(
                                                fontSize: 24),
                                          ),
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: const BoxDecoration(
                                                color: AppColors.success,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : isLocked
                                        ? const Icon(
                                            Icons.lock_rounded,
                                            color: AppColors.textHint,
                                            size: 22,
                                          )
                                        : Text(
                                            theme['icon']!,
                                            style: const TextStyle(
                                                fontSize: 26),
                                          ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ngay $dayNumber',
                                    style:
                                        AppTypography.titleSmall.copyWith(
                                      color: isCurrent
                                          ? Colors.white
                                          : isLocked
                                              ? AppColors.textHint
                                              : AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    theme['label']!,
                                    style:
                                        AppTypography.bodySmall.copyWith(
                                      color: isCurrent
                                          ? Colors.white
                                              .withValues(alpha: 0.85)
                                          : AppColors.textSecondary,
                                      fontSize: 13,
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
                            if (isCurrent && !isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Hom nay',
                                  style:
                                      AppTypography.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: (index % 2 == 0) ? 50 : 0),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
