/// Result of a single activity attempt within a session.
class ActivityResult {
  final String activityId;
  final String activityType;
  final String? vocabularyId;
  final bool isCorrect;
  final int attempts;
  final int timeSpentMs;
  final int starsEarned;
  final Map<String, dynamic> metadata;

  const ActivityResult({
    required this.activityId,
    required this.activityType,
    this.vocabularyId,
    required this.isCorrect,
    this.attempts = 1,
    this.timeSpentMs = 0,
    this.starsEarned = 0,
    this.metadata = const {},
  });

  ActivityResult copyWith({
    String? activityId,
    String? activityType,
    String? vocabularyId,
    bool? isCorrect,
    int? attempts,
    int? timeSpentMs,
    int? starsEarned,
    Map<String, dynamic>? metadata,
  }) {
    return ActivityResult(
      activityId: activityId ?? this.activityId,
      activityType: activityType ?? this.activityType,
      vocabularyId: vocabularyId ?? this.vocabularyId,
      isCorrect: isCorrect ?? this.isCorrect,
      attempts: attempts ?? this.attempts,
      timeSpentMs: timeSpentMs ?? this.timeSpentMs,
      starsEarned: starsEarned ?? this.starsEarned,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Serializes to JSON matching Go backend's ActivityResultRequest.
  /// Note: activityId is not included because it's in the URL path.
  Map<String, dynamic> toJson() {
    return {
      'activity_type': activityType,
      if (vocabularyId != null) 'vocabulary_id': vocabularyId,
      'is_correct': isCorrect,
      'attempts': attempts,
      'time_spent_ms': timeSpentMs,
      'stars_earned': starsEarned,
      'metadata': metadata,
    };
  }

  factory ActivityResult.fromJson(Map<String, dynamic> json) {
    return ActivityResult(
      activityId: json['activity_id'] as String? ?? '',
      activityType: json['activity_type'] as String? ?? '',
      vocabularyId: json['vocabulary_id'] as String?,
      isCorrect: json['is_correct'] as bool? ?? false,
      attempts: json['attempts'] as int? ?? 1,
      timeSpentMs: json['time_spent_ms'] as int? ?? 0,
      starsEarned: json['stars_earned'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Calculates stars earned based on attempts and correctness.
  static int calculateStars({
    required bool isCorrect,
    required int attempts,
  }) {
    if (!isCorrect) return 0;
    if (attempts == 1) return 3;
    if (attempts == 2) return 2;
    return 1;
  }
}
