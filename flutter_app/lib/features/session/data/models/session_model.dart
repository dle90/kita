import 'package:kita_english/features/session/data/models/activity_model.dart';
import 'package:kita_english/features/session/domain/entities/session.dart';

/// JSON-serializable model for [Session].
class SessionModel {
  final String id;
  final int dayNumber;
  final List<ActivityModel> activities;
  final bool isCompleted;
  final String? completedAt;
  final int totalStars;
  final double accuracyPct;
  final List<String> decisionLog;

  const SessionModel({
    required this.id,
    required this.dayNumber,
    this.activities = const [],
    this.isCompleted = false,
    this.completedAt,
    this.totalStars = 0,
    this.accuracyPct = 0.0,
    this.decisionLog = const [],
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    // Defensively handle activities — may be null, list, or missing
    List<ActivityModel> activities = [];
    final rawActivities = json['activities'];
    if (rawActivities is List) {
      activities = rawActivities
          .whereType<Map<String, dynamic>>()
          .map((a) => ActivityModel.fromJson(a))
          .toList();
    }

    final completedAt = json['completed_at'] as String?;

    // Parse decision log from dynamic engine
    List<String> decisionLog = [];
    final rawLog = json['decision_log'];
    if (rawLog is List) {
      decisionLog = rawLog.map((e) => e.toString()).toList();
    }

    return SessionModel(
      id: json['id'] as String? ?? '',
      dayNumber: (json['day_number'] as num?)?.toInt() ?? 1,
      activities: activities,
      isCompleted: completedAt != null,
      completedAt: completedAt,
      totalStars: (json['total_stars'] as num?)?.toInt() ?? 0,
      accuracyPct: (json['accuracy_pct'] as num?)?.toDouble() ?? 0.0,
      decisionLog: decisionLog,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_number': dayNumber,
      'activities': activities.map((a) => a.toJson()).toList(),
      if (completedAt != null) 'completed_at': completedAt,
      'total_stars': totalStars,
      'accuracy_pct': accuracyPct,
    };
  }

  /// Converts this model to a domain [Session] entity.
  Session toEntity() {
    return Session(
      id: id,
      dayNumber: dayNumber,
      activities: activities.map((a) => a.toEntity()).toList(),
      isCompleted: isCompleted,
      completedAt:
          completedAt != null ? DateTime.tryParse(completedAt!) : null,
      totalStars: totalStars,
      accuracyPct: accuracyPct,
      decisionLog: decisionLog,
    );
  }
}
