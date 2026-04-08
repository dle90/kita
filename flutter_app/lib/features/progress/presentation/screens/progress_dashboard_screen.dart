import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/progress/domain/entities/challenge_summary.dart';
import 'package:kita_english/features/progress/domain/entities/daily_progress.dart';
import 'package:kita_english/features/progress/presentation/providers/progress_provider.dart';
import 'package:kita_english/features/progress/presentation/widgets/skill_radar.dart';

/// Parent-facing progress dashboard with Vietnamese UI.
class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(progressOverviewProvider);
    final dailyAsync = ref.watch(dailyProgressProvider);
    final skillAsync = ref.watch(skillSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiến trình học'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Challenge summary card
              summaryAsync.when(
                data: (summary) => _SummaryCard(summary: summary),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => const _SummaryCard(
                  summary: ChallengeSummary(),
                ),
              ),
              const SizedBox(height: 24),

              // Stats row
              summaryAsync.when(
                data: (summary) => _StatsRow(summary: summary),
                loading: () => const SizedBox.shrink(),
                error: (_, __) =>
                    const _StatsRow(summary: ChallengeSummary()),
              ),
              const SizedBox(height: 24),

              // Skill radar chart
              skillAsync.when(
                data: (skills) => SkillRadar(
                  listening: skills.listening,
                  speaking: skills.speaking,
                  reading: skills.reading,
                  writing: skills.writing,
                ),
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SkillRadar(
                  listening: 0,
                  speaking: 0,
                  reading: 0,
                  writing: 0,
                ),
              ),
              const SizedBox(height: 16),

              // Mastery stats from skill data
              skillAsync.when(
                data: (skills) => _MasteryStatsRow(
                  wordsMastered: skills.wordsMastered,
                  wordsInProgress: skills.wordsInProgress,
                  weakestSkill: skills.weakestSkill,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Pronunciation trend placeholder
              _PronunciationTrendCard(),
              const SizedBox(height: 24),

              // Daily breakdown
              const Text(
                'Chi tiết hàng ngày',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 12),
              dailyAsync.when(
                data: (dailyList) => Column(
                  children: dailyList
                      .map((day) => _DailyProgressTile(progress: day))
                      .toList(),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (_, __) => Text(
                  'Chưa có dữ liệu.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ChallengeSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha:0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Tiến trình thử thách 7 ngày',
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: summary.progressRatio,
              minHeight: 16,
              backgroundColor: Colors.white.withValues(alpha:0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.daysCompleted} / 7 ngày',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.white,
            ),
          ),
          if (summary.isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hoàn thành! 🎉',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ChallengeSummary summary;

  const _StatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.book_outlined,
            value: '${summary.totalWords}',
            label: 'Từ đã học',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatItem(
            icon: Icons.mic_outlined,
            value: '${summary.avgScore.toStringAsFixed(0)}%',
            label: 'Phát âm TB',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatItem(
            icon: Icons.timer_outlined,
            value: summary.totalTimeFormatted,
            label: 'Thời gian',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PronunciationTrendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Xu hướng phát âm',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 16),
          // Placeholder chart area
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha:0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.show_chart,
                    size: 40,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Biểu đồ sẽ hiển thị sau khi hoàn thành 2+ ngày',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyProgressTile extends StatelessWidget {
  final DailyProgress progress;

  const _DailyProgressTile({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: progress.sessionCompleted
            ? AppColors.successLight.withValues(alpha:0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: progress.sessionCompleted
              ? AppColors.success.withValues(alpha:0.3)
              : AppColors.surfaceVariant,
        ),
      ),
      child: Row(
        children: [
          // Date circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: progress.sessionCompleted
                  ? AppColors.success
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${progress.date.day}',
                style: AppTypography.titleSmall.copyWith(
                  color: progress.sessionCompleted
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(progress.date),
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${progress.wordsLearned} từ mới • ${progress.totalTimeFormatted}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),

          // Pronunciation score
          if (progress.avgPronScore > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _pronColor(progress.avgPronScore).withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${progress.avgPronScore.toStringAsFixed(0)}%',
                style: AppTypography.labelSmall.copyWith(
                  color: _pronColor(progress.avgPronScore),
                ),
              ),
            ),

          if (progress.sessionCompleted)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle,
                  color: AppColors.success, size: 24,),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN',
    ];
    final weekday = weekdays[(date.weekday - 1) % 7];
    return '$weekday, ${date.day}/${date.month}';
  }

  Color _pronColor(double score) {
    if (score >= 80) return AppColors.pronExcellent;
    if (score >= 50) return AppColors.pronGood;
    return AppColors.pronNeedsWork;
  }
}

class _MasteryStatsRow extends StatelessWidget {
  final int wordsMastered;
  final int wordsInProgress;
  final String weakestSkill;

  const _MasteryStatsRow({
    required this.wordsMastered,
    required this.wordsInProgress,
    required this.weakestSkill,
  });

  String _skillLabel(String skill) {
    switch (skill) {
      case 'listening':
        return 'Nghe';
      case 'speaking':
        return 'Noi';
      case 'reading':
        return 'Doc';
      case 'writing':
        return 'Viet';
      default:
        return skill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.star_rounded,
            value: '$wordsMastered',
            label: 'Tu da thong thao',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatItem(
            icon: Icons.trending_up_rounded,
            value: '$wordsInProgress',
            label: 'Dang hoc',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatItem(
            icon: Icons.warning_amber_rounded,
            value: _skillLabel(weakestSkill),
            label: 'Can luyen them',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}
