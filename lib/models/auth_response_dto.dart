import 'auth_tokens.dart';
import 'technician.dart';

class AuthResponseDto {
  const AuthResponseDto.api({
    required this.technician,
    required this.tokens,
    this.expiresIn,
    this.refreshExpiresIn,
  });

  final Technician technician;
  final AuthTokens tokens;
  final int? expiresIn;
  final int? refreshExpiresIn;

  /// MobileSessionRead: login and refresh both include the user and token pair.
  factory AuthResponseDto.fromApiJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String;
    final refreshToken = json['refresh_token'] as String;
    final expiresIn = json['expires_in'] as int;
    final refreshExpiresIn = json['refresh_expires_in'] as int;
    if (accessToken.trim().isEmpty ||
        refreshToken.trim().isEmpty ||
        (json['token_type'] ?? 'bearer') != 'bearer' ||
        expiresIn <= 0 ||
        refreshExpiresIn <= 0) {
      throw const FormatException('Invalid mobile session');
    }
    return AuthResponseDto.api(
      technician: Technician.fromApiJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessExpiresAt: DateTime.now().toUtc().add(
          Duration(seconds: expiresIn),
        ),
        refreshExpiresAt: DateTime.now().toUtc().add(
          Duration(seconds: refreshExpiresIn),
        ),
      ),
      expiresIn: expiresIn,
      refreshExpiresIn: refreshExpiresIn,
    );
  }
}
