import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';
import 'package:kita_english/core/network/api_client.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/onboarding/domain/entities/kid_profile.dart';
import 'package:kita_english/features/onboarding/domain/entities/onboarding_state.dart';

/// StateNotifier managing the onboarding flow.
class OnboardingNotifier extends StateNotifier<OnboardingFlowState> {
  final Dio _dio;
  final SecureStorageService _secureStorage;

  OnboardingNotifier({
    required Dio dio,
    required SecureStorageService secureStorage,
  })  : _dio = dio,
        _secureStorage = secureStorage,
        super(const OnboardingFlowState());

  // --- Parent Gate ---

  void setDisplayName(String name) {
    state = state.copyWith(displayName: name);
  }

  void setAge(int age) {
    state = state.copyWith(age: age);
  }

  void setDialect(Dialect dialect) {
    state = state.copyWith(dialect: dialect);
  }

  void setEnglishLevel(EnglishLevel level) {
    state = state.copyWith(englishLevel: level);
  }

  void setNotificationTime(TimeOfDay time) {
    state = state.copyWith(notificationTime: time);
  }

  void completeParentGate() {
    state = state.copyWith(currentStep: OnboardingStep.characterSelect);
  }

  // --- Character Selection ---

  void selectCharacter(String characterId) {
    state = state.copyWith(selectedCharacterId: characterId);
  }

  void completeCharacterSelect() {
    state = state.copyWith(currentStep: OnboardingStep.placementTest);
  }

  // --- Placement Test ---

  void setPlacementScore(int score) {
    state = state.copyWith(placementScore: score);
  }

  /// Submits the onboarding data to the backend and creates the kid profile.
  Future<bool> submitOnboarding() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final response = await _dio.post(
        ApiEndpoints.kidProfiles,
        data: {
          'display_name': state.displayName,
          'age': state.age,
          'dialect': state.dialect.name == 'nam' ? 'south' : state.dialect.name == 'bac' ? 'north' : 'central',
          'english_level': state.englishLevel.name,
          'character_id': state.selectedCharacterId ?? 'mochi',
          if (state.notificationTime != null)
            'notification_time': '${state.notificationTime!.hour.toString().padLeft(2, '0')}:${state.notificationTime!.minute.toString().padLeft(2, '0')}',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final kidId = data['id'] as String? ?? '';

      // Save kid profile ID locally
      await _secureStorage.writeKidProfileId(kidId);
      if (state.selectedCharacterId != null) {
        await _secureStorage
            .writeSelectedCharacterId(state.selectedCharacterId!);
      }

      state = state.copyWith(
        currentStep: OnboardingStep.complete,
        isSubmitting: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          e.message ?? 'Không thể tạo hồ sơ. Vui lòng thử lại.';
      state = state.copyWith(isSubmitting: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Đã xảy ra lỗi: $e',
      );
      return false;
    }
  }

  /// Submits placement test results to the backend.
  Future<void> submitPlacementResults({
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final kidId = await _secureStorage.readKidProfileId() ?? '';
      final response = await _dio.post(
        ApiEndpoints.kidPlacement(kidId),
        data: {
          'answers': answers,
          'age': state.age,
          'english_level': state.englishLevel.name,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final score = data['score'] as int? ?? 0;
      state = state.copyWith(placementScore: score);
    } catch (_) {
      // If placement scoring fails, default to a score based on self-report
      final fallbackScore = state.englishLevel.value * 25;
      state = state.copyWith(placementScore: fallbackScore);
    }
  }

  void reset() {
    state = const OnboardingFlowState();
  }
}

/// Riverpod provider for [OnboardingNotifier].
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingFlowState>((ref) {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return OnboardingNotifier(dio: dio, secureStorage: secureStorage);
});
