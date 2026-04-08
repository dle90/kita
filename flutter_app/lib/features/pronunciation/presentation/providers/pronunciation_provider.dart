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

// ---------------------------------------------------------------------------
// Pronunciation History — tracks last 10 scores & per-phoneme accuracy
// ---------------------------------------------------------------------------

/// Holds score history and per-phoneme tracking.
class PronunciationHistoryState {
  final List<PronunciationScore> recentScores;

  /// Map of phoneme string -> list of scores for that phoneme.
  final Map<String, List<double>> phonemeAccuracy;

  const PronunciationHistoryState({
    this.recentScores = const [],
    this.phonemeAccuracy = const {},
  });

  PronunciationHistoryState copyWith({
    List<PronunciationScore>? recentScores,
    Map<String, List<double>>? phonemeAccuracy,
  }) {
    return PronunciationHistoryState(
      recentScores: recentScores ?? this.recentScores,
      phonemeAccuracy: phonemeAccuracy ?? this.phonemeAccuracy,
    );
  }

  /// Returns the 3 phonemes with the lowest average score.
  List<MapEntry<String, double>> get weakPhonemes {
    if (phonemeAccuracy.isEmpty) return [];

    final averages = phonemeAccuracy.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return MapEntry(e.key, avg);
    }).toList();

    averages.sort((a, b) => a.value.compareTo(b.value));

    return averages.take(3).toList();
  }
}

/// Notifier that keeps a rolling history of pronunciation scores.
class PronunciationHistoryNotifier
    extends StateNotifier<PronunciationHistoryState> {
  PronunciationHistoryNotifier()
      : super(const PronunciationHistoryState());

  static const _maxHistory = 10;

  /// Add a new score to the history.
  void addScore(PronunciationScore score) {
    // Update recent scores (keep last 10)
    final updatedScores = [...state.recentScores, score];
    if (updatedScores.length > _maxHistory) {
      updatedScores.removeRange(0, updatedScores.length - _maxHistory);
    }

    // Update per-phoneme accuracy
    final updatedPhonemes = Map<String, List<double>>.from(
      state.phonemeAccuracy.map((k, v) => MapEntry(k, List<double>.from(v))),
    );

    for (final phoneme in score.phonemes) {
      final key = phoneme.phoneme;
      updatedPhonemes.putIfAbsent(key, () => []);
      updatedPhonemes[key]!.add(phoneme.score);
      // Keep only last 20 entries per phoneme
      if (updatedPhonemes[key]!.length > 20) {
        updatedPhonemes[key]!.removeAt(0);
      }
    }

    state = state.copyWith(
      recentScores: updatedScores,
      phonemeAccuracy: updatedPhonemes,
    );
  }

  /// Clear all history.
  void clear() {
    state = const PronunciationHistoryState();
  }
}

/// Riverpod provider for pronunciation history tracking.
final pronunciationHistoryProvider = StateNotifierProvider<
    PronunciationHistoryNotifier, PronunciationHistoryState>(
  (ref) => PronunciationHistoryNotifier(),
);
