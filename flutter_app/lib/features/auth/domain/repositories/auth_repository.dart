import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/features/auth/domain/entities/parent_account.dart';

/// Abstract auth repository defining the authentication contract.
abstract class AuthRepository {
  /// Registers a new parent account.
  Future<ApiResult<ParentAccount>> signUp({
    required String email,
    required String password,
    String? phone,
  });

  /// Signs in with email/phone + password.
  Future<ApiResult<ParentAccount>> signIn({
    required String emailOrPhone,
    required String password,
  });

  /// Signs out the current user and clears tokens.
  Future<ApiResult<void>> signOut();

  /// Returns the stored access token, or null if not authenticated.
  Future<String?> getToken();

  /// Returns whether the user is currently authenticated with a valid token.
  Future<bool> isAuthenticated();

  /// Refreshes the access token using the refresh token.
  Future<ApiResult<void>> refreshToken();

  /// Creates a guest account (no email/password needed).
  Future<ApiResult<ParentAccount>> createGuest();

  /// Links a guest account to a permanent email/password.
  Future<ApiResult<ParentAccount>> linkAccount({
    required String email,
    required String password,
    String? phone,
  });
}
