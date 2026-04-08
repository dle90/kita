import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:kita_english/shared/widgets/kita_button.dart';

/// Data class for a mascot character option.
class _CharacterOption {
  final String id;
  final String name;
  final String emoji;
  final String personality;
  final String quote;
  final Color color;
  final Color accentColor;

  const _CharacterOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.personality,
    required this.quote,
    required this.color,
    required this.accentColor,
  });
}

const _characters = [
  _CharacterOption(
    id: 'mochi',
    name: 'Mochi \u{1F431}',
    emoji: '\u{1F431}',
    personality: 'Mèo dễ thương, thích khám phá và luôn vui vẻ!',
    quote: 'Mình sẽ học cùng bạn nhé!',
    color: AppColors.mochiCat,
    accentColor: AppColors.mochiCatAccent,
  ),
  _CharacterOption(
    id: 'rong',
    name: 'Rong \u{1F409}',
    emoji: '\u{1F409}',
    personality: 'Rồng nhỏ dũng cảm, thích phiêu lưu và kể chuyện!',
    quote: 'Cùng phiêu lưu nào!',
    color: AppColors.rongDragon,
    accentColor: AppColors.rongDragonAccent,
  ),
  _CharacterOption(
    id: 'lua',
    name: 'Lua \u{1F426}',
    emoji: '\u{1F426}',
    personality: 'Chim nhỏ hay hát, yêu âm nhạc và thích học từ mới!',
    quote: 'Hát cùng mình nhé!',
    color: AppColors.luaBird,
    accentColor: AppColors.luaBirdAccent,
  ),
  _CharacterOption(
    id: 'bo',
    name: 'Bo \u{1F916}',
    emoji: '\u{1F916}',
    personality: 'Robot thông minh, giỏi toán và thích giải đố!',
    quote: 'Giải đố cùng mình!',
    color: AppColors.boRobot,
    accentColor: AppColors.boRobotAccent,
  ),
];

class CharacterSelectScreen extends ConsumerStatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  ConsumerState<CharacterSelectScreen> createState() =>
      _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends ConsumerState<CharacterSelectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);
    final selectedId = onboardingState.selectedCharacterId;

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
          child: Column(
            children: [
              // Top bar with step indicator
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.primary),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    _buildStepIndicator(2, 3),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                'Chọn bạn đồng hành! \u{2728}',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Bạn đồng hành sẽ luôn ở bên cổ vũ bé',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Character grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: _characters.length,
                    itemBuilder: (context, index) {
                      final character = _characters[index];
                      final isSelected = selectedId == character.id;

                      return GestureDetector(
                        onTap: () {
                          ref
                              .read(onboardingProvider.notifier)
                              .selectCharacter(character.id);
                        },
                        child: AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                isSelected ? _floatAnimation.value : 0,
                              ),
                              child: child,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutBack,
                            transform: isSelected
                                ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
                                : Matrix4.identity(),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? character.accentColor
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected
                                    ? character.color
                                    : AppColors.surfaceVariant,
                                width: isSelected ? 3.5 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: character.color
                                            .withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: character.color
                                            .withValues(alpha: 0.15),
                                        blurRadius: 40,
                                        spreadRadius: 8,
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Speech bubble quote
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? character.color
                                              .withValues(alpha: 0.15)
                                          : AppColors.surfaceVariant
                                              .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      character.quote,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: isSelected
                                            ? character.color
                                            : AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Character emoji/avatar - big
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? LinearGradient(
                                              colors: [
                                                character.color
                                                    .withValues(alpha: 0.3),
                                                character.accentColor,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isSelected
                                          ? null
                                          : character.color
                                              .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        character.emoji,
                                        style: const TextStyle(fontSize: 44),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Name - prominent
                                  Text(
                                    character.name,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: isSelected
                                          ? character.color
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Personality
                                  Text(
                                    character.personality,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // Checkmark if selected
                                  if (isSelected) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            character.color,
                                            character.color
                                                .withValues(alpha: 0.7),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: character.color
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Continue button
              Padding(
                padding: const EdgeInsets.all(24),
                child: KitaButton(
                  label: 'Tiếp tục \u{1F389}',
                  onPressed: selectedId != null
                      ? () {
                          ref
                              .read(onboardingProvider.notifier)
                              .completeCharacterSelect();
                          context.push(RoutePaths.onboardingPlacement);
                        }
                      : null,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
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
}
