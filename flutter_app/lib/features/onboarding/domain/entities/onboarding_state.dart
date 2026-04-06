import 'package:flutter/material.dart';
import 'package:kita_english/features/onboarding/domain/entities/kid_profile.dart';

/// Steps in the onboarding flow.
enum OnboardingStep {
  parentGate,
  characterSelect,
  placementTest,
  complete,
}

/// Tracks the current state of the onboarding flow.
class OnboardingFlowState {
  final OnboardingStep currentStep;
  final String? displayName;
  final int age;
  final Dialect dialect;
  final EnglishLevel englishLevel;
  final TimeOfDay? notificationTime;
  final String? selectedCharacterId;
  final int? placementScore;
  final bool isSubmitting;
  final String? errorMessage;

  const OnboardingFlowState({
    this.currentStep = OnboardingStep.parentGate,
    this.displayName,
    this.age = 7,
    this.dialect = Dialect.bac,
    this.englishLevel = EnglishLevel.none,
    this.notificationTime,
    this.selectedCharacterId,
    this.placementScore,
    this.isSubmitting = false,
    this.errorMessage,
  });

  OnboardingFlowState copyWith({
    OnboardingStep? currentStep,
    String? displayName,
    int? age,
    Dialect? dialect,
    EnglishLevel? englishLevel,
    TimeOfDay? notificationTime,
    String? selectedCharacterId,
    int? placementScore,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return OnboardingFlowState(
      currentStep: currentStep ?? this.currentStep,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      dialect: dialect ?? this.dialect,
      englishLevel: englishLevel ?? this.englishLevel,
      notificationTime: notificationTime ?? this.notificationTime,
      selectedCharacterId: selectedCharacterId ?? this.selectedCharacterId,
      placementScore: placementScore ?? this.placementScore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }

  /// Whether the parent gate form is complete.
  bool get isParentGateComplete =>
      displayName != null && displayName!.trim().isNotEmpty;

  /// Whether character selection is complete.
  bool get isCharacterSelected => selectedCharacterId != null;

  /// Whether placement test is complete.
  bool get isPlacementComplete => placementScore != null;
}

/// Extension to format TimeOfDay as HH:mm string for the API.
extension TimeOfDayFormat on TimeOfDay {
  String toHHmm() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
