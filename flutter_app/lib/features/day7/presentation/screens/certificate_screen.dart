import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/shared/widgets/confetti_overlay.dart';
import 'package:kita_english/shared/widgets/kita_button.dart';
import 'package:share_plus/share_plus.dart';

/// Beautiful completion certificate with kid's name, date, and share options.
class CertificateScreen extends ConsumerStatefulWidget {
  const CertificateScreen({super.key});

  @override
  ConsumerState<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends ConsumerState<CertificateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _showConfetti = true;

  // These would come from the kid profile in production
  final String _kidName = 'Bao';
  final DateTime _completionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _shareCertificate() {
    Share.share(
      'Con tui vua hoan thanh thu thach 7 ngay hoc tieng Anh voi Kita English! '
      'Rat tu hao! #KitaEnglish #HocTiengAnh',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_completionDate.day}/${_completionDate.month}/${_completionDate.year}';

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFF8E1),
                  Color(0xFFFFF3E0),
                  Color(0xFFFFECB3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => context.go(RoutePaths.home),
                      icon: const Icon(Icons.close, size: 28),
                    ),
                  ),

                  // Certificate card
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha:0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Trophy icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFFFD700).withValues(alpha:0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '🏆',
                                style: TextStyle(fontSize: 44),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          const Text(
                            'CHỨNG CHỈ',
                            style: TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hoàn Thành Xuất Sắc',
                            style: AppTypography.headlineMedium.copyWith(
                              color: const Color(0xFFB8860B),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Decorative line
                          Container(
                            width: 80,
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Kid's name
                          Text(
                            'Trao tặng cho bạn',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _kidName,
                            style: AppTypography.displayMedium.copyWith(
                              color: AppColors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Achievement text
                          Text(
                            'Đã hoàn thành thử thách\n7 Ngày Học Tiếng Anh\ncùng Kita English',
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Date
                          Text(
                            'Ngày $dateStr',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stars decoration
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (i) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.star,
                                  color: const Color(0xFFFFD700),
                                  size: i == 2 ? 32 : 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Share buttons
                  Text(
                    'Chia sẻ thành tích với bạn bè!',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Share to Zalo
                      _ShareButton(
                        label: 'Zalo',
                        color: const Color(0xFF0068FF),
                        icon: Icons.chat_bubble,
                        onTap: _shareCertificate,
                      ),
                      const SizedBox(width: 16),
                      // Share to Facebook
                      _ShareButton(
                        label: 'Facebook',
                        color: const Color(0xFF1877F2),
                        icon: Icons.facebook,
                        onTap: _shareCertificate,
                      ),
                      const SizedBox(width: 16),
                      // General share
                      _ShareButton(
                        label: 'Khác',
                        color: AppColors.secondary,
                        icon: Icons.share,
                        onTap: _shareCertificate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Back home
                  KitaButton(
                    label: 'Về trang chính',
                    onPressed: () => context.go(RoutePaths.home),
                    icon: Icons.home_rounded,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Confetti
          if (_showConfetti)
            ConfettiOverlay(
              onComplete: () {
                if (mounted) setState(() => _showConfetti = false);
              },
            ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ShareButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha:0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
