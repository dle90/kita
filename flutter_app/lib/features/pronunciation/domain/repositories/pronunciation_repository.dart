import 'dart:typed_data';

import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/features/pronunciation/domain/entities/pronunciation_score.dart';

/// Abstract repository for pronunciation scoring.
abstract class PronunciationRepository {
  /// Scores pronunciation from a file path (native platforms).
  Future<ApiResult<PronunciationScore>> scorePronunciation({
    required String audioPath,
    required String referenceText,
  });

  /// Scores pronunciation from raw audio bytes (web platform).
  Future<ApiResult<PronunciationScore>> scorePronunciationBytes({
    required Uint8List audioBytes,
    required String referenceText,
    String contentType = 'audio/webm',
  });
}
