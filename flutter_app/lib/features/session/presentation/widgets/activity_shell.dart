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
import 'package:kita_english/features/session/presentation/widgets/build_sentence_activity.dart';
import 'package:kita_english/features/session/presentation/widgets/fill_blank_activity.dart';
import 'package:kita_english/features/session/presentation/widgets/listen_tap_activity.dart';
import 'package:kita_english/features/session/presentation/widgets/repeat_after_me_activity.dart';
import 'package:kita_english/features/session/presentation/widgets/sentence_builder_activity.dart';
import 'package:kita_english/features/session/presentation/widgets/phonics_activity.dart';
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
    with TickerProviderStateMixin {
  late final AnimationController _transitionController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late final AnimationController _encourageController;
  late Animation<double> _encourageOpacity;
  late Animation<double> _encourageScale;

  String? _encourageText;
  Color _encourageColor = AppColors.success;
  DateTime? _activityStartTime;
  int _attempts = 0;
  bool _textMode = false;

  @override
  void initState() {
    super.initState();
    // Transition animation with bouncy curve
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _transitionController.forward();

    // Encouragement text animation
    _encourageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _encourageOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _encourageController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _encourageScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _encourageController,
        curve: Curves.elasticOut,
      ),
    );

    _activityStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _encourageController.dispose();
    super.dispose();
  }

  void _showEncouragementAnimated(String text, Color color) {
    setState(() {
      _encourageText = text;
      _encourageColor = color;
    });
    _encourageController.forward(from: 0);
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
      final attemptCount = _attempts;
      final timeSpent = DateTime.now()
          .difference(_activityStartTime ?? DateTime.now())
          .inMilliseconds;
      final stars = ActivityResult.calculateStars(
        isCorrect: true,
        attempts: attemptCount,
      );

      _showEncouragementAnimated(_getEncouragement(true), AppColors.success);

      // After brief pause, submit result then transition
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;

        final result = ActivityResult(
          activityId: activity.id,
          activityType: activity.type.apiValue,
          isCorrect: true,
          attempts: attemptCount,
          timeSpentMs: timeSpent,
          starsEarned: stars,
          metadata: metadata,
        );

        // Submit updates state synchronously, then transition reads fresh state
        ref.read(sessionProvider.notifier).submitActivityResult(result);
        _transitionToNext();
      });
    } else {
      _attempts++;
      _showEncouragementAnimated(
          _getEncouragement(false), AppColors.secondary);

      ref.read(soundEffectsProvider).playWrong();
      // If too many attempts, move on
      if (_attempts >= 3) {
        final attemptCount = _attempts;
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;

          final timeSpent = DateTime.now()
              .difference(_activityStartTime ?? DateTime.now())
              .inMilliseconds;
          final result = ActivityResult(
            activityId: activity.id,
            activityType: activity.type.apiValue,
            isCorrect: false,
            attempts: attemptCount,
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

      // Read state FRESH after animation completes
      final freshState = ref.read(sessionProvider);
      final activityCount = freshState.session?.activityCount ?? 0;
      if (freshState.isSessionComplete ||
          freshState.currentActivityIndex >= activityCount) {
        final day = freshState.session?.dayNumber ?? 1;
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
        'Gi\u1ECFi l\u1EAFm! \u2B50',
        'Tuy\u1EC7t v\u1EDDi! \u{1F31F}',
        'Hay qu\u00E1! \u{1F44F}',
        '\u0110\u00FAng r\u1ED3i! \u{1F389}',
        'Si\u00EAu gi\u1ECFi! \u{1F3C6}',
      ];
      return options[DateTime.now().millisecond % options.length];
    } else {
      const options = [
        'Th\u1EED l\u1EA1i nha! \u{1F4AA}',
        'G\u1EA7n \u0111\u00FAng r\u1ED3i! \u{1F44D}',
        'C\u1ED1 l\u00EAn! \u{1F680}',
        'Kh\u00F4ng sao, th\u1EED l\u1EA1i nh\u00E9! \u{1F60A}',
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
                '\u0110ang t\u1EA3i b\u00E0i h\u1ECDc...',
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
                  child: const Text('Quay l\u1EA1i'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF5F3FF),
              Color(0xFFE8F4FD),
              Color(0xFFF8F6FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress bar + close button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Close button with circle background
                    GestureDetector(
                      onTap: _showExitConfirmation,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.close,
                            size: 22, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Colorful gradient progress bar
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              AnimatedFractionallySizedBox(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutBack,
                                widthFactor: progress.clamp(0.0, 1.0),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF7CD992),
                                        Color(0xFF4A90D9),
                                        Color(0xFFAB7BF7),
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(8)),
                                  ),
                                ),
                              ),
                              // Sheen effect
                              AnimatedFractionallySizedBox(
                                duration: const Duration(milliseconds: 500),
                                widthFactor: progress.clamp(0.0, 1.0),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.25),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Text mode toggle
                    GestureDetector(
                      onTap: () => setState(() => _textMode = !_textMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _textMode
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'TXT',
                          style: AppTypography.labelSmall.copyWith(
                            color: _textMode
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Activity counter badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${sessionState.currentActivityIndex + 1}/${sessionState.session?.activityCount ?? 0}',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Encouragement bubble with animated scale + opacity
              if (_encourageText != null)
                AnimatedBuilder(
                  animation: _encourageController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _encourageOpacity.value,
                      child: Transform.scale(
                        scale: _encourageScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: _encourageColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _encourageColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CharacterAvatar(
                            characterId: 'mochi', size: 36, animate: false),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _encourageText!,
                            style: AppTypography.titleSmall.copyWith(
                              color: _encourageColor,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Activity content with slide + fade transition
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildActivityWidget(activity),
                    ),
                  ),
                ),
              ),

              // Character buddy in corner — more prominent
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 6, left: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CharacterAvatar(
                      characterId: 'mochi',
                      size: 52,
                      speechText: _encourageText == null
                          ? null
                          : null, // only show speech on encourage
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityWidget(Activity activity) {
    if (_textMode) {
      return _buildTextModeWidget(activity);
    }

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
      case ActivityType.buildSentence:
        return BuildSentenceActivity(
          activity: activity,
          onComplete: _onActivityComplete,
        );
      case ActivityType.fillBlank:
        return FillBlankActivity(
          activity: activity,
          onComplete: _onActivityComplete,
        );
      case ActivityType.phonicsListen:
      case ActivityType.phonicsMatch:
        return PhonicsActivity(
          activity: activity,
          onComplete: _onActivityComplete,
        );
    }
  }

  Widget _buildTextModeWidget(Activity activity) {
    final sessionState = ref.read(sessionProvider);
    final index = sessionState.currentActivityIndex;
    final total = sessionState.session?.activityCount ?? 0;
    final phase = activity.config['phase'] as String? ?? '?';
    final decisionLog = sessionState.session?.decisionLog ?? [];
    final reason = index < decisionLog.length ? decisionLog[index] : '';

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\u{1F4CB} Activity ${index + 1}/$total [$phase]\n'
                'Type: ${activity.type.apiValue}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Content based on activity type
            _buildTextModeContent(activity),

            // Decision log reason
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\u{1F9E0} Why: $reason',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            if (activity.type == ActivityType.flashcardIntro)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _onActivityComplete(isCorrect: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Next',
                      style: TextStyle(fontSize: 16)),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _onActivityComplete(isCorrect: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('\u2705 Correct',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _onActivityComplete(isCorrect: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('\u274C Wrong',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextModeContent(Activity activity) {
    final config = activity.config;
    final lines = StringBuffer();

    switch (activity.type) {
      case ActivityType.flashcardIntro:
        final words = config['words'] as List<dynamic>? ?? [];
        lines.writeln('Words to learn:');
        for (final w in words) {
          if (w is Map<String, dynamic>) {
            final word = w['word'] ?? '?';
            final emoji = w['emoji'] ?? '';
            final vi = w['translation_vi'] ?? '';
            lines.writeln('  $emoji $word ($vi)');
          }
        }

      case ActivityType.listenTap:
      case ActivityType.listenAndChoose:
        final target = config['target_word'] ?? config['word'] ?? '?';
        final targetVi = config['target_vi'] ?? config['translation_vi'] ?? '';
        final targetEmoji = config['target_emoji'] ?? config['emoji'] ?? '';
        lines.writeln('Target: "$target" $targetEmoji ($targetVi)');
        lines.writeln('');
        final options = config['options'];
        if (options is List) {
          lines.writeln('Options:');
          final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
          for (var i = 0; i < options.length && i < letters.length; i++) {
            final opt = options[i];
            if (opt is Map<String, dynamic>) {
              final text = opt['text'] ?? '?';
              final correct = opt['is_correct'] == true;
              final marker = correct ? ' <-- correct' : '';
              lines.writeln('  ${letters[i]}. $text$marker');
            }
          }
        }

      case ActivityType.repeatAfterMe:
      case ActivityType.listenAndRepeat:
      case ActivityType.speakWord:
        final target = config['target_word'] ?? config['word'] ?? activity.targetWord ?? '?';
        final targetVi = config['target_vi'] ?? config['translation_vi'] ?? '';
        final targetEmoji = config['target_emoji'] ?? config['emoji'] ?? '';
        final ipa = config['phonetic_ipa'] ?? '';
        lines.writeln('Say: "$target" $targetEmoji');
        lines.writeln('Vietnamese: $targetVi');
        if (ipa.toString().isNotEmpty) {
          lines.writeln('IPA: /$ipa/');
        }

      case ActivityType.wordMatch:
        final pairs = config['pairs'] as List<dynamic>? ?? [];
        lines.writeln('Match the pairs:');
        for (final p in pairs) {
          if (p is Map<String, dynamic>) {
            final en = p['english'] ?? '?';
            final vi = p['vietnamese'] ?? '?';
            final emoji = p['emoji'] ?? '';
            lines.writeln('  $en $emoji = $vi');
          }
        }

      case ActivityType.buildSentence:
      case ActivityType.sentenceBuilder:
        final sentence = config['sentence'] ?? '?';
        final sentenceVi = config['sentence_vi'] ?? '';
        final scrambled = config['scrambled_words'] as List<dynamic>? ?? [];
        final correct = config['correct_order'] as List<dynamic>? ?? [];
        lines.writeln('Correct: "$sentence"');
        lines.writeln('Vietnamese: $sentenceVi');
        lines.writeln('Scrambled: ${scrambled.join(" | ")}');
        lines.writeln('Answer: ${correct.join(" ")}');

      case ActivityType.fillBlank:
        final display = config['display_sentence'] ?? config['sentence'] ?? '?';
        final sentenceVi = config['sentence_vi'] ?? '';
        final correctWord = config['correct_word'] ?? '?';
        final options = config['options'] as List<dynamic>? ?? [];
        lines.writeln('Sentence: $display');
        lines.writeln('Vietnamese: $sentenceVi');
        lines.writeln('');
        lines.writeln('Options:');
        final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
        for (var i = 0; i < options.length && i < letters.length; i++) {
          final opt = options[i].toString();
          final correct = opt == correctWord.toString();
          final marker = correct ? ' <-- correct' : '';
          lines.writeln('  ${letters[i]}. $opt$marker');
        }

      case ActivityType.phonicsListen:
        final symbol = config['symbol'] ?? '?';
        final word1 = config['word1'] ?? '?';
        final word2 = config['word2'] ?? '?';
        lines.writeln('Phoneme: /$symbol/');
        lines.writeln('Word 1: $word1');
        lines.writeln('Word 2: $word2');
        lines.writeln('Answer: Different');

      case ActivityType.phonicsMatch:
        final symbol = config['symbol'] ?? '?';
        final targetWord = config['target_word'] ?? '?';
        final options = config['options'] as List<dynamic>? ?? [];
        lines.writeln('Phoneme: /$symbol/');
        lines.writeln('Word: $targetWord');
        lines.writeln('Options:');
        for (final opt in options) {
          if (opt is Map<String, dynamic>) {
            final g = opt['grapheme'] ?? '?';
            final correct = opt['correct'] == true;
            final marker = correct ? ' <-- correct' : '';
            lines.writeln('  "$g"$marker');
          }
        }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        lines.toString().trimRight(),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.6,
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tho\u00E1t b\u00E0i h\u1ECDc?'),
        content: const Text(
          'N\u1EBFu tho\u00E1t, ti\u1EBFn tr\u00ECnh b\u00E0i h\u1ECDc s\u1EBD kh\u00F4ng \u0111\u01B0\u1EE3c l\u01B0u. B\u00E9 c\u00F3 mu\u1ED1n tho\u00E1t kh\u00F4ng?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('\u1EB2 l\u1EA1i'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(sessionProvider.notifier).reset();
              context.go('/home');
            },
            child: const Text(
              'Tho\u00E1t',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
