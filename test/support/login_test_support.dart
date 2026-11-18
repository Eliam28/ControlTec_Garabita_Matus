import 'dart:async';
import 'dart:convert';

import 'package:controltec_app/api/services/auth_api_contract.dart';
import 'package:controltec_app/api/services/auth_session_api.dart';
import 'package:controltec_app/api/services/login_api.dart';
import 'package:controltec_app/api/services/login_service.dart';
import 'package:controltec_app/api/services/token_store.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

LoginService createTestLoginService({
  required Future<http.Response> Function(http.Request) handler,
  TokenStore? store,
  Duration timeout = const Duration(seconds: 1),
}) {
  final client = MockClient(handler);
  addTearDown(client.close);
  const contract = FastApiAuthContract();
  final service = LoginService.api(
    loginApi: LoginApi(
      httpClient: client,
      baseUrl: 'https://example.com',
      contract: contract,
      timeout: timeout,
    ),
    sessionApi: AuthSessionApi(
      httpClient: client,
      baseUrl: 'https://example.com',
      contract: contract,
    ),
    contract: contract,
    tokenStore: store ?? MemoryStore(),
  );
  addTearDown(service.dispose);
  return service;
}

class PendingLoginResponse {
  final result = Completer<http.Response>();
  final started = Completer<void>();
  int calls = 0;

  Future<http.Response> handle(http.Request request) {
    calls++;
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

Map<String, dynamic> sessionJson() => {
  'user': {
    'id': 'test-user',
    'full_name': 'Técnico de prueba',
    'role': 'technician',
    'active': true,
    'email': 'test@example.com',
    'avatar_url': null,
    'has_signature': true,
    'capabilities': ['field:access'],
  },
  'access_token': 'test-only-access',
  'refresh_token': 'test-only-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_expires_in': 604800,
};

http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class MemoryStore implements TokenStore {
  AuthTokens? tokens;
  @override
  Future<AuthTokens?> read() async => tokens;
  @override
  Future<void> write(AuthTokens value) async => tokens = value;
  @override
  Future<void> clear() async => tokens = null;
}

class FailingStore extends MemoryStore {
  @override
  Future<void> write(AuthTokens value) async =>
      throw Exception('Secure storage unavailable');
}
