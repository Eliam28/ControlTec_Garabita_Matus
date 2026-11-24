class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;

  bool accessExpired(DateTime now) =>
      accessExpiresAt != null && !now.isBefore(accessExpiresAt!);
  bool refreshExpired(DateTime now) =>
      refreshExpiresAt != null && !now.isBefore(refreshExpiresAt!);

  /// Local storage format, not the FastAPI response schema.
  Map<String, dynamic> toJson() => {
    'access': accessToken,
    'refresh': refreshToken,
    if (accessExpiresAt != null)
      'accessExpiresAt': accessExpiresAt!.toUtc().toIso8601String(),
    if (refreshExpiresAt != null)
      'refreshExpiresAt': refreshExpiresAt!.toUtc().toIso8601String(),
  };

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final access = json['access'] as String;
    final refresh = json['refresh'] as String;
    if (access.isEmpty || refresh.isEmpty) {
      throw const FormatException('Empty tokens');
    }
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: json['accessExpiresAt'] == null
          ? null
          : DateTime.parse(json['accessExpiresAt'] as String),
      refreshExpiresAt: json['refreshExpiresAt'] == null
          ? null
          : DateTime.parse(json['refreshExpiresAt'] as String),
    );
  }
}
