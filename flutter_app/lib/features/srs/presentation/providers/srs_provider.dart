import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/features/srs/data/repositories/srs_repository_impl.dart';
import 'package:kita_english/features/srs/domain/entities/srs_card.dart';

/// Provider for due SRS cards.
final dueCardsProvider = FutureProvider<List<SrsCard>>((ref) async {
  final repository = ref.read(srsRepositoryProvider);
  final result = await repository.getDueCards();
  return result.dataOrNull ?? [];
});

/// Provider for reviewing a card. Returns the updated card.
final reviewCardProvider =
    FutureProvider.family<SrsCard?, ({String cardId, int quality})>(
  (ref, params) async {
    final repository = ref.read(srsRepositoryProvider);
    final result = await repository.reviewCard(params.cardId, params.quality);
    if (result.isSuccess) {
      // Invalidate due cards so they refresh
      ref.invalidate(dueCardsProvider);
    }
    return result.dataOrNull;
  },
);

/// Provider for the count of due cards (for badges/notifications).
final dueCardCountProvider = Provider<int>((ref) {
  final cardsAsync = ref.watch(dueCardsProvider);
  return cardsAsync.when(
    data: (cards) => cards.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
