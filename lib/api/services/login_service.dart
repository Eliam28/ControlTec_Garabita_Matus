import 'dart:convert';

import 'package:flutter/foundation.dart';

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
import 'token_store.dart';

class LoginService
    extends AbstractServiceHandler<UserCredentialsDto, AuthResponseDto> {
  LoginService.mock({required this.loginApi})
    : contract = null,
      sessionApi = null,
      tokenStore = null,
      super(
        failureMessage: AuthMessages.unavailable,
        connectionMessage: AuthMessages.connection,
      );

  LoginService.api({
    required this.loginApi,
    required AuthApiContract this.contract,
    required AuthSessionApi this.sessionApi,
    required TokenStore this.tokenStore,
  }) : super(
         failureMessage: AuthMessages.unavailable,
         connectionMessage: AuthMessages.connection,
       );

  final Handler<UserCredentialsDto, String> loginApi;
  final AuthApiContract? contract;
  final AuthSessionApi? sessionApi;
  final TokenStore? tokenStore;
  AuthResponseDto? _session;

  bool get isMock => contract == null;

  Future<AuthResponseDto> login(String email, String password) =>
      execute(UserCredentialsDto(email: email, password: password));

  @override
  Future<AuthResponseDto> doExecute(UserCredentialsDto input) async {
    if (isMock && kReleaseMode) {
      throw const CustomException(message: AuthMessages.pendingApi);
    }
    final body = await loginApi.execute(input);
    final json = jsonDecode(body);
    if (isMock) {
      final response = AuthResponseDto.fromJson(json as Map<String, dynamic>);
      if (!response.isMock || response.tokens != null) {
        throw const FormatException('Expected mock response');
      }
      return _session = response;
    }
    final tokens = _readTokens(json);
    final technician = await _fetchTechnician(tokens);
    await tokenStore!.write(tokens);
    return _session = AuthResponseDto.api(
      technician: technician,
      tokens: tokens,
    );
  }

  Future<AuthResponseDto> refresh() => runSafely(() async {
    if (isMock) return _requireSession();
    final previous = await _requireTokens();
    final body = await sessionApi!.refresh(previous);
    final tokens = _readTokens(jsonDecode(body), previous: previous);
    // Preserve refresh-token rotation even when the next profile request fails.
    await tokenStore!.write(tokens);
    return _session = AuthResponseDto.api(
      technician: await _fetchTechnician(tokens),
      tokens: tokens,
    );
  });

  Future<Technician> me() => runSafely(
    () async => isMock
        ? _requireSession().technician
        : await _fetchTechnician(await _requireTokens()),
  );

  Future<void> logout() => runSafely(() async {
    try {
      if (!isMock) {
        final tokens = await tokenStore!.read();
        if (tokens != null) await sessionApi!.logout(tokens);
      }
    } finally {
      _session = null;
      await tokenStore?.clear();
    }
  });

  AuthResponseDto _requireSession() =>
      _session ??
      (throw const CustomException(message: AuthMessages.expiredSession));

  Future<AuthTokens> _requireTokens() async =>
      await tokenStore!.read() ??
      (throw const CustomException(message: AuthMessages.expiredSession));

  AuthTokens _readTokens(Object? response, {AuthTokens? previous}) {
    final tokens = contract!.readTokens(response, previousTokens: previous);
    if (tokens.accessToken.isEmpty || tokens.refreshToken.isEmpty) {
      throw const FormatException('Empty tokens');
    }
    return tokens;
  }

  Future<Technician> _fetchTechnician(AuthTokens tokens) async =>
      contract!.readTechnician(jsonDecode(await sessionApi!.execute(tokens)));

  void dispose() => _session = null;
}
