import 'package:kita_english/features/session/domain/entities/activity.dart';
import 'package:kita_english/features/session/domain/entities/activity_type.dart';

/// JSON-serializable model for [Activity].
///
/// Maps from the Go backend's Activity struct which has:
/// `activity_type`, `phase`, `config` (raw JSON), `vocabulary_ids`,
/// `sentence_ids`, `sort_order`.
///
/// Domain-level fields like `targetWord`, `targetSentence`, `audioUrl`,
/// `imageUrls`, `options`, `difficulty` are extracted from `config`.
class ActivityModel {
  final String id;
  final String activityType;
  final String phase;
  final Map<String, dynamic> config;
  final List<String> vocabularyIds;
  final List<String> sentenceIds;
  final int sortOrder;

  const ActivityModel({
    required this.id,
    required this.activityType,
    this.phase = '',
    this.config = const {},
    this.vocabularyIds = const [],
    this.sentenceIds = const [],
    this.sortOrder = 0,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as String? ?? '',
      activityType: json['activity_type'] as String? ?? 'listen_tap',
      phase: json['phase'] as String? ?? '',
      config: json['config'] as Map<String, dynamic>? ?? const {},
      vocabularyIds: (json['vocabulary_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sentenceIds: (json['sentence_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activity_type': activityType,
      'phase': phase,
      'config': config,
      'vocabulary_ids': vocabularyIds,
      'sentence_ids': sentenceIds,
      'sort_order': sortOrder,
    };
  }

  /// Converts this model to a domain [Activity] entity.
  /// Extracts domain-level fields from the `config` JSON.
  Activity toEntity() {
    final targetWord = config['target_word'] as String? ??
        config['targetWord'] as String?;
    final targetSentence = config['target_sentence'] as String? ??
        config['targetSentence'] as String?;
    final audioUrl =
        config['audio_url'] as String? ?? config['audioUrl'] as String?;
    final imageUrls = (config['image_urls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        (config['imageUrls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [];
    final optionsJson = (config['options'] as List<dynamic>?) ?? const [];
    final difficulty = config['difficulty'] as int? ?? 1;

    return Activity(
      id: id,
      type: ActivityType.fromString(activityType),
      targetWord: targetWord,
      targetSentence: targetSentence,
      audioUrl: audioUrl,
      imageUrls: imageUrls,
      options: optionsJson
          .map((o) => ActivityOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      difficulty: difficulty,
      config: config,
    );
  }
}
