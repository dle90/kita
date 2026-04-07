import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/features/auth/data/datasources/auth_local_ds.dart';
import 'package:kita_english/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:kita_english/features/auth/domain/entities/parent_account.dart';
import 'package:kita_english/features/auth/domain/repositories/auth_repository.dart';

/// Concrete implementation of [AuthRepository] coordinating
/// remote API calls and local token storage.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDs;
  final AuthLocalDataSource _localDs;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDs,
    required AuthLocalDataSource localDs,
  })  : _remoteDs = remoteDs,
        _localDs = localDs;

  @override
  Future<ApiResult<ParentAccount>> signUp({
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await _remoteDs.register(
        email: email,
        password: password,
        phone: phone,
      );

      // Save tokens locally
      await _localDs.saveTokens(response.tokens);

      return ApiResult.success(response.account);
    } on DioException catch (e) {
      final message = e.message ?? 'Đăng ký thất bại. Vui lòng thử lại.';
      final statusCode = e.response?.statusCode;
      return ApiResult.failure(message, statusCode: statusCode);
    } catch (e) {
      return ApiResult.failure('Đã xảy ra lỗi không mong muốn: $e');
    }
  }

  @override
  Future<ApiResult<ParentAccount>> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      final response = await _remoteDs.login(
        email: emailOrPhone,
        password: password,
      );

      // Save tokens locally
      await _localDs.saveTokens(response.tokens);

      return ApiResult.success(response.account);
    } on DioException catch (e) {
      final message = e.message ?? 'Đăng nhập thất bại. Vui lòng thử lại.';
      final statusCode = e.response?.statusCode;
      return ApiResult.failure(message, statusCode: statusCode);
    } catch (e) {
      return ApiResult.failure('Đã xảy ra lỗi không mong muốn: $e');
    }
  }

  @override
  Future<ApiResult<void>> signOut() async {
    // Go backend has no logout endpoint — just clear tokens locally
    await _localDs.clearTokens();
    return const ApiResult.success(null);
  }

  @override
  Future<String?> getToken() async {
    return _localDs.readAccessToken();
  }

  @override
  Future<bool> isAuthenticated() async {
    return _localDs.hasValidToken();
  }

  @override
  Future<ApiResult<ParentAccount>> createGuest() async {
    try {
      final response = await _remoteDs.createGuest();
      await _localDs.saveTokens(response.tokens);
      return ApiResult.success(response.account);
    } on DioException catch (e) {
      final message = e.message ?? 'Tạo tài khoản khách thất bại.';
      final statusCode = e.response?.statusCode;
      return ApiResult.failure(message, statusCode: statusCode);
    } catch (e) {
      return ApiResult.failure('Đã xảy ra lỗi không mong muốn: $e');
    }
  }

  @override
  Future<ApiResult<ParentAccount>> linkAccount({
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await _remoteDs.linkAccount(
        email: email,
        password: password,
        phone: phone,
      );
      await _localDs.saveTokens(response.tokens);
      return ApiResult.success(response.account);
    } on DioException catch (e) {
      final message = e.message ?? 'Liên kết tài khoản thất bại.';
      final statusCode = e.response?.statusCode;
      return ApiResult.failure(message, statusCode: statusCode);
    } catch (e) {
      return ApiResult.failure('Đã xảy ra lỗi không mong muốn: $e');
    }
  }

  @override
  Future<ApiResult<void>> refreshToken() async {
    try {
      final currentRefreshToken = await _localDs.readRefreshToken();
      if (currentRefreshToken == null) {
        return const ApiResult.failure('Không có refresh token.');
      }

      final newTokens = await _remoteDs.refreshToken(currentRefreshToken);
      await _localDs.saveTokens(newTokens);

      return const ApiResult.success(null);
    } on DioException catch (e) {
      await _localDs.clearTokens();
      final message = e.message ?? 'Phiên đăng nhập đã hết hạn.';
      return ApiResult.failure(message, statusCode: e.response?.statusCode);
    } catch (e) {
      return ApiResult.failure('Lỗi làm mới token: $e');
    }
  }
}

/// Riverpod provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDs: ref.read(authRemoteDataSourceProvider),
    localDs: ref.read(authLocalDataSourceProvider),
  );
});
