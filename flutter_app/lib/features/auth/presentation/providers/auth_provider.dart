import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kita_english/features/auth/domain/entities/parent_account.dart';
import 'package:kita_english/features/auth/domain/repositories/auth_repository.dart';

/// Enum representing the current authentication state.
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// State for the auth notifier.
class AuthState {
  final AuthStatus status;
  final ParentAccount? account;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.account,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    ParentAccount? account,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      account: account ?? this.account,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier managing the authentication state.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isAuth = await _repository.isAuthenticated();
    if (isAuth) {
      state = state.copyWith(status: AuthStatus.authenticated);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? phone,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _repository.signUp(
      email: email,
      password: password,
      phone: phone,
    );

    result.when(
      success: (account) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          account: account,
        );
      },
      failure: (message, _) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: message,
        );
      },
    );
  }

  Future<void> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _repository.signIn(
      emailOrPhone: emailOrPhone,
      password: password,
    );

    result.when(
      success: (account) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          account: account,
        );
      },
      failure: (message, _) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: message,
        );
      },
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    await _repository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for the [AuthNotifier].
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

/// Convenience provider: is the user authenticated?
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.status == AuthStatus.authenticated;
});

/// Convenience provider: is auth currently loading?
final isAuthLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.status == AuthStatus.loading;
});
