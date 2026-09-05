import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/auth_token.dart';
import '../models/user_model.dart';
import 'http_client.dart';

class AuthApi {
  final ApiClient apiClient;

  AuthApi({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// Register a new user account
  /// POST /auth/register { username, email, password }
  Future<String> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {
          'username': username.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      if (response.data is Map && response.data['message'] != null) {
        return response.data['message'].toString();
      }
      return 'Account registered successfully';
    } on DioException catch (e) {
      throw apiClient.formatDioError(e);
    }
  }

  /// Log in using OAuth2PasswordRequestForm (username=email, password)
  /// POST /token
  Future<AuthToken> login({
    required String email,
    required String password,
  }) async {
    try {
      // FastAPI OAuth2PasswordRequestForm expects form-urlencoded body
      final response = await _dio.post(
        ApiConstants.token,
        data: {
          'username': email.trim().toLowerCase(),
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final authToken = AuthToken.fromJson(data);

      // Save tokens in secure storage
      await apiClient.tokenStorage.saveTokens(authToken);

      return authToken;
    } on DioException catch (e) {
      throw apiClient.formatDioError(e);
    }
  }

  /// Refresh token
  /// POST /auth/refresh { refresh_token }
  Future<AuthToken> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final authToken = AuthToken.fromJson(data);

      // Persist updated access token
      await apiClient.tokenStorage.updateAccessToken(
        authToken.accessToken,
        authToken.tokenType,
      );

      return authToken;
    } on DioException catch (e) {
      throw apiClient.formatDioError(e);
    }
  }

  /// Get current user profile
  /// GET /users/me/
  Future<UserModel> getMe() async {
    try {
      final response = await _dio.get(ApiConstants.me);
      final data = response.data as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw apiClient.formatDioError(e);
    }
  }

  /// Log out user
  /// POST /auth/logout { refresh_token }
  Future<void> logout() async {
    try {
      final refreshToken = await apiClient.tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post(
          ApiConstants.logout,
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // Best effort - even if network call fails, clear local tokens
    } finally {
      await apiClient.tokenStorage.clearTokens();
    }
  }
}
