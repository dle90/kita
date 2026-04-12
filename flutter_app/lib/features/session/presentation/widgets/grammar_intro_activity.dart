import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/session/domain/entities/activity.dart';

/// Introduces a new grammar structure from the curriculum DAG.
///
/// Shows:
///   - The grammar template (e.g. "I am + feeling")
///   - Vietnamese description of the pattern
///   - 1-3 example sentences (EN + VI)
///   - A common L1 error tip (what Vietnamese kids typically get wrong)
///
/// The kid taps "Hiểu rồi! 👍" to complete — it is always marked correct
/// since it is an introduction, not a test.
class GrammarIntroActivity extends ConsumerStatefulWidget {
  final Activity activity;
  final void Function({required bool isCorrect, Map<String, dynamic> metadata})
      onComplete;

  const GrammarIntroActivity({
    super.key,
    required this.activity,
    required this.onComplete,
  });

  @override
  ConsumerState<GrammarIntroActivity> createState() =>
      _GrammarIntroActivityState();
}

class _GrammarIntroActivityState extends ConsumerState<GrammarIntroActivity>
    with SingleTickerProviderStateMixin {
  bool _showTip = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _config => widget.activity.config;

  @override
  Widget build(BuildContext context) {
    final grammarName = _config['grammar_name'] as String? ?? '';
    final descriptionVI = _config['description_vi'] as String? ?? '';
    final template = _config['template'] as String? ?? '';
    final cefrLevel = _config['cefr_level'] as String? ?? '';
    final examples = (_config['examples'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final l1Tip = _config['l1_tip'] as Map<String, dynamic>?;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header chip
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📚', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'Ngữ pháp mới · $cefrLevel',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grammar name
            Text(
              grammarName,
              style: AppTypography.titleLarge.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            if (descriptionVI.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                descriptionVI,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),

            // Template box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9B59F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Mẫu câu',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    template,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Example sentences
            if (examples.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ví dụ:',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...examples.map((ex) => _ExampleCard(
                          en: ex['en'] as String? ?? '',
                          vi: ex['vi'] as String? ?? '',
                        )),
                  ],
                ),
              ),
            ],

            // L1 error tip (collapsible)
            if (l1Tip != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _showTip = !_showTip),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _showTip
                        ? AppColors.warningLight.withValues(alpha: 0.2)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _showTip
                          ? AppColors.warning.withValues(alpha: 0.4)
                          : AppColors.surfaceVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('⚠️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lỗi thường gặp',
                              style: AppTypography.labelMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                          Icon(
                            _showTip
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                      if (_showTip) ...[
                        const SizedBox(height: 10),
                        _L1ErrorDetail(tip: l1Tip),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // "Got it" button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton(
                onPressed: () => widget.onComplete(
                  isCorrect: true,
                  metadata: {
                    'grammar_structure_id':
                        _config['grammar_structure_id'] ?? '',
                    'type': 'pattern_intro',
                  },
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Hiểu rồi! 👍',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final String en;
  final String vi;

  const _ExampleCard({required this.en, required this.vi});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$en"',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          if (vi.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              vi,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _L1ErrorDetail extends StatelessWidget {
  final Map<String, dynamic> tip;

  const _L1ErrorDetail({required this.tip});

  @override
  Widget build(BuildContext context) {
    final wrong = tip['example_wrong'] as String? ?? '';
    final correct = tip['example_correct'] as String? ?? '';
    final reasonVI = tip['reason_vi'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wrong.isNotEmpty)
          _ErrorRow(
            icon: '❌',
            label: 'Sai:',
            text: wrong,
            color: AppColors.error,
          ),
        if (correct.isNotEmpty) ...[
          const SizedBox(height: 4),
          _ErrorRow(
            icon: '✅',
            label: 'Đúng:',
            text: correct,
            color: AppColors.success,
          ),
        ],
        if (reasonVI.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            reasonVI,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String icon;
  final String label;
  final String text;
  final Color color;

  const _ErrorRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
