
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';
import 'package:kita_english/core/network/api_client.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/progress/domain/entities/challenge_summary.dart';
import 'package:kita_english/features/progress/domain/entities/daily_progress.dart';

/// Provider for the overall challenge progress overview.
final progressOverviewProvider =
    FutureProvider<ChallengeSummary>((ref) async {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  final kidId = await secureStorage.readKidProfileId() ?? '';
  try {
    final response = await dio.get(ApiEndpoints.progressOverview(kidId));
    final data = response.data as Map<String, dynamic>;
    return ChallengeSummary.fromJson(data);
  } catch (_) {
    return const ChallengeSummary();
  }
});

/// Provider for vocabulary statistics.
final vocabularyStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  final kidId = await secureStorage.readKidProfileId() ?? '';
  try {
    final response = await dio.get(ApiEndpoints.progressVocabulary(kidId));
    return response.data as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
});

/// Provider for daily progress breakdown.
/// Extracts daily data from the main progress endpoint.
final dailyProgressProvider =
    FutureProvider<List<DailyProgress>>((ref) async {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  final kidId = await secureStorage.readKidProfileId() ?? '';
  try {
    final response = await dio.get(ApiEndpoints.progressOverview(kidId));
    final data = response.data as Map<String, dynamic>;
    final daily = data['daily'] as List<dynamic>? ?? [];
    return daily
        .map((json) => DailyProgress.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

/// Provider for pronunciation statistics.
final pronunciationStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  final kidId = await secureStorage.readKidProfileId() ?? '';
  try {
    final response =
        await dio.get(ApiEndpoints.progressPronunciation(kidId));
    return response.data as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
});

/// Provider for per-skill mastery summary (4 skills radar data).
final skillSummaryProvider =
    FutureProvider<SkillSummary>((ref) async {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  final kidId = await secureStorage.readKidProfileId() ?? '';
  try {
    final response = await dio.get(ApiEndpoints.progressSkills(kidId));
    final data = response.data as Map<String, dynamic>;
    return SkillSummary.fromJson(data);
  } catch (_) {
    return const SkillSummary();
  }
});

/// Model for the per-skill mastery summary.
class SkillSummary {
  final double listening;
  final double speaking;
  final double reading;
  final double writing;
  final int wordsMastered;
  final int wordsInProgress;
  final String weakestSkill;

  const SkillSummary({
    this.listening = 0,
    this.speaking = 0,
    this.reading = 0,
    this.writing = 0,
    this.wordsMastered = 0,
    this.wordsInProgress = 0,
    this.weakestSkill = 'listening',
  });

  factory SkillSummary.fromJson(Map<String, dynamic> json) {
    return SkillSummary(
      listening: (json['listening'] as num?)?.toDouble() ?? 0,
      speaking: (json['speaking'] as num?)?.toDouble() ?? 0,
      reading: (json['reading'] as num?)?.toDouble() ?? 0,
      writing: (json['writing'] as num?)?.toDouble() ?? 0,
      wordsMastered: (json['words_mastered'] as num?)?.toInt() ?? 0,
      wordsInProgress: (json['words_in_progress'] as num?)?.toInt() ?? 0,
      weakestSkill: json['weakest_skill'] as String? ?? 'listening',
    );
  }
}
