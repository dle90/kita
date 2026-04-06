import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/features/srs/domain/entities/srs_card.dart';

/// Abstract repository for spaced repetition system.
abstract class SrsRepository {
  /// Gets all cards due for review.
  Future<ApiResult<List<SrsCard>>> getDueCards();

  /// Submits a review for a card with a quality rating (0-5).
  /// Returns the updated card with new scheduling.
  Future<ApiResult<SrsCard>> reviewCard(String cardId, int quality);
}
