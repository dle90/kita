import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/features/pronunciation/data/repositories/pronunciation_repository_impl.dart';
import 'package:kita_english/features/pronunciation/domain/entities/pronunciation_score.dart';
import 'package:kita_english/features/pronunciation/domain/repositories/pronunciation_repository.dart';

/// Recording/scoring states.
enum PronunciationStatus {
  idle,
  recording,
  uploading,
  scored,
  error,
}

/// State for pronunciation recording and scoring.
class PronunciationState {
  final PronunciationStatus status;
  final String? recordingPath;
  final PronunciationScore? score;
  final String? errorMessage;

  const PronunciationState({
    this.status = PronunciationStatus.idle,
    this.recordingPath,
    this.score,
    this.errorMessage,
  });

  PronunciationState copyWith({
    PronunciationStatus? status,
    String? recordingPath,
    PronunciationScore? score,
    String? errorMessage,
  }) {
    return PronunciationState(
      status: status ?? this.status,
      recordingPath: recordingPath ?? this.recordingPath,
      score: score ?? this.score,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier managing pronunciation recording, upload, and scoring.
class PronunciationNotifier extends StateNotifier<PronunciationState> {
  final PronunciationRepository _repository;

  PronunciationNotifier(this._repository)
      : super(const PronunciationState());

  void setRecording() {
    state = state.copyWith(
      status: PronunciationStatus.recording,
      score: null,
      errorMessage: null,
    );
  }

  void setRecordingComplete(String path) {
    state = state.copyWith(
      status: PronunciationStatus.idle,
      recordingPath: path,
    );
  }

  /// Scores the recorded audio against the reference text.
  Future<PronunciationScore?> scorePronunciation({
    required String audioPath,
    required String referenceText,
  }) async {
    state = state.copyWith(
      status: PronunciationStatus.uploading,
      errorMessage: null,
    );

    final result = await _repository.scorePronunciation(
      audioPath: audioPath,
      referenceText: referenceText,
    );

    return result.when(
      success: (score) {
        state = state.copyWith(
          status: PronunciationStatus.scored,
          score: score,
        );
        return score;
      },
      failure: (message, _) {
        state = state.copyWith(
          status: PronunciationStatus.error,
          errorMessage: message,
        );
        return null;
      },
    );
  }

  void reset() {
    state = const PronunciationState();
  }
}

/// Riverpod provider for [PronunciationNotifier].
final pronunciationProvider =
    StateNotifierProvider<PronunciationNotifier, PronunciationState>((ref) {
  final repository = ref.read(pronunciationRepositoryProvider);
  return PronunciationNotifier(repository);
});
