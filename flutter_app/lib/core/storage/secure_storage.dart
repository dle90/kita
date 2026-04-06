import 'package:flutter/foundation.dart';
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

/// In-memory storage fallback for web platform.
class _WebMemoryStorage {
  final Map<String, String> _data = {};

  Future<String?> read({required String key}) async => _data[key];
  Future<void> write({required String key, required String value}) async =>
      _data[key] = value;
  Future<void> delete({required String key}) async => _data.remove(key);
  Future<void> deleteAll() async => _data.clear();
}

/// Wrapper around [FlutterSecureStorage] for token read/write/delete.
/// Falls back to in-memory storage on web.
class SecureStorageService {
  final FlutterSecureStorage? _storage;
  final _WebMemoryStorage? _webStorage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = kIsWeb
            ? null
            : (storage ??
                const FlutterSecureStorage(
                  aOptions: AndroidOptions(encryptedSharedPreferences: true),
                  iOptions: IOSOptions(
                    accessibility: KeychainAccessibility.first_unlock,
                  ),
                )),
        _webStorage = kIsWeb ? _WebMemoryStorage() : null;

  Future<String?> _read(String key) async {
    if (kIsWeb) return _webStorage!.read(key: key);
    return _storage!.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    if (kIsWeb) return _webStorage!.write(key: key, value: value);
    return _storage!.write(key: key, value: value);
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) return _webStorage!.delete(key: key);
    return _storage!.delete(key: key);
  }

  // --- Access Token ---

  Future<String?> readAccessToken() => _read(_StorageKeys.accessToken);

  Future<void> writeAccessToken(String token) =>
      _write(_StorageKeys.accessToken, token);

  Future<void> deleteAccessToken() => _delete(_StorageKeys.accessToken);

  // --- Refresh Token ---

  Future<String?> readRefreshToken() => _read(_StorageKeys.refreshToken);

  Future<void> writeRefreshToken(String token) =>
      _write(_StorageKeys.refreshToken, token);

  Future<void> deleteRefreshToken() => _delete(_StorageKeys.refreshToken);

  // --- Token Expiry ---

  Future<DateTime?> readTokenExpiresAt() async {
    final value = await _read(_StorageKeys.tokenExpiresAt);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> writeTokenExpiresAt(DateTime expiresAt) =>
      _write(_StorageKeys.tokenExpiresAt, expiresAt.toIso8601String());

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
      _delete(_StorageKeys.tokenExpiresAt),
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

  Future<String?> readKidProfileId() => _read(_StorageKeys.kidProfileId);

  Future<void> writeKidProfileId(String id) =>
      _write(_StorageKeys.kidProfileId, id);

  Future<void> deleteKidProfileId() => _delete(_StorageKeys.kidProfileId);

  // --- Character ---

  Future<String?> readSelectedCharacterId() =>
      _read(_StorageKeys.selectedCharacterId);

  Future<void> writeSelectedCharacterId(String id) =>
      _write(_StorageKeys.selectedCharacterId, id);

  // --- Clear All ---

  Future<void> clearAll() async {
    if (kIsWeb) {
      await _webStorage!.deleteAll();
    } else {
      await _storage!.deleteAll();
    }
  }
}

/// Riverpod provider for [SecureStorageService].
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
