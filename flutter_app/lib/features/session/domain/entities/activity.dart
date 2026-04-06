import 'package:kita_english/features/session/domain/entities/activity_type.dart';

/// Represents a single activity within a session.
class Activity {
  final String id;
  final ActivityType type;
  final String? targetWord;
  final String? targetSentence;
  final String? audioUrl;
  final List<String> imageUrls;
  final List<ActivityOption> options;
  final int difficulty;
  final Map<String, dynamic> config;

  const Activity({
    required this.id,
    required this.type,
    this.targetWord,
    this.targetSentence,
    this.audioUrl,
    this.imageUrls = const [],
    this.options = const [],
    this.difficulty = 1,
    this.config = const {},
  });

  Activity copyWith({
    String? id,
    ActivityType? type,
    String? targetWord,
    String? targetSentence,
    String? audioUrl,
    List<String>? imageUrls,
    List<ActivityOption>? options,
    int? difficulty,
    Map<String, dynamic>? config,
  }) {
    return Activity(
      id: id ?? this.id,
      type: type ?? this.type,
      targetWord: targetWord ?? this.targetWord,
      targetSentence: targetSentence ?? this.targetSentence,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      options: options ?? this.options,
      difficulty: difficulty ?? this.difficulty,
      config: config ?? this.config,
    );
  }

  /// Vietnamese translation from config, if available.
  String? get vietnameseTranslation =>
      config['vietnameseTranslation'] as String?;

  /// Reference text for pronunciation scoring.
  String get referenceText =>
      targetSentence ?? targetWord ?? '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Activity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// An option within an activity (for multiple choice, matching, etc.).
class ActivityOption {
  final String id;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
  final bool isCorrect;

  const ActivityOption({
    required this.id,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.isCorrect = false,
  });

  factory ActivityOption.fromJson(Map<String, dynamic> json) {
    return ActivityOption(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
      isCorrect: json['isCorrect'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      'isCorrect': isCorrect,
    };
  }
}
