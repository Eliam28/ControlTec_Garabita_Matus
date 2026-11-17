import 'dart:convert';

import 'package:controltec_app/api/services/login_api.dart';
import 'package:controltec_app/api/services/login_service.dart';
import 'package:controltec_app/api/services/auth_session_api.dart';
import 'package:controltec_app/api/services/auth_api_contract.dart';
import 'package:controltec_app/base/custom_exception.dart';
import 'package:controltec_app/models/auth_request_body.dart';
import 'package:controltec_app/api/services/token_store.dart';
import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/api/auth_messages.dart';
import 'package:controltec_app/models/user_credentials_dto.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/models/technician.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const credentials = UserCredentialsDto(
    email: 'user@example.com',
    password: 'secret',
  );
  const initialTokens = AuthTokens(
    accessToken: 'access',
    refreshToken: 'refresh',
  );

  test('Pending JSON contract fails before making any HTTP request', () async {
    final service = createApiService(
      baseUrl: 'https://example.com',
      contract: const PendingAuthApiContract(),
      tokenStore: MemoryTokenStore(),
      client: MockClient((_) => throw StateError('Must not send')),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.execute(credentials),
      throwsA(
        isA<CustomException>().having(
          (e) => e.message,
          'message',
          AuthMessages.pendingApi,
        ),
      ),
    );
  });

  test('REST uses documented routes, sends Bearer only when needed, stores and rotates tokens', () async {
    final store = MemoryTokenStore();
    final paths = <String>[];
    final service = createApiService(
      baseUrl: 'https://example.com/api/',
      contract: TestContract(),
      tokenStore: store,
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.scheme, 'https');
        if (request.url.path.endsWith(ApiRoutes.login)) {
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'fixtureEmail': credentials.email,
            'fixturePassword': credentials.password,
          });
          return http.Response('["access", "refresh"]', 200);
        }
        if (request.url.path.endsWith(ApiRoutes.refresh)) {
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), ['refresh']);
          return http.Response('["new-access", "new-refresh"]', 200);
        }
        if (request.url.path.endsWith(ApiRoutes.logout)) {
          expect(request.headers['Authorization'], 'Bearer new-access');
          expect(jsonDecode(request.body), ['new-refresh']);
          return http.Response('', 204);
        }
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], startsWith('Bearer '));
        return http.Response('"Technician"', 200);
      }),
    );
    addTearDown(service.dispose);
    final session = await service.execute(credentials);
    expect(session.isMock, isFalse);
    expect(store.tokens!.accessToken, 'access');
    expect((await service.me()).name, 'Technician');
    await service.refresh();
    expect(store.tokens!.refreshToken, 'new-refresh');
    await service.logout();
    expect(store.tokens, isNull);
    expect(paths, [
      '/api${ApiRoutes.login}',
      '/api${ApiRoutes.me}',
      '/api${ApiRoutes.me}',
      '/api${ApiRoutes.refresh}',
      '/api${ApiRoutes.me}',
      '/api${ApiRoutes.logout}',
    ]);
  });

  for (final status in [401, 500]) {
    test('Login HTTP $status does not establish a stored session', () async {
      final store = MemoryTokenStore();
      final service = createApiService(
        baseUrl: 'https://example.com',
        contract: TestContract(),
        tokenStore: store,
        client: MockClient(
          (_) async => http.Response('sensitive server details', status),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.execute(credentials),
        throwsA(
          isA<CustomException>().having(
            (e) => e.message,
            'message',
            status == 401
                ? AuthMessages.invalidCredentials
                : AuthMessages.unavailable,
          ),
        ),
      );
      expect(store.tokens, isNull);
    });
  }

  test(
    'Profile failure does not persist the tokens from an incomplete login',
    () async {
      final store = MemoryTokenStore();
      final service = createApiService(
        baseUrl: 'https://example.com',
        contract: TestContract(),
        tokenStore: store,
        client: MockClient(
          (request) async => request.url.path == ApiRoutes.login
              ? http.Response('["a", "r"]', 200)
              : http.Response('', 401),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.execute(credentials),
        throwsA(isA<CustomException>()),
      );
      expect(store.tokens, isNull);
    },
  );

  test(
    'Logout clears local storage even when the server is unreachable',
    () async {
      final store = MemoryTokenStore()..tokens = initialTokens;
      final service = createApiService(
        baseUrl: 'https://example.com',
        contract: TestContract(),
        tokenStore: store,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(service.dispose);
      await expectLater(service.logout(), throwsA(isA<CustomException>()));
      expect(store.tokens, isNull);
    },
  );

  for (final body in ['invalid JSON', '["", ""]', '{}']) {
    test('Malformed token payload is rejected: $body', () async {
      final service = createApiService(
        baseUrl: 'https://example.com',
        contract: TestContract(),
        tokenStore: MemoryTokenStore(),
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.execute(credentials),
        throwsA(
          isA<CustomException>().having(
            (e) => e.message,
            'message',
            AuthMessages.unavailable,
          ),
        ),
      );
    });
  }

  test('Timeout becomes a connection error', () async {
    final service = createApiService(
      baseUrl: 'https://example.com',
      contract: TestContract(),
      tokenStore: MemoryTokenStore(),
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return http.Response('', 200);
      }),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.execute(credentials),
      throwsA(
        isA<CustomException>().having(
          (e) => e.message,
          'message',
          AuthMessages.connection,
        ),
      ),
    );
  });

  test('Secure store persists the pair and removes it on logout', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureTokenStore();
    expect(await store.read(), isNull);
    await store.write(initialTokens);
    expect((await store.read())!.accessToken, 'access');
    expect((await store.read())!.refreshToken, 'refresh');
    await store.clear();
    expect(await store.read(), isNull);
  });
}

LoginService createApiService({
  required String baseUrl,
  required AuthApiContract contract,
  required TokenStore tokenStore,
  required http.Client client,
  Duration timeout = const Duration(seconds: 20),
}) {
  addTearDown(client.close);
  return LoginService.api(
    loginApi: LoginApi(
      httpClient: client,
      baseUrl: baseUrl,
      contract: contract,
      timeout: timeout,
    ),
    sessionApi: AuthSessionApi(
      httpClient: client,
      baseUrl: baseUrl,
      contract: contract,
      timeout: timeout,
    ),
    contract: contract,
    tokenStore: tokenStore,
  );
}

class MemoryTokenStore implements TokenStore {
  AuthTokens? tokens;
  @override
  Future<AuthTokens?> read() async => tokens;
  @override
  Future<void> write(AuthTokens value) async => tokens = value;
  @override
  Future<void> clear() async => tokens = null;
}

/// Test fixture only. This schema is deliberately unrelated to the pending API.
class TestContract implements AuthApiContract {
  AuthRequestBody _body(Object data) =>
      AuthRequestBody(body: jsonEncode(data), contentType: 'application/json');
  @override
  AuthRequestBody loginBody(UserCredentialsDto credentials) => _body({
    'fixtureEmail': credentials.email,
    'fixturePassword': credentials.password,
  });
  @override
  AuthRequestBody refreshBody(String refreshToken) => _body([refreshToken]);
  @override
  AuthRequestBody logoutBody(String refreshToken) => _body([refreshToken]);
  @override
  AuthTokens readTokens(Object? response, {AuthTokens? previousTokens}) {
    final list = response as List<dynamic>;
    return AuthTokens(
      accessToken: list[0] as String,
      refreshToken: list[1] as String,
    );
  }

  @override
  Technician readTechnician(Object? response) => Technician(
    name: response as String,
    role: 'técnico',
    hasSignature: false,
  );
}
