import '../../base/abstract_api_handler.dart';
import '../../models/auth_tokens.dart';
import '../api_routes.dart';
import '../auth_messages.dart';
import 'auth_api_contract.dart';

/// Existing refresh/logout/me preparation, sharing LoginApi's HTTP client.
/// These operations remain unused by the temporary home screen.
class AuthSessionApi extends AbstractApiHandler<AuthTokens, String> {
  AuthSessionApi({
    required super.httpClient,
    required super.baseUrl,
    required this.contract,
    super.timeout,
  }) : super(
         failureMessage: AuthMessages.unavailable,
         unauthorizedMessage: AuthMessages.expiredSession,
         configurationMessage: AuthMessages.pendingApi,
       );

  final AuthApiContract contract;

  @override
  Future<String> doExecute(AuthTokens input) => webClientGet(
    ApiRoutes.me,
    headers: {'Authorization': 'Bearer ${input.accessToken}'},
  );

  Future<String> refresh(AuthTokens tokens) {
    final payload = contract.refreshBody(tokens.refreshToken);
    return webClientPost(
      ApiRoutes.refresh,
      payload.body,
      headers: {'Content-Type': payload.contentType},
    );
  }

  Future<String> logout(AuthTokens tokens) {
    final payload = contract.logoutBody(tokens.refreshToken);
    return webClientPost(
      ApiRoutes.logout,
      payload.body,
      headers: {
        'Content-Type': payload.contentType,
        'Authorization': 'Bearer ${tokens.accessToken}',
      },
    );
  }
}
