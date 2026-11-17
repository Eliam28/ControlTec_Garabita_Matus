import 'dart:convert';

import 'package:controltec_app/api/app_config.dart';
import 'package:controltec_app/api/app_dependencies.dart';
import 'package:controltec_app/api/auth_messages.dart';
import 'package:controltec_app/api/services/login_api.dart';
import 'package:controltec_app/api/services/login_service.dart';
import 'package:controltec_app/base/abstract_api_handler.dart';
import 'package:controltec_app/base/custom_exception.dart';
import 'package:controltec_app/models/auth_response_dto.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/models/user_credentials_dto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/pending_login_api.dart';

void main() {
  for (final method in ['GET', 'POST', 'PUT', 'DELETE']) {
    test(
      'Shared HTTP handler sends $method with a prefix and keeps UTF-8',
      () async {
        final client = MockClient((request) async {
          expect(request.method, method);
          expect(request.url.toString(), 'https://example.com/api/probe');
          expect(request.headers['Accept'], 'application/json');
          if (method == 'POST' || method == 'PUT') {
            expect(
              request.headers['Content-Type'],
              startsWith('application/json'),
            );
            expect(jsonDecode(request.body), {'value': 'prueba'});
          }
          return http.Response.bytes(utf8.encode('Respuesta válida'), 200);
        });
        addTearDown(client.close);
        final api = ProbeApi(client: client);
        expect(await api.execute(method), 'Respuesta válida');
      },
    );
  }

  test(
    'HTTP failures retain status but do not expose the server response',
    () async {
      final client = MockClient(
        (_) async => http.Response('private details', 503),
      );
      addTearDown(client.close);
      await expectLater(
        ProbeApi(client: client).execute('GET'),
        throwsA(
          isA<CustomException>()
              .having((error) => error.status, 'HTTP status', 503)
              .having(
                (error) => error.message,
                'safe message',
                isNot(contains('private details')),
              ),
        ),
      );
    },
  );

  test('Mock configuration never constructs an HTTP client', () async {
    final dependencies = http.runWithClient(
      () => AppDependencies.fromConfig(const AppConfig()),
      () => throw StateError('HTTP client must not be created in mock mode'),
    );
    addTearDown(dependencies.dispose);
    final response = await dependencies.loginService.login(
      'tecnico@controltec.com',
      'Tecnico123',
    );
    expect(response.isMock, isTrue);
    expect(response.tokens, isNull);
    expect(dependencies.loginService.tokenStore, isNull);
  });

  test('Real configuration shares one HTTP client and disposes it once', () {
    final client = TrackingClient();
    int clientsCreated = 0;
    final dependencies = http.runWithClient(
      () => AppDependencies.fromConfig(
        const AppConfig(mockAuth: false, apiBaseUrl: 'https://example.com'),
      ),
      () {
        clientsCreated++;
        return client;
      },
    );
    final loginApi = dependencies.loginService.loginApi as LoginApi;
    expect(clientsCreated, 1);
    expect(
      loginApi.httpClient,
      same(dependencies.loginService.sessionApi!.httpClient),
    );
    dependencies.dispose();
    expect(client.closeCalls, 1);
  });

  test(
    'The service converts an invalid mock response into a safe exception',
    () async {
      final api = PendingLoginApi();
      final service = LoginService.mock(loginApi: api);
      final response = service.login('test@example.com', 'secret');
      api.result.complete('{malformed');
      await expectLater(
        response,
        throwsA(
          isA<CustomException>().having(
            (error) => error.message,
            'message',
            AuthMessages.unavailable,
          ),
        ),
      );
    },
  );

  test(
    'A custom exception survives the service boundary with its status',
    () async {
      const error = CustomException(
        message: 'Mensaje esperado',
        status: 403,
        code: 'forbidden',
      );
      final api = PendingLoginApi();
      final service = LoginService.mock(loginApi: api);
      final response = service.login('test@example.com', 'secret');
      api.result.completeError(error);
      await expectLater(response, throwsA(same(error)));
    },
  );

  test('DTO serialization round-trips the internal format without changing credentials', () {
    const credentials = UserCredentialsDto(
      email: 'user@example.com',
      password: ' secret ',
    );
    final decoded = UserCredentialsDto.fromJson(credentials.toJson());
    expect(decoded.email, credentials.email);
    expect(decoded.password, credentials.password);
    final mock = AuthResponseDto.fromJson(
      jsonDecode(mockResponse) as Map<String, dynamic>,
    );
    expect(mock.tokens, isNull);
    expect(
      AuthResponseDto.fromJson(mock.toJson()).technician.name,
      mock.technician.name,
    );
    final apiResponse = AuthResponseDto.api(
      technician: mock.technician,
      tokens: const AuthTokens(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
      ),
    );
    final restored = AuthResponseDto.fromJson(apiResponse.toJson());
    expect(restored.isMock, isFalse);
    expect(restored.tokens!.refreshToken, 'test-refresh');
  });

  test('Mock DTOs reject fabricated tokens', () {
    final json = jsonDecode(mockResponse) as Map<String, dynamic>;
    json['tokens'] = {'access': 'fake', 'refresh': 'fake'};
    expect(() => AuthResponseDto.fromJson(json), throwsFormatException);
  });
}

class ProbeApi extends AbstractApiHandler<String, String> {
  ProbeApi({required http.Client client})
    : super(httpClient: client, baseUrl: 'https://example.com/api/');

  @override
  Future<String> doExecute(String input) => switch (input) {
    'GET' => webClientGet('/probe'),
    'POST' => webClientPost(
      '/probe',
      '{"value":"prueba"}',
      headers: {'Content-Type': 'application/json'},
    ),
    'PUT' => webClientPut(
      '/probe',
      '{"value":"prueba"}',
      headers: {'Content-Type': 'application/json'},
    ),
    'DELETE' => webClientDelete('/probe'),
    _ => throw ArgumentError.value(input),
  };
}

class TrackingClient extends MockClient {
  TrackingClient()
    : super((_) async => throw StateError('No real requests in this test'));
  int closeCalls = 0;

  @override
  void close() {
    closeCalls++;
    super.close();
  }
}
