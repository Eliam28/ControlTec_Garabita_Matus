import 'dart:convert';

import '../../base/custom_exception.dart';
import '../auth_messages.dart';
import '../../models/auth_request_body.dart';
import '../../models/user_credentials_dto.dart';
import '../../models/auth_response_dto.dart';
import '../../models/technician.dart';

abstract interface class AuthApiContract {
  AuthRequestBody loginBody(UserCredentialsDto credentials);
  AuthRequestBody refreshBody(String refreshToken);
  AuthRequestBody logoutBody(String refreshToken);
  AuthResponseDto readSession(Object? response);
  Technician readTechnician(Object? response);
}

/// Explicit unconfigured contract retained for regression tests. Production
/// must select FastApiAuthContract in the composition root.
class PendingAuthApiContract implements AuthApiContract {
  const PendingAuthApiContract();

  Never _pending() => throw const CustomException(
    message: AuthMessages.pendingApi,
    code: 'configuration',
  );

  @override
  AuthRequestBody loginBody(UserCredentialsDto credentials) => _pending();
  @override
  AuthRequestBody refreshBody(String refreshToken) => _pending();
  @override
  AuthRequestBody logoutBody(String refreshToken) => _pending();
  @override
  AuthResponseDto readSession(Object? response) => _pending();
  @override
  Technician readTechnician(Object? response) => _pending();
}

/// Confirmed against /openapi.json on 2026-11-18. No cookies or CSRF on mobile.
class FastApiAuthContract implements AuthApiContract {
  const FastApiAuthContract();

  AuthRequestBody _json(Object value) =>
      AuthRequestBody(body: jsonEncode(value), contentType: 'application/json');

  @override
  AuthRequestBody loginBody(UserCredentialsDto credentials) =>
      _json({...credentials.toJson(), 'door': 'staff'});

  @override
  AuthRequestBody refreshBody(String refreshToken) =>
      _json({'refresh_token': refreshToken});

  @override
  AuthRequestBody logoutBody(String refreshToken) =>
      _json({'refresh_token': refreshToken});

  @override
  AuthResponseDto readSession(Object? response) =>
      AuthResponseDto.fromApiJson(response as Map<String, dynamic>);

  @override
  Technician readTechnician(Object? response) {
    final json = response as Map<String, dynamic>;
    return Technician.fromApiJson(json['user'] as Map<String, dynamic>);
  }
}
