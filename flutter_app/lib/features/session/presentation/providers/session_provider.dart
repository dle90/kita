import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/features/session/data/repositories/session_repository_impl.dart';
import 'package:kita_english/features/session/domain/entities/activity_result.dart';
import 'package:kita_english/features/session/domain/entities/session.dart';
import 'package:kita_english/features/session/domain/repositories/session_repository.dart';

/// State for the current session.
class SessionState {
  final Session? session;
  final int currentActivityIndex;
  final List<ActivityResult> results;
  final bool isLoading;
  final bool isSessionComplete;
  final String? errorMessage;
  final int totalStarsEarned;

  const SessionState({
    this.session,
    this.currentActivityIndex = 0,
    this.results = const [],
    this.isLoading = false,
    this.isSessionComplete = false,
    this.errorMessage,
    this.totalStarsEarned = 0,
  });

  SessionState copyWith({
    Session? session,
    int? currentActivityIndex,
    List<ActivityResult>? results,
    bool? isLoading,
    bool? isSessionComplete,
    String? errorMessage,
    int? totalStarsEarned,
  }) {
    return SessionState(
      session: session ?? this.session,
      currentActivityIndex: currentActivityIndex ?? this.currentActivityIndex,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isSessionComplete: isSessionComplete ?? this.isSessionComplete,
      errorMessage: errorMessage,
      totalStarsEarned: totalStarsEarned ?? this.totalStarsEarned,
    );
  }

  /// Progress ratio (0.0 - 1.0).
  double get progress {
    final total = session?.activityCount ?? 0;
    if (total == 0) return 0.0;
    return currentActivityIndex / total;
  }

  /// Accuracy percentage based on results so far.
  double get accuracyPct {
    if (results.isEmpty) return 0.0;
    final correct = results.where((r) => r.isCorrect).length;
    return (correct / results.length) * 100;
  }
}

/// StateNotifier for managing the active session.
class SessionNotifier extends StateNotifier<SessionState> {
  final SessionRepository _repository;

  SessionNotifier(this._repository) : super(const SessionState());

  /// Loads sessions for the challenge home view.
  Future<List<Session>> loadSessions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repository.getSessions();
    return result.when(
      success: (sessions) {
        state = state.copyWith(isLoading: false);
        return sessions;
      },
      failure: (message, _) {
        state = state.copyWith(isLoading: false, errorMessage: message);
        return [];
      },
    );
  }

  /// Starts a session for the given day.
  Future<void> startSession(int dayNumber) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      currentActivityIndex: 0,
      results: [],
      isSessionComplete: false,
      totalStarsEarned: 0,
    );

    // Fetch session with activities first
    final sessionResult = await _repository.getSession(dayNumber);
    sessionResult.when(
      success: (session) {
        // Use the session with activities
        state = state.copyWith(
          session: session,
          isLoading: false,
        );
        // Mark as started on backend (fire-and-forget, don't replace session)
        _repository.startSession(dayNumber);
      },
      failure: (message, _) {
        state = state.copyWith(isLoading: false, errorMessage: message);
      },
    );
  }

  /// Records the result of the current activity and advances.
  void submitActivityResult(ActivityResult result) {
    final updatedResults = [...state.results, result];
    final totalStars = state.totalStarsEarned + result.starsEarned;
    final nextIndex = state.currentActivityIndex + 1;
    final activityCount = state.session?.activityCount ?? 0;

    // Submit to backend in background
    _repository.submitActivityResult(result);

    if (nextIndex >= activityCount) {
      // Session complete
      state = state.copyWith(
        results: updatedResults,
        currentActivityIndex: nextIndex,
        totalStarsEarned: totalStars,
        isSessionComplete: true,
      );
      _completeSession(updatedResults, totalStars);
    } else {
      state = state.copyWith(
        results: updatedResults,
        currentActivityIndex: nextIndex,
        totalStarsEarned: totalStars,
      );
    }
  }

  Future<void> _completeSession(
    List<ActivityResult> results,
    int totalStars,
  ) async {
    final session = state.session;
    if (session == null) return;

    final accuracyPct = state.accuracyPct;
    await _repository.completeSession(
      session.dayNumber,
      totalStars: totalStars,
      accuracyPct: accuracyPct,
      results: results,
    );
  }

  void reset() {
    state = const SessionState();
  }
}

/// Provider for the session notifier.
final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final repository = ref.read(sessionRepositoryProvider);
  return SessionNotifier(repository);
});

/// Provider for the current activity index.
final currentActivityIndexProvider = Provider<int>((ref) {
  return ref.watch(sessionProvider).currentActivityIndex;
});

/// Provider for session progress (0.0 - 1.0).
final sessionProgressProvider = Provider<double>((ref) {
  return ref.watch(sessionProvider).progress;
});

/// Provider for the list of all sessions (for the home screen).
final allSessionsProvider = FutureProvider<List<Session>>((ref) async {
  final repository = ref.read(sessionRepositoryProvider);
  final result = await repository.getSessions();
  return result.dataOrNull ?? [];
});
