import '../../base/abstract_api_handler.dart';
import '../../models/user_credentials_dto.dart';
import '../api_routes.dart';
import '../auth_messages.dart';
import 'auth_api_contract.dart';

/// Only POST /auth/mobile/login. Parsing belongs to LoginService.
class LoginApi extends AbstractApiHandler<UserCredentialsDto, String> {
  LoginApi({
    required super.httpClient,
    required super.baseUrl,
    required this.contract,
    super.timeout,
  }) : super(
         failureMessage: AuthMessages.unavailable,
         unauthorizedMessage: AuthMessages.invalidCredentials,
         configurationMessage: AuthMessages.pendingApi,
       );

  final AuthApiContract contract;

  @override
  Future<String> doExecute(UserCredentialsDto input) {
    final payload = contract.loginBody(input);
    return webClientPost(
      ApiRoutes.login,
      payload.body,
      headers: {'Content-Type': payload.contentType},
    );
  }
}
