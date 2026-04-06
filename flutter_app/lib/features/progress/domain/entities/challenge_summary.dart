/// Summary of the overall 7-day challenge progress.
class ChallengeSummary {
  final int daysCompleted;
  final int totalWords;
  final double avgScore;
  final int streak;
  final int totalTimeMs;

  const ChallengeSummary({
    this.daysCompleted = 0,
    this.totalWords = 0,
    this.avgScore = 0.0,
    this.streak = 0,
    this.totalTimeMs = 0,
  });

  factory ChallengeSummary.fromJson(Map<String, dynamic> json) {
    return ChallengeSummary(
      daysCompleted: json['daysCompleted'] as int? ?? 0,
      totalWords: json['totalWords'] as int? ?? 0,
      avgScore: (json['avgScore'] as num?)?.toDouble() ?? 0.0,
      streak: json['streak'] as int? ?? 0,
      totalTimeMs: json['totalTimeMs'] as int? ?? 0,
    );
  }

  /// Progress ratio (0.0 - 1.0) based on 7-day challenge.
  double get progressRatio => (daysCompleted / 7).clamp(0.0, 1.0);

  /// Whether the challenge is complete.
  bool get isComplete => daysCompleted >= 7;

  /// Total time formatted.
  String get totalTimeFormatted {
    final hours = totalTimeMs ~/ 3600000;
    final minutes = (totalTimeMs % 3600000) ~/ 60000;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '$minutes phút';
  }
}
