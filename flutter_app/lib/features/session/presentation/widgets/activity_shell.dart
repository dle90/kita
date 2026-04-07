import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/audio/sound_effects.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';
import 'package:kita_english/features/session/domain/entities/activity_result.dart';
import 'package:kita_english/features/session/domain/entities/activity_type.dart';
import 'package:kita_english/features/session/presentation/providers/session_provider.dart';
import 'package:kita_english/features/session/presentation/widgets/listen_tap_activity.dart';
import 'package:kita_english/features/session/presentation/widgets/repeat_after_me_activity.dart';
import 'package:kita_english/features/session/presentation/widgets/sentence_builder_activity.dart';
import 'package:kita_english/features/session/presentation/widgets/word_match_activity.dart';
import 'package:kita_english/shared/widgets/character_avatar.dart';

/// The main shell widget that wraps individual activities.
/// Shows progress bar, character buddy, and handles transitions.
class ActivityShell extends ConsumerStatefulWidget {
  const ActivityShell({super.key});

  @override
  ConsumerState<ActivityShell> createState() => _ActivityShellState();
}

class _ActivityShellState extends ConsumerState<ActivityShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transitionController;
  late Animation<Offset> _slideAnimation;
  String? _encourageText;
  Color _encourageColor = AppColors.success;
  DateTime? _activityStartTime;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
    ),);
    _transitionController.forward();
    _activityStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _onActivityComplete({
    required bool isCorrect,
    Map<String, dynamic> metadata = const {},
  }) {
    final sessionState = ref.read(sessionProvider);
    final activity = _currentActivity(sessionState);
    if (activity == null) return;

    if (isCorrect) {
      ref.read(soundEffectsProvider).playCorrect();
      _attempts++;
      final timeSpent = DateTime.now()
          .difference(_activityStartTime ?? DateTime.now())
          .inMilliseconds;
      final stars = ActivityResult.calculateStars(
        isCorrect: true,
        attempts: _attempts,
      );

      setState(() {
        _encourageText = _getEncouragement(true);
        _encourageColor = AppColors.success;
      });

      // Submit result and transition after a brief pause
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;

        final result = ActivityResult(
          activityId: activity.id,
          activityType: activity.type.apiValue,
          isCorrect: true,
          attempts: _attempts,
          timeSpentMs: timeSpent,
          starsEarned: stars,
          metadata: metadata,
        );

        ref.read(sessionProvider.notifier).submitActivityResult(result);
        _transitionToNext();
      });
    } else {
      _attempts++;
      setState(() {
        _encourageText = _getEncouragement(false);
        _encourageColor = AppColors.secondary;
      });

      ref.read(soundEffectsProvider).playWrong();
      // If too many attempts, move on
      if (_attempts >= 3) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;

          final timeSpent = DateTime.now()
              .difference(_activityStartTime ?? DateTime.now())
              .inMilliseconds;
          final result = ActivityResult(
            activityId: activity.id,
            activityType: activity.type.apiValue,
            isCorrect: false,
            attempts: _attempts,
            timeSpentMs: timeSpent,
            starsEarned: 0,
            metadata: metadata,
          );
          ref.read(sessionProvider.notifier).submitActivityResult(result);
          _transitionToNext();
        });
      }
    }
  }

  void _transitionToNext() {
    _transitionController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _encourageText = null;
        _attempts = 0;
        _activityStartTime = DateTime.now();
      });

      final sessionState = ref.read(sessionProvider);
      if (sessionState.isSessionComplete ||
          sessionState.currentActivityIndex >= (sessionState.session?.activityCount ?? 0)) {
        final day = sessionState.session?.dayNumber ?? 1;
        context.go('/session/$day/complete');
      } else {
        _transitionController.forward();
      }
    });
  }

  Activity? _currentActivity(SessionState state) {
    final session = state.session;
    if (session == null) return null;
    final index = state.currentActivityIndex;
    if (index >= session.activities.length) return null;
    return session.activities[index];
  }

  String _getEncouragement(bool isCorrect) {
    if (isCorrect) {
      const options = [
        'Giỏi lắm! ⭐',
        'Tuyệt vời!',
        'Hay quá!',
        'Đúng rồi! 🎉',
        'Siêu giỏi!',
      ];
      return options[DateTime.now().millisecond % options.length];
    } else {
      const options = [
        'Thử lại nha!',
        'Gần đúng rồi!',
        'Cố lên!',
        'Không sao, thử lại nhé!',
      ];
      return options[DateTime.now().millisecond % options.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final activity = _currentActivity(sessionState);
    final progress = sessionState.progress;

    if (sessionState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (activity == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Đang tải bài học...',
                style: AppTypography.bodyLarge,
              ),
              if (sessionState.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  sessionState.errorMessage!,
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Quay lại'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar + close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _showExitConfirmation(),
                    icon: const Icon(Icons.close, size: 28),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${sessionState.currentActivityIndex + 1}/${sessionState.session?.activityCount ?? 0}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Encouragement bubble
            if (_encourageText != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _encourageColor.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CharacterAvatar(characterId: 'mochi', size: 32),
                    const SizedBox(width: 8),
                    Text(
                      _encourageText!,
                      style: AppTypography.titleSmall.copyWith(
                        color: _encourageColor,
                      ),
                    ),
                  ],
                ),
              ),

            // Activity content with slide transition
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildActivityWidget(activity),
                ),
              ),
            ),

            // Character buddy in corner
            const Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(right: 16, bottom: 8),
                child: CharacterAvatar(characterId: 'mochi', size: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityWidget(Activity activity) {
    switch (activity.type) {
      case ActivityType.listenTap:
      case ActivityType.flashcardIntro:
      case ActivityType.listenAndChoose:
        return ListenTapActivity(
          activity: activity,
          onComplete: _onActivityComplete,
        );
      case ActivityType.repeatAfterMe:
      case ActivityType.listenAndRepeat:
      case ActivityType.speakWord:
        return RepeatAfterMeActivity(
          activity: activity,
          onComplete: _onActivityComplete,
        );
      case ActivityType.wordMatch:
        return WordMatchActivity(
          activity: activity,
          onComplete: _onActivityComplete,
        );
      case ActivityType.sentenceBuilder:
        return SentenceBuilderActivity(
          activity: activity,
          onComplete: _onActivityComplete,
        );
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát bài học?'),
        content: const Text(
          'Nếu thoát, tiến trình bài học sẽ không được lưu. Bé có muốn thoát không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(sessionProvider.notifier).reset();
              context.go('/home');
            },
            child: const Text(
              'Thoát',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
