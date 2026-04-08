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

class _ParentGateScreenState extends ConsumerState<ParentGateScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _ensureGuestSession();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  Future<void> _ensureGuestSession() async {
    final authState = ref.read(authStateProvider);
    if (authState.status == AuthStatus.authenticated) return;
    await ref.read(authStateProvider.notifier).createGuest();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui long nhap ten cua be'),
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
      helpText: 'Chon gio nhac nho hoc bai',
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F6FF), Color(0xFFEDE7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Step indicator
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.primary),
                    ),
                    const Spacer(),
                    _buildStepIndicator(1, 3),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),

                // Fun header illustration
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _bounceAnimation.value),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD166), Color(0xFFFF9FB0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF9FB0).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '\u{1F476}\u{1F4DA}',
                            style: TextStyle(fontSize: 42),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Welcome message
                Text(
                  'Xin chao phu huynh! \u{1F44B}',
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cho chung toi biet them ve be\nde ca nhan hoa trai nghiem hoc',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Kid's display name
                _buildSectionCard(
                  icon: '\u{1F466}',
                  title: 'Ten cua be',
                  child: TextFormField(
                    controller: _nameController,
                    style: AppTypography.bodyLarge,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Nhap ten be (vd: Minh)',
                      prefixIcon:
                          const Icon(Icons.child_care, size: 24, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.surfaceVariant,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Age slider - big and visual
                _buildSectionCard(
                  icon: '\u{1F382}',
                  title: 'Tuoi cua be',
                  child: Column(
                    children: [
                      // Big bouncy age number
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.9, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        key: ValueKey(onboardingState.age),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${onboardingState.age}',
                              style: AppTypography.displayMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'tuoi',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('5', style: AppTypography.labelMedium),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 8,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 14,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 24,
                                ),
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: AppColors.surfaceVariant,
                                thumbColor: AppColors.primary,
                                overlayColor: AppColors.primary.withValues(alpha: 0.15),
                              ),
                              child: Slider(
                                value: onboardingState.age.toDouble(),
                                min: 5,
                                max: 12,
                                divisions: 7,
                                label: '${onboardingState.age} tuoi',
                                onChanged: (value) {
                                  ref
                                      .read(onboardingProvider.notifier)
                                      .setAge(value.round());
                                },
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('12', style: AppTypography.labelMedium),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // English level - colorful pill buttons
                _buildSectionCard(
                  icon: '\u{1F4DA}',
                  title: 'Trinh do tieng Anh hien tai',
                  child: Column(
                    children: EnglishLevel.values.map((level) {
                      final isSelected = onboardingState.englishLevel == level;
                      final levelEmojis = {
                        EnglishLevel.none: '\u{1F331}',
                        EnglishLevel.beginner: '\u{1F33F}',
                        EnglishLevel.school: '\u{1F333}',
                      };
                      final levelColors = {
                        EnglishLevel.none: AppColors.success,
                        EnglishLevel.beginner: AppColors.secondary,
                        EnglishLevel.school: AppColors.primary,
                      };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () {
                            ref
                                .read(onboardingProvider.notifier)
                                .setEnglishLevel(level);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            transform: isSelected
                                ? Matrix4.diagonal3Values(1.02, 1.02, 1.0)
                                : Matrix4.identity(),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (levelColors[level] ?? AppColors.primary)
                                      .withValues(alpha: 0.12)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? (levelColors[level] ?? AppColors.primary)
                                    : AppColors.surfaceVariant,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: (levelColors[level] ?? AppColors.primary)
                                            .withValues(alpha: 0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                Text(
                                  levelEmojis[level] ?? '',
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    level.vietnameseName,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? (levelColors[level] ?? AppColors.primary)
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (levelColors[level] ?? AppColors.primary)
                                        : AppColors.surfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_rounded
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textHint,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Notification time
                _buildSectionCard(
                  icon: '\u{23F0}',
                  title: 'Gio nhac nho hoc bai',
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.surfaceVariant,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.access_time_rounded,
                                color: AppColors.secondary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Doi',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Continue button
                KitaButton(
                  label: 'Tiep tuc \u{1F680}',
                  onPressed: _onContinue,
                  icon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isActive = index < current;
        final isCurrent = index == current - 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 32 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildSectionCard({
    required String icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
