import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import 'token_storage.dart';

typedef SessionExpiredCallback = void Function();

class ApiClient {
  late final Dio dio;
  final TokenStorage tokenStorage;
  final SessionExpiredCallback? onSessionExpired;
  
  String _baseUrl;
  Completer<String?>? _refreshCompleter;

  ApiClient({
    required this.tokenStorage,
    this.onSessionExpired,
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? ApiConstants.defaultBaseUrl {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
    dio.options.baseUrl = newBaseUrl;
  }

  String get baseUrl => _baseUrl;

  void _setupInterceptors() {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          // Do not attach token for public auth endpoints
          final isPublicAuth = options.path.contains(ApiConstants.token) ||
              options.path.contains(ApiConstants.register) ||
              options.path.contains(ApiConstants.refresh);

          if (!isPublicAuth) {
            final accessToken = await tokenStorage.getAccessToken();
            if (accessToken != null && accessToken.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }

          return handler.next(options);
        },
        onError: (DioException err, handler) async {
          // If the error is 401 and not from login/register/refresh
          final isAuthEndpoint = err.requestOptions.path.contains(ApiConstants.token) ||
              err.requestOptions.path.contains(ApiConstants.register) ||
              err.requestOptions.path.contains(ApiConstants.refresh);

          final alreadyRetried = err.requestOptions.extra['retried'] == true;

          if (err.response?.statusCode == 401 && !isAuthEndpoint && !alreadyRetried) {
            try {
              final newAccessToken = await _performTokenRefresh();
              if (newAccessToken != null && newAccessToken.isNotEmpty) {
                // Retry the original request once
                final options = err.requestOptions;
                options.extra['retried'] = true;
                options.headers['Authorization'] = 'Bearer $newAccessToken';

                final response = await dio.fetch(options);
                return handler.resolve(response);
              }
            } catch (refreshErr) {
              debugPrint('Token refresh failed: $refreshErr');
            }

            // Refresh failed or returned null: user session expired
            await tokenStorage.clearTokens();
            onSessionExpired?.call();
            return handler.reject(err);
          }

          return handler.next(err);
        },
      ),
    );
  }

  Future<String?> _performTokenRefresh() async {
    // If a refresh is already underway, await it
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(null);
        return null;
      }

      // Use a separate Dio instance without interceptors to avoid loops
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
        ),
      );

      final response = await refreshDio.post(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data as Map<String, dynamic> : {};
        final newAccessToken = data['access_token'] as String?;
        final tokenType = data['token_type'] as String? ?? 'bearer';

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await tokenStorage.updateAccessToken(newAccessToken, tokenType);
          _refreshCompleter!.complete(newAccessToken);
          return newAccessToken;
        }
      }

      _refreshCompleter!.complete(null);
      return null;
    } catch (e) {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  String formatDioError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return 'Network connection failure. Please verify server is reachable.';
    }

    final statusCode = err.response?.statusCode;
    final data = err.response?.data;

    String? serverDetail;
    if (data is Map) {
      serverDetail = data['detail']?.toString() ?? data['message']?.toString();
    } else if (data is String && data.isNotEmpty) {
      serverDetail = data;
    }

    switch (statusCode) {
      case 400:
        return serverDetail ?? 'Bad request. Please check input.';
      case 401:
        return serverDetail ?? 'Session expired or unauthorized.';
      case 403:
        return serverDetail ?? 'Access forbidden.';
      case 404:
        return serverDetail ?? 'Resource not found.';
      case 409:
        return serverDetail ?? 'Conflict. Email or username already registered.';
      case 422:
        return serverDetail ?? 'Invalid input data provided.';
      case 500:
      case 502:
      case 503:
        return 'Server error ($statusCode). Please try again later.';
      default:
        return serverDetail ?? err.message ?? 'An unexpected error occurred.';
    }
  }
}
