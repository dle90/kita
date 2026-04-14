import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/network/api_client.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/core/storage/secure_storage.dart';

/// Skips onboarding by auto-creating a guest account and a default kid profile,
/// then navigates directly to the home screen.
class AutoProvisionScreen extends ConsumerStatefulWidget {
  const AutoProvisionScreen({super.key});

  @override
  ConsumerState<AutoProvisionScreen> createState() =>
      _AutoProvisionScreenState();
}

class _AutoProvisionScreenState extends ConsumerState<AutoProvisionScreen> {
  String _status = 'Đang khởi động...';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _provision();
  }

  Future<void> _provision() async {
    final dio = ref.read(dioProvider);
    final storage = ref.read(secureStorageProvider);

    try {
      // 1. Guest auth
      setState(() => _status = 'Tạo tài khoản...');
      final authResp = await dio.post(ApiEndpoints.authGuest);
      final authData = authResp.data as Map<String, dynamic>;
      await storage.writeTokens(
        accessToken: authData['access_token'] as String? ?? '',
        refreshToken: authData['refresh_token'] as String? ?? '',
        expiresAt: DateTime.tryParse(authData['expires_at'] as String? ?? ''),
      );

      // 2. Create kid profile with default dev values
      setState(() => _status = 'Tạo hồ sơ...');
      final kidResp = await dio.post(
        ApiEndpoints.kidProfiles,
        data: {
          'display_name': 'Dev Kid',
          'age': 7,
          'dialect': 'northern',
          'english_level': 'beginner',
          'character_id': 'mochi',
        },
      );
      final kidData = kidResp.data as Map<String, dynamic>;
      final kidId = kidData['id'] as String? ?? '';
      await storage.writeKidProfileId(kidId);
      await storage.writeSelectedCharacterId('mochi');

      if (mounted) context.go(RoutePaths.home);
    } on DioException catch (e) {
      setState(() {
        _failed = true;
        _status = 'Lỗi: ${e.message ?? e.toString()}';
      });
    } catch (e) {
      setState(() {
        _failed = true;
        _status = 'Lỗi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐱', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text(
              'Kita English',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            if (!_failed) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Text(
              _status,
              style: TextStyle(
                fontSize: 15,
                color: _failed ? AppColors.error : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (_failed) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _failed = false;
                    _status = 'Đang thử lại...';
                  });
                  _provision();
                },
                child: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
