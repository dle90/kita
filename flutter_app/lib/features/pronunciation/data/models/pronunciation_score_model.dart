import 'package:kita_english/features/pronunciation/domain/entities/phoneme_result.dart';
import 'package:kita_english/features/pronunciation/domain/entities/pronunciation_score.dart';

/// JSON-serializable model for [PronunciationScore].
class PronunciationScoreModel {
  final String id;
  final String kidId;
  final String referenceText;
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double pronunciationScore;
  final List<Map<String, dynamic>> phonemeResults;
  final List<Map<String, dynamic>> l1Errors;

  const PronunciationScoreModel({
    this.id = '',
    this.kidId = '',
    this.referenceText = '',
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.pronunciationScore,
    this.phonemeResults = const [],
    this.l1Errors = const [],
  });

  factory PronunciationScoreModel.fromJson(Map<String, dynamic> json) {
    return PronunciationScoreModel(
      id: json['id'] as String? ?? '',
      kidId: json['kid_id'] as String? ?? '',
      referenceText: json['reference_text'] as String? ?? '',
      accuracyScore:
          (json['accuracy_score'] as num?)?.toDouble() ?? 0.0,
      fluencyScore:
          (json['fluency_score'] as num?)?.toDouble() ?? 0.0,
      completenessScore:
          (json['completeness_score'] as num?)?.toDouble() ?? 0.0,
      pronunciationScore:
          (json['pronunciation_score'] as num?)?.toDouble() ?? 0.0,
      phonemeResults: (json['phoneme_results'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      l1Errors: (json['l1_errors'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kid_id': kidId,
      'reference_text': referenceText,
      'accuracy_score': accuracyScore,
      'fluency_score': fluencyScore,
      'completeness_score': completenessScore,
      'pronunciation_score': pronunciationScore,
      'phoneme_results': phonemeResults,
      'l1_errors': l1Errors,
    };
  }

  /// Converts to a domain entity.
  PronunciationScore toEntity() {
    return PronunciationScore(
      accuracyScore: accuracyScore,
      fluencyScore: fluencyScore,
      completenessScore: completenessScore,
      pronunciationScore: pronunciationScore,
      phonemes: phonemeResults.map((p) => PhonemeResult.fromJson(p)).toList(),
      l1Errors: l1Errors,
    );
  }
}
