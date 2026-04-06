/// Represents a spaced repetition flashcard.
class SrsCard {
  final String id;
  final String vocabularyId;
  final String kidId;
  final int repetitions;
  final double easeFactor;
  final int intervalDays;
  final DateTime nextReviewDate;
  final DateTime? lastReviewDate;
  final int quality;

  const SrsCard({
    required this.id,
    required this.vocabularyId,
    required this.kidId,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.intervalDays = 1,
    required this.nextReviewDate,
    this.lastReviewDate,
    this.quality = 0,
  });

  SrsCard copyWith({
    String? id,
    String? vocabularyId,
    String? kidId,
    int? repetitions,
    double? easeFactor,
    int? intervalDays,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    int? quality,
  }) {
    return SrsCard(
      id: id ?? this.id,
      vocabularyId: vocabularyId ?? this.vocabularyId,
      kidId: kidId ?? this.kidId,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      quality: quality ?? this.quality,
    );
  }

  factory SrsCard.fromJson(Map<String, dynamic> json) {
    return SrsCard(
      id: json['id'] as String? ?? '',
      vocabularyId: json['vocabulary_id'] as String? ?? '',
      kidId: json['kid_id'] as String? ?? '',
      repetitions: json['repetitions'] as int? ?? 0,
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: json['interval_days'] as int? ?? 1,
      nextReviewDate:
          DateTime.tryParse(json['next_review_date'] as String? ?? '') ??
              DateTime.now(),
      lastReviewDate: json['last_review_date'] != null
          ? DateTime.tryParse(json['last_review_date'] as String)
          : null,
      quality: json['last_quality'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vocabulary_id': vocabularyId,
      'kid_id': kidId,
      'repetitions': repetitions,
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'next_review_date': nextReviewDate.toIso8601String(),
      if (lastReviewDate != null)
        'last_review_date': lastReviewDate!.toIso8601String(),
      'last_quality': quality,
    };
  }

  /// Whether this card is due for review.
  bool get isDue => nextReviewDate.isBefore(DateTime.now());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SrsCard && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
