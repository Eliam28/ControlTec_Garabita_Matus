import 'dart:convert';

import '../../base/abstract_service_handler.dart';
import '../../base/custom_exception.dart';
import '../../base/handler.dart';
import '../../models/auth_response_dto.dart';
import '../../models/auth_tokens.dart';
import '../../models/technician.dart';
import '../../models/user_credentials_dto.dart';
import '../auth_messages.dart';
import 'auth_api_contract.dart';
import 'auth_session_api.dart';
import 'login_api.dart';
import 'token_store.dart';

class LoginService
    extends AbstractServiceHandler<UserCredentialsDto, AuthResponseDto> {
  // Required by the shared container; this constructor cannot authenticate.
  LoginService.mock({required Handler<UserCredentialsDto, String> loginApi})
    : loginApi = null,
      contract = null,
      sessionApi = null,
      tokenStore = null,
      super(
        failureMessage: AuthMessages.unavailable,
        connectionMessage: AuthMessages.connection,
      );

  LoginService.api({
    required LoginApi this.loginApi,
    required AuthApiContract this.contract,
    required AuthSessionApi this.sessionApi,
    required TokenStore this.tokenStore,
  }) : super(
         failureMessage: AuthMessages.unavailable,
         connectionMessage: AuthMessages.connection,
       );

  final LoginApi? loginApi;
  final AuthApiContract? contract;
  final AuthSessionApi? sessionApi;
  final TokenStore? tokenStore;
  Future<AuthResponseDto>? _refreshInFlight;

  static const invalidResponseMessage =
      'La respuesta del servidor no es válida. Intente nuevamente';

  Future<AuthResponseDto> login(String email, String password) =>
      execute(UserCredentialsDto(email: email, password: password));

  @override
  Future<AuthResponseDto> doExecute(UserCredentialsDto input) async {
    _requireConfiguration();
    final String body;
    try {
      body = await loginApi!.execute(input);
    } on FormatException {
      throw const CustomException(
        message: invalidResponseMessage,
        code: 'invalid_response',
      );
    }
    final response = _readSession(body);
    await tokenStore!.write(response.tokens);
    return response;
  }

  Future<AuthResponseDto> refresh() {
    // The backend rotates refresh tokens: concurrent callers must renew once.
    return _refreshInFlight ??= runSafely(() async {
      _requireConfiguration();
      final previous = await _requireTokens();
      final response = _readSession(await sessionApi!.refresh(previous));
      await tokenStore!.write(response.tokens);
      return response;
    }).whenComplete(() => _refreshInFlight = null);
  }

  Future<Technician> me() => runSafely(() async {
    _requireConfiguration();
    return _fetchTechnician(await _requireTokens());
  });

  Future<void> logout() => runSafely(() async {
    _requireConfiguration();
    try {
      final tokens = await tokenStore!.read();
      if (tokens != null) await sessionApi!.logout(tokens);
    } finally {
      await tokenStore!.clear();
    }
  });

  void _requireConfiguration() {
    if (loginApi == null ||
        contract == null ||
        sessionApi == null ||
        tokenStore == null) {
      throw const CustomException(
        message: AuthMessages.pendingApi,
        code: 'configuration',
      );
    }
  }

  Future<AuthTokens> _requireTokens() async =>
      await tokenStore!.read() ??
      (throw const CustomException(message: AuthMessages.expiredSession));

  AuthResponseDto _readSession(String body) {
    try {
      final json = jsonDecode(body);
      final response = contract!.readSession(json);
      if (!response.technician.active ||
          response.technician.role == 'customer') {
        throw const CustomException(
          message: LoginApi.accessDeniedMessage,
          code: 'forbidden',
        );
      }
      return response;
    } on FormatException {
      throw const CustomException(
        message: invalidResponseMessage,
        code: 'invalid_response',
      );
    } on TypeError {
      throw const CustomException(
        message: invalidResponseMessage,
        code: 'invalid_response',
      );
    }
  }

  Future<Technician> _fetchTechnician(AuthTokens tokens) async {
    final body = await sessionApi!.execute(tokens);
    try {
      return contract!.readTechnician(jsonDecode(body));
    } on FormatException {
      throw const CustomException(
        message: invalidResponseMessage,
        code: 'invalid_response',
      );
    } on TypeError {
      throw const CustomException(
        message: invalidResponseMessage,
        code: 'invalid_response',
      );
    }
  }

  void dispose() => _refreshInFlight = null;
}
