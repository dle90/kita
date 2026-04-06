import 'package:kita_english/features/pronunciation/domain/entities/phoneme_result.dart';

/// Result of pronunciation scoring for a recorded utterance.
class PronunciationScore {
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double pronunciationScore;
  final List<PhonemeResult> phonemes;
  final List<Map<String, dynamic>> l1Errors;

  const PronunciationScore({
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.pronunciationScore,
    this.phonemes = const [],
    this.l1Errors = const [],
  });

  PronunciationScore copyWith({
    double? accuracyScore,
    double? fluencyScore,
    double? completenessScore,
    double? pronunciationScore,
    List<PhonemeResult>? phonemes,
    List<Map<String, dynamic>>? l1Errors,
  }) {
    return PronunciationScore(
      accuracyScore: accuracyScore ?? this.accuracyScore,
      fluencyScore: fluencyScore ?? this.fluencyScore,
      completenessScore: completenessScore ?? this.completenessScore,
      pronunciationScore: pronunciationScore ?? this.pronunciationScore,
      phonemes: phonemes ?? this.phonemes,
      l1Errors: l1Errors ?? this.l1Errors,
    );
  }

  /// Overall rating category.
  String get rating {
    if (pronunciationScore >= 80) return 'excellent';
    if (pronunciationScore >= 60) return 'good';
    if (pronunciationScore >= 40) return 'fair';
    return 'needs_practice';
  }

  /// Vietnamese rating display text.
  String get ratingVietnamese {
    if (pronunciationScore >= 80) return 'Xuất sắc';
    if (pronunciationScore >= 60) return 'Tốt';
    if (pronunciationScore >= 40) return 'Khá';
    return 'Cần luyện thêm';
  }

  /// Stars earned (0-3) based on pronunciation score.
  int get starsEarned {
    if (pronunciationScore >= 80) return 3;
    if (pronunciationScore >= 60) return 2;
    if (pronunciationScore >= 40) return 1;
    return 0;
  }
}
