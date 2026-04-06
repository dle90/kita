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
  final Color color;
  final Color accentColor;

  const _CharacterOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.personality,
    required this.color,
    required this.accentColor,
  });
}

const _characters = [
  _CharacterOption(
    id: 'mochi',
    name: 'Mochi',
    emoji: '🐱',
    personality: 'Mèo dễ thương, thích khám phá và luôn vui vẻ!',
    color: AppColors.mochiCat,
    accentColor: AppColors.mochiCatAccent,
  ),
  _CharacterOption(
    id: 'rong',
    name: 'Rồng',
    emoji: '🐉',
    personality: 'Rồng nhỏ dũng cảm, thích phiêu lưu và kể chuyện!',
    color: AppColors.rongDragon,
    accentColor: AppColors.rongDragonAccent,
  ),
  _CharacterOption(
    id: 'lua',
    name: 'Lúa',
    emoji: '🐦',
    personality: 'Chim nhỏ hay hát, yêu âm nhạc và thích học từ mới!',
    color: AppColors.luaBird,
    accentColor: AppColors.luaBirdAccent,
  ),
  _CharacterOption(
    id: 'bo',
    name: 'Bô',
    emoji: '🤖',
    personality: 'Robot thông minh, giỏi toán và thích giải đố!',
    color: AppColors.boRobot,
    accentColor: AppColors.boRobotAccent,
  ),
];

class CharacterSelectScreen extends ConsumerWidget {
  const CharacterSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingProvider);
    final selectedId = onboardingState.selectedCharacterId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn bạn đồng hành'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'Chọn một người bạn\nsẽ cùng học với bé!',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đồng hành sẽ luôn ở bên cổ vũ bé',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Character grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.78,
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
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
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: character.color.withValues(alpha:0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha:0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Character emoji/avatar
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: character.color.withValues(alpha:0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    character.emoji,
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Name
                              Text(
                                character.name,
                                style: AppTypography.titleMedium.copyWith(
                                  color: isSelected
                                      ? character.color
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Personality
                              Text(
                                character.personality,
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Checkmark if selected
                              if (isSelected) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: character.color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ],
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
                label: 'Tiếp tục',
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
    );
  }
}
