import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_token.dart';

class TokenStorage {
  final FlutterSecureStorage _storage;

  static const String _keyAccessToken = 'remotectrl_access_token';
  static const String _keyRefreshToken = 'remotectrl_refresh_token';
  static const String _keyTokenType = 'remotectrl_token_type';
  static const String _keyBaseUrl = 'remotectrl_base_url';

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  Future<void> saveTokens(AuthToken token) async {
    await _storage.write(key: _keyAccessToken, value: token.accessToken);
    if (token.refreshToken != null && token.refreshToken!.isNotEmpty) {
      await _storage.write(key: _keyRefreshToken, value: token.refreshToken);
    }
    await _storage.write(key: _keyTokenType, value: token.tokenType);
  }

  Future<void> updateAccessToken(String newAccessToken, [String? tokenType]) async {
    await _storage.write(key: _keyAccessToken, value: newAccessToken);
    if (tokenType != null) {
      await _storage.write(key: _keyTokenType, value: tokenType);
    }
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<AuthToken?> getTokens() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    final type = await _storage.read(key: _keyTokenType) ?? 'bearer';

    if (access == null && refresh == null) {
      return null;
    }

    return AuthToken(
      accessToken: access ?? '',
      refreshToken: refresh,
      tokenType: type,
    );
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyTokenType);
  }

  Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: _keyBaseUrl, value: url);
  }

  Future<String?> getBaseUrl() async {
    return await _storage.read(key: _keyBaseUrl);
  }
}
