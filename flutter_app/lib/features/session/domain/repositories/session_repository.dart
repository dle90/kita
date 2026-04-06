import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/features/session/domain/entities/activity_result.dart';
import 'package:kita_english/features/session/domain/entities/session.dart';

/// Abstract repository for session management.
abstract class SessionRepository {
  /// Gets all 7 sessions for the current kid.
  Future<ApiResult<List<Session>>> getSessions();

  /// Gets a specific session by day number (with activities).
  Future<ApiResult<Session>> getSession(int dayNumber);

  /// Starts a session for the given day number.
  Future<ApiResult<Session>> startSession(int dayNumber);

  /// Completes a session for the given day number.
  Future<ApiResult<Session>> completeSession(
    int dayNumber, {
    required int totalStars,
    required double accuracyPct,
    required List<ActivityResult> results,
  });

  /// Submits the result of a single activity.
  Future<ApiResult<void>> submitActivityResult(ActivityResult result);
}
