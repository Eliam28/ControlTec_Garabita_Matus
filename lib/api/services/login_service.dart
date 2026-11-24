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
  int _sessionRevision = 0;
  bool _disposed = false;
  void Function()? onSessionInvalidated;
  void Function(AuthResponseDto)? onSessionUpdated;

  int get sessionRevision => _sessionRevision;

  static const invalidResponseMessage =
      'La respuesta del servidor no es válida. Intente nuevamente';

  Future<AuthResponseDto> login(String email, String password) =>
      execute(UserCredentialsDto(email: email, password: password));

  @override
  Future<AuthResponseDto> doExecute(UserCredentialsDto input) async {
    _requireConfiguration();
    final revision = _sessionRevision;
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
    await _storeSession(response, revision);
    return response;
  }

  /// A saved token pair is only a candidate: /me or refresh must confirm it.
  Future<AuthResponseDto?> restoreSession() => runSafely(() async {
    _requireConfiguration();
    final revision = _sessionRevision;
    final tokens = await tokenStore!.read();
    if (tokens == null) return null;
    if (tokens.refreshExpired(DateTime.now().toUtc())) {
      await invalidateSession();
      return null;
    }
    if (tokens.accessExpired(DateTime.now().toUtc())) {
      try {
        return await refresh();
      } on CustomException catch (error) {
        if (_definitelyInvalid(error)) return null;
        rethrow;
      }
    }
    try {
      final technician = await _fetchTechnician(tokens);
      _validateTechnician(technician);
      _checkRevision(revision);
      return AuthResponseDto.api(technician: technician, tokens: tokens);
    } on CustomException catch (error) {
      if (error.status == 401) {
        try {
          return await refresh();
        } on CustomException catch (refreshError) {
          if (_definitelyInvalid(refreshError)) return null;
          rethrow;
        }
      }
      if (_definitelyInvalid(error)) {
        await invalidateSession();
        return null;
      }
      rethrow;
    }
  });

  Future<AuthResponseDto> refresh() {
    // The backend rotates refresh tokens: concurrent callers must renew once.
    return _refreshInFlight ??= runSafely(() async {
      _requireConfiguration();
      final revision = _sessionRevision;
      final previous = await _requireTokens();
      try {
        if (previous.refreshExpired(DateTime.now().toUtc())) {
          throw const CustomException(
            message: AuthMessages.expiredSession,
            status: 401,
          );
        }
        final response = _readSession(await sessionApi!.refresh(previous));
        await _storeSession(response, revision);
        if (!_disposed) onSessionUpdated?.call(response);
        return response;
      } on CustomException catch (error) {
        if (_definitelyInvalid(error) && revision == _sessionRevision) {
          await invalidateSession();
        }
        rethrow;
      }
    }).whenComplete(() => _refreshInFlight = null);
  }

  Future<Technician> me() => runSafely(() async {
    _requireConfiguration();
    return _fetchTechnician(await _requireTokens());
  });

  Future<void> logout() => runSafely(() async {
    _requireConfiguration();
    _sessionRevision++;
    try {
      final tokens = await tokenStore!.read();
      if (tokens != null) await sessionApi!.logout(tokens);
    } finally {
      await invalidateSession();
    }
  });

  Future<void> invalidateSession() async {
    _sessionRevision++;
    try {
      await tokenStore?.clear();
    } finally {
      if (!_disposed) onSessionInvalidated?.call();
    }
  }

  bool _definitelyInvalid(CustomException error) =>
      error.status == 401 ||
      error.status == 403 ||
      error.status == 422 ||
      error.code == 'forbidden';

  Future<void> _storeSession(AuthResponseDto response, int revision) async {
    _checkRevision(revision);
    await tokenStore!.write(response.tokens);
    if (revision != _sessionRevision) {
      await tokenStore!.clear();
      _checkRevision(revision);
    }
  }

  void _checkRevision(int revision) {
    if (_disposed || revision != _sessionRevision) {
      throw const CustomException(
        message: AuthMessages.expiredSession,
        code: 'stale_session',
      );
    }
  }

  void _validateTechnician(Technician technician) {
    if (!technician.active || technician.role == 'customer') {
      throw const CustomException(
        message: LoginApi.accessDeniedMessage,
        code: 'forbidden',
      );
    }
  }

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
      (throw const CustomException(
        message: AuthMessages.expiredSession,
        status: 401,
      ));

  AuthResponseDto _readSession(String body) {
    try {
      final json = jsonDecode(body);
      final response = contract!.readSession(json);
      _validateTechnician(response.technician);
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

  void dispose() {
    _disposed = true;
    _sessionRevision++;
    onSessionInvalidated = null;
    onSessionUpdated = null;
    _refreshInFlight = null;
  }
}
