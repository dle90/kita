import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/features/pronunciation/domain/entities/pronunciation_score.dart';

/// Abstract repository for pronunciation scoring.
abstract class PronunciationRepository {
  /// Scores the pronunciation of a recorded audio file against reference text.
  ///
  /// [audioPath] - path to the recorded WAV file (16kHz, 16-bit, mono).
  /// [referenceText] - the expected English text the learner should have said.
  Future<ApiResult<PronunciationScore>> scorePronunciation({
    required String audioPath,
    required String referenceText,
  });
}
