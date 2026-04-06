import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys used for secure storage entries.
class _StorageKeys {
  static const String accessToken = 'kita_access_token';
  static const String refreshToken = 'kita_refresh_token';
  static const String tokenExpiresAt = 'kita_token_expires_at';
  static const String kidProfileId = 'kita_kid_profile_id';
  static const String selectedCharacterId = 'kita_selected_character_id';
}

/// Wrapper around [FlutterSecureStorage] for token read/write/delete.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  // --- Access Token ---

  Future<String?> readAccessToken() async {
    return _storage.read(key: _StorageKeys.accessToken);
  }

  Future<void> writeAccessToken(String token) async {
    await _storage.write(key: _StorageKeys.accessToken, value: token);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _StorageKeys.accessToken);
  }

  // --- Refresh Token ---

  Future<String?> readRefreshToken() async {
    return _storage.read(key: _StorageKeys.refreshToken);
  }

  Future<void> writeRefreshToken(String token) async {
    await _storage.write(key: _StorageKeys.refreshToken, value: token);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _StorageKeys.refreshToken);
  }

  // --- Token Expiry ---

  Future<DateTime?> readTokenExpiresAt() async {
    final value = await _storage.read(key: _StorageKeys.tokenExpiresAt);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> writeTokenExpiresAt(DateTime expiresAt) async {
    await _storage.write(
      key: _StorageKeys.tokenExpiresAt,
      value: expiresAt.toIso8601String(),
    );
  }

  // --- Token Management ---

  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? expiresAt,
  }) async {
    await Future.wait([
      writeAccessToken(accessToken),
      writeRefreshToken(refreshToken),
      if (expiresAt != null) writeTokenExpiresAt(expiresAt),
    ]);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      deleteAccessToken(),
      deleteRefreshToken(),
      _storage.delete(key: _StorageKeys.tokenExpiresAt),
    ]);
  }

  Future<bool> hasValidToken() async {
    final token = await readAccessToken();
    if (token == null || token.isEmpty) return false;

    final expiresAt = await readTokenExpiresAt();
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  // --- Kid Profile ---

  Future<String?> readKidProfileId() async {
    return _storage.read(key: _StorageKeys.kidProfileId);
  }

  Future<void> writeKidProfileId(String id) async {
    await _storage.write(key: _StorageKeys.kidProfileId, value: id);
  }

  Future<void> deleteKidProfileId() async {
    await _storage.delete(key: _StorageKeys.kidProfileId);
  }

  // --- Character ---

  Future<String?> readSelectedCharacterId() async {
    return _storage.read(key: _StorageKeys.selectedCharacterId);
  }

  Future<void> writeSelectedCharacterId(String id) async {
    await _storage.write(key: _StorageKeys.selectedCharacterId, value: id);
  }

  // --- Clear All ---

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

/// Riverpod provider for [SecureStorageService].
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
