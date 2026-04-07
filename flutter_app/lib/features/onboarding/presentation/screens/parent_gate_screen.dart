import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/features/onboarding/domain/entities/kid_profile.dart';
import 'package:kita_english/features/auth/presentation/providers/auth_provider.dart';
import 'package:kita_english/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:kita_english/shared/widgets/kita_button.dart';

class ParentGateScreen extends ConsumerStatefulWidget {
  const ParentGateScreen({super.key});

  @override
  ConsumerState<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends ConsumerState<ParentGateScreen> {
  final _nameController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  @override
  void initState() {
    super.initState();
    _ensureGuestSession();
  }

  Future<void> _ensureGuestSession() async {
    final authState = ref.read(authStateProvider);
    if (authState.status == AuthStatus.authenticated) return;
    await ref.read(authStateProvider.notifier).createGuest();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên của bé'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final notifier = ref.read(onboardingProvider.notifier);
    notifier.setDisplayName(_nameController.text.trim());
    notifier.completeParentGate();
    context.push(RoutePaths.onboardingCharacter);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      ),
      helpText: 'Chọn giờ nhắc nhở học bài',
    );
    if (picked != null) {
      setState(() {
        _selectedTime = TimeOfDay(hour: picked.hour, minute: picked.minute);
      });
      ref.read(onboardingProvider.notifier).setNotificationTime(
            _selectedTime as dynamic,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin của bé'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome message
              Text(
                'Xin chào phụ huynh!',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Cho chúng tôi biết thêm về bé để cá nhân hóa trải nghiệm học',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Kid's display name
              const Text(
                'Tên của bé',
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: AppTypography.bodyLarge,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Nhập tên bé (vd: Minh)',
                  prefixIcon: Icon(Icons.child_care, size: 24),
                ),
              ),
              const SizedBox(height: 28),

              // Age slider
              Text(
                'Tuổi của bé: ${onboardingState.age}',
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('5', style: AppTypography.labelMedium),
                  Expanded(
                    child: Slider(
                      value: onboardingState.age.toDouble(),
                      min: 5,
                      max: 12,
                      divisions: 7,
                      label: '${onboardingState.age} tuổi',
                      onChanged: (value) {
                        ref
                            .read(onboardingProvider.notifier)
                            .setAge(value.round());
                      },
                    ),
                  ),
                  const Text('12', style: AppTypography.labelMedium),
                ],
              ),
              const SizedBox(height: 24),

              // Dialect picker
              const Text(
                'Giọng nói',
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: Dialect.values.map((dialect) {
                  final isSelected = onboardingState.dialect == dialect;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(onboardingProvider.notifier)
                              .setDialect(dialect);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primaryDark, width: 2,)
                                : null,
                          ),
                          child: Text(
                            dialect.vietnameseName,
                            textAlign: TextAlign.center,
                            style: AppTypography.labelMedium.copyWith(
                              color: isSelected
                                  ? AppColors.textOnPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // English level
              const Text(
                'Trình độ tiếng Anh hiện tại',
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: 12),
              ...EnglishLevel.values.map((level) {
                final isSelected = onboardingState.englishLevel == level;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(onboardingProvider.notifier)
                          .setEnglishLevel(level);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha:0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              level.vietnameseName,
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Notification time
              const Text(
                'Giờ nhắc nhở học bài',
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.bodyLarge,
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Continue button
              KitaButton(
                label: 'Tiếp tục',
                onPressed: _onContinue,
                icon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
