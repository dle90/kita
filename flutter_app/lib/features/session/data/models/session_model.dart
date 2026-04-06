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

  const SessionModel({
    required this.id,
    required this.dayNumber,
    this.activities = const [],
    this.isCompleted = false,
    this.completedAt,
    this.totalStars = 0,
    this.accuracyPct = 0.0,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final activitiesJson = json['activities'] as List<dynamic>? ?? [];
    final completedAt = json['completed_at'] as String?;
    return SessionModel(
      id: json['id'] as String? ?? '',
      dayNumber: json['day_number'] as int? ?? 1,
      activities: activitiesJson
          .map((a) => ActivityModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      isCompleted: completedAt != null,
      completedAt: completedAt,
      totalStars: json['total_stars'] as int? ?? 0,
      accuracyPct: (json['accuracy_pct'] as num?)?.toDouble() ?? 0.0,
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
    );
  }
}
