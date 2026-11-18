import 'auth_tokens.dart';
import 'technician.dart';

class AuthResponseDto {
  const AuthResponseDto.mock(this.technician)
    : tokens = null,
      isMock = true,
      expiresIn = null,
      refreshExpiresIn = null;

  const AuthResponseDto.api({
    required this.technician,
    required AuthTokens this.tokens,
    this.expiresIn,
    this.refreshExpiresIn,
  }) : isMock = false;

  final Technician technician;
  final AuthTokens? tokens;
  final bool isMock;
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
      tokens: AuthTokens(accessToken: accessToken, refreshToken: refreshToken),
      expiresIn: expiresIn,
      refreshExpiresIn: refreshExpiresIn,
    );
  }

  /// Internal mock/test representation. FastAPI uses fromApiJson instead.
  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    final technician = Technician.fromJson(
      json['technician'] as Map<String, dynamic>,
    );
    final isMock = json['isMock'] as bool;
    if (isMock) {
      if (json['tokens'] != null) {
        throw const FormatException('Mock tokens are not allowed');
      }
      return AuthResponseDto.mock(technician);
    }
    return AuthResponseDto.api(
      technician: technician,
      tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
      expiresIn: json['expiresIn'] as int?,
      refreshExpiresIn: json['refreshExpiresIn'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'isMock': isMock,
    'technician': technician.toJson(),
    'tokens': tokens?.toJson(),
    if (expiresIn != null) 'expiresIn': expiresIn,
    if (refreshExpiresIn != null) 'refreshExpiresIn': refreshExpiresIn,
  };
}
