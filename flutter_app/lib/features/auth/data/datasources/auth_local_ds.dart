import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/auth/data/models/auth_token_model.dart';

/// Local data source for storing and reading auth tokens.
class AuthLocalDataSource {
  final SecureStorageService _secureStorage;

  AuthLocalDataSource(this._secureStorage);

  /// Persists the auth tokens to secure storage.
  Future<void> saveTokens(AuthTokens tokens) async {
    await _secureStorage.writeTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt,
    );
  }

  /// Reads the stored auth tokens.
  /// Returns null if no tokens are stored.
  Future<AuthTokens?> readTokens() async {
    final accessToken = await _secureStorage.readAccessToken();
    final refreshToken = await _secureStorage.readRefreshToken();

    if (accessToken == null || refreshToken == null) return null;

    final expiresAt = await _secureStorage.readTokenExpiresAt();

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  /// Returns the stored access token.
  Future<String?> readAccessToken() async {
    return _secureStorage.readAccessToken();
  }

  /// Returns the stored refresh token.
  Future<String?> readRefreshToken() async {
    return _secureStorage.readRefreshToken();
  }

  /// Checks if a valid token exists.
  Future<bool> hasValidToken() async {
    return _secureStorage.hasValidToken();
  }

  /// Clears all stored auth tokens.
  Future<void> clearTokens() async {
    await _secureStorage.clearTokens();
  }
}

/// Riverpod provider for [AuthLocalDataSource].
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  return AuthLocalDataSource(secureStorage);
});
