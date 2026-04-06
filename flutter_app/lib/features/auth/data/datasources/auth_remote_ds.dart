import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';
import 'package:kita_english/core/network/api_client.dart';
import 'package:kita_english/features/auth/data/models/auth_token_model.dart';
import 'package:kita_english/features/auth/domain/entities/parent_account.dart';

/// Response from auth endpoints containing account + tokens.
class AuthResponse {
  final ParentAccount account;
  final AuthTokens tokens;

  const AuthResponse({required this.account, required this.tokens});
}

/// Remote data source for authentication API calls.
class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource(this._dio);

  /// POST /auth/register
  Future<AuthResponse> register({
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.authRegister,
      data: {
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return _parseAuthResponse(data);
  }

  /// POST /auth/login
  Future<AuthResponse> login({
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.authLogin,
      data: {
        'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return _parseAuthResponse(data);
  }

  /// POST /auth/refresh
  Future<AuthTokens> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      ApiEndpoints.authRefresh,
      data: {'refresh_token': refreshToken},
    );

    final data = response.data as Map<String, dynamic>;
    return AuthTokens.fromJson(data);
  }

  AuthResponse _parseAuthResponse(Map<String, dynamic> data) {
    final userData = data['user'] as Map<String, dynamic>? ?? data;
    // Auth response returns tokens at top level: access_token, refresh_token, expires_at
    final tokens = AuthTokens.fromJson(data);

    final account = ParentAccount(
      id: userData['id'] as String? ?? '',
      email: userData['email'] as String? ?? '',
      phone: userData['phone'] as String?,
      createdAt: DateTime.tryParse(
            userData['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
    );

    return AuthResponse(account: account, tokens: tokens);
  }
}

/// Riverpod provider for [AuthRemoteDataSource].
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  return AuthRemoteDataSource(dio);
});
