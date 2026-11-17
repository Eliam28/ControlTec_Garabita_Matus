import 'auth_tokens.dart';
import 'technician.dart';

class AuthResponseDto {
  const AuthResponseDto.mock(this.technician) : tokens = null, isMock = true;

  const AuthResponseDto.api({
    required this.technician,
    required AuthTokens this.tokens,
  }) : isMock = false;

  final Technician technician;
  final AuthTokens? tokens;
  final bool isMock;

  /// Internal mock/test representation. Never decode a FastAPI payload with
  /// this factory: its unconfirmed schema belongs to AuthApiContract.
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
    );
  }

  Map<String, dynamic> toJson() => {
    'isMock': isMock,
    'technician': technician.toJson(),
    'tokens': tokens?.toJson(),
  };
}
