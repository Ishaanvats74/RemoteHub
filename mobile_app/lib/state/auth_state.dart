import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/auth_api.dart';
import '../api/http_client.dart';
import '../models/user_model.dart';
import 'server_settings_state.dart';
import 'websocket_state.dart';

enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final bool isSessionExpired;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.isSessionExpired = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool? isSessionExpired,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isSessionExpired: isSessionExpired ?? this.isSessionExpired,
    );
  }
}

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final baseUrl = ref.watch(serverSettingsProvider);

  final client = ApiClient(
    tokenStorage: storage,
    baseUrl: baseUrl,
    onSessionExpired: () {
      ref.read(authNotifierProvider.notifier).handleSessionExpired();
    },
  );

  return client;
});

final Provider<AuthApi> authApiProvider = Provider<AuthApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthApi(apiClient: client);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final AuthApi _authApi;

  AuthNotifier(this._ref, this._authApi) : super(const AuthState());

  /// Checks secure storage for stored refresh token on app start
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      final storage = _ref.read(tokenStorageProvider);
      final refreshToken = await storage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      // Silently refresh access token
      await _authApi.refreshToken(refreshToken);

      // Fetch user profile
      final me = await _authApi.getMe();

      // Open persistent WebSocket connection
      _ref.read(webSocketManagerProvider).connect();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: me,
        isSessionExpired: false,
      );
    } catch (e) {
      // If refresh fails, route to login screen
      await _ref.read(tokenStorageProvider).clearTokens();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
      );
    }
  }

  /// Logs in user with email and password
  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      await _authApi.login(email: email, password: password);
      final me = await _authApi.getMe();

      // Open WebSocket connection upon successful authentication
      _ref.read(webSocketManagerProvider).connect();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: me,
        errorMessage: null,
        isSessionExpired: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Registers user and automatically logs them in
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      await _authApi.register(
        username: username,
        email: email,
        password: password,
      );

      // Log in right after registration
      return await login(email, password);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Logs out user, invalidates token with backend, clears storage, and closes WS
  Future<void> logout() async {
    try {
      _ref.read(webSocketManagerProvider).disconnect();
      await _authApi.logout();
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Callback triggered when Dio interceptor detects expired session
  void handleSessionExpired() {
    _ref.read(webSocketManagerProvider).disconnect();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isSessionExpired: true,
      errorMessage: 'Your session has expired. Please sign in again.',
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final StateNotifierProvider<AuthNotifier, AuthState> authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authApi = ref.watch(authApiProvider);
  return AuthNotifier(ref, authApi);
});
