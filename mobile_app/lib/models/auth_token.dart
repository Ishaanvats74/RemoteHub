class AuthToken {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;

  const AuthToken({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      'token_type': tokenType,
    };
  }

  AuthToken copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
  }) {
    return AuthToken(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
    );
  }
}
