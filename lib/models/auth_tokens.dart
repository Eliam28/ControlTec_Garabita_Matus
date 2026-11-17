class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  /// Local storage format, not the FastAPI response schema.
  Map<String, dynamic> toJson() => {
    'access': accessToken,
    'refresh': refreshToken,
  };

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final access = json['access'] as String;
    final refresh = json['refresh'] as String;
    if (access.isEmpty || refresh.isEmpty) {
      throw const FormatException('Empty tokens');
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}
