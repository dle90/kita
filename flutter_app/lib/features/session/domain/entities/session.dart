import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Represents a learning session for one day.
class Session {
  final String id;
  final int dayNumber;
  final List<Activity> activities;
  final bool isCompleted;
  final DateTime? completedAt;
  final int totalStars;
  final double accuracyPct;

  const Session({
    required this.id,
    required this.dayNumber,
    this.activities = const [],
    this.isCompleted = false,
    this.completedAt,
    this.totalStars = 0,
    this.accuracyPct = 0.0,
  });

  Session copyWith({
    String? id,
    int? dayNumber,
    List<Activity>? activities,
    bool? isCompleted,
    DateTime? completedAt,
    int? totalStars,
    double? accuracyPct,
  }) {
    return Session(
      id: id ?? this.id,
      dayNumber: dayNumber ?? this.dayNumber,
      activities: activities ?? this.activities,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      totalStars: totalStars ?? this.totalStars,
      accuracyPct: accuracyPct ?? this.accuracyPct,
    );
  }

  /// Number of activities in this session.
  int get activityCount => activities.length;

  /// Maximum stars achievable (3 per activity).
  int get maxStars => activityCount * 3;

  /// Star ratio for display.
  double get starRatio => maxStars > 0 ? totalStars / maxStars : 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
