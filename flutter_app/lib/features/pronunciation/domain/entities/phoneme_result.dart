/// Result of scoring for an individual phoneme.
class PhonemeResult {
  final String phoneme;
  final double score;
  final bool isCorrect;
  final String? expected;
  final String? actual;

  const PhonemeResult({
    required this.phoneme,
    required this.score,
    required this.isCorrect,
    this.expected,
    this.actual,
  });

  factory PhonemeResult.fromJson(Map<String, dynamic> json) {
    return PhonemeResult(
      phoneme: json['phoneme'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      isCorrect: json['is_correct'] as bool? ?? false,
      expected: json['expected'] as String?,
      actual: json['actual'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneme': phoneme,
      'score': score,
      'is_correct': isCorrect,
      if (expected != null) 'expected': expected,
      if (actual != null) 'actual': actual,
    };
  }

  /// Whether the phoneme was pronounced well enough.
  bool get isGood => score >= 80;

  /// Whether the phoneme needs some work.
  bool get isFair => score >= 50 && score < 80;

  /// Whether the phoneme needs significant practice.
  bool get needsWork => score < 50;
}
