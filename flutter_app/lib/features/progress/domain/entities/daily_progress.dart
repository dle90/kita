/// Progress data for a single day.
class DailyProgress {
  final DateTime date;
  final int wordsLearned;
  final int wordsReviewed;
  final double avgPronScore;
  final bool sessionCompleted;
  final int totalTimeMs;

  const DailyProgress({
    required this.date,
    this.wordsLearned = 0,
    this.wordsReviewed = 0,
    this.avgPronScore = 0.0,
    this.sessionCompleted = false,
    this.totalTimeMs = 0,
  });

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    return DailyProgress(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      wordsLearned: json['wordsLearned'] as int? ?? 0,
      wordsReviewed: json['wordsReviewed'] as int? ?? 0,
      avgPronScore: (json['avgPronScore'] as num?)?.toDouble() ?? 0.0,
      sessionCompleted: json['sessionCompleted'] as bool? ?? false,
      totalTimeMs: json['totalTimeMs'] as int? ?? 0,
    );
  }

  /// Total time formatted as minutes.
  String get totalTimeFormatted {
    final minutes = (totalTimeMs / 60000).round();
    return '$minutes phút';
  }
}
