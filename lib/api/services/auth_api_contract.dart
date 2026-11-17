import '../../base/custom_exception.dart';
import '../auth_messages.dart';
import '../../models/auth_request_body.dart';
import '../../models/user_credentials_dto.dart';
import '../../models/auth_tokens.dart';
import '../../models/technician.dart';

abstract interface class AuthApiContract {
  AuthRequestBody loginBody(UserCredentialsDto credentials);
  AuthRequestBody refreshBody(String refreshToken);
  AuthRequestBody logoutBody(String refreshToken);
  AuthTokens readTokens(Object? response, {AuthTokens? previousTokens});
  Technician readTechnician(Object? response);
}

/// TODO(api-contract): Replace at the composition root once FastAPI provides
/// content types, request/response keys, refresh rotation and profile schema.
/// Fail before sending credentials rather than assume an undocumented format.
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
  AuthTokens readTokens(Object? response, {AuthTokens? previousTokens}) =>
      _pending();
  @override
  Technician readTechnician(Object? response) => _pending();
}
