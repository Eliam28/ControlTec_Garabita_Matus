import 'dart:async';
import 'dart:convert';

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/api/auth_messages.dart';
import 'package:controltec_app/api/services/auth_api_contract.dart';
import 'package:controltec_app/api/services/auth_session_api.dart';
import 'package:controltec_app/api/services/login_api.dart';
import 'package:controltec_app/api/services/login_service.dart';
import 'package:controltec_app/api/services/my_day_api.dart';
import 'package:controltec_app/api/services/my_day_service.dart';
import 'package:controltec_app/api/services/token_store.dart';

import 'package:controltec_app/base/custom_exception.dart';
import 'package:controltec_app/main.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/screens/controllers/login_controller.dart';
import 'package:controltec_app/screens/home_screen.dart';
import 'package:controltec_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/login_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const contract = FastApiAuthContract();

  test('Confirmed LoginRequest and MobileSessionRead authenticate without requesting me', () async {
    final store = MemoryStore();
    int calls = 0;
    final service = createTestLoginService(
      handler: (request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.url.path, ApiRoutes.login);
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'email': 'test@example.com',
          'password': ' password ',
          'door': 'staff',
        });
        return jsonResponse(sessionJson());
      },
      store: store,
    );
    final response = await service.login('test@example.com', ' password ');
    expect(calls, 1);
    expect(response.technician.name, 'Técnico de prueba');
    expect(response.technician.id, 'test-user');
    expect(response.technician.capabilities, contains('field:access'));
    expect(response.expiresIn, 3600);
    expect(response.refreshExpiresIn, 604800);
    expect(store.tokens!.accessToken, 'test-only-access');
  });

  for (final input in [
    ('', 'secret', AuthMessages.emptyFields),
    ('test@example.com', '', AuthMessages.emptyFields),
    ('invalid', 'secret', AuthMessages.invalidEmail),
  ]) {
    test('Local validation prevents HTTP for ${input.$3}', () async {
      int calls = 0;
      final service = createTestLoginService(
        handler: (_) async {
          calls++;
          return jsonResponse(sessionJson());
        },
      );
      final controller = LoginController(service);
      addTearDown(controller.dispose);
      expect(await controller.login(input.$1, input.$2), isFalse);
      expect(controller.errorMessage, input.$3);
      expect(calls, 0);
    });
  }

  for (final error in [
    (401, AuthMessages.invalidCredentials),
    (403, LoginApi.accessDeniedMessage),
    (422, LoginApi.validationMessage),
    (500, LoginApi.serverMessage),
    (503, LoginApi.serverMessage),
  ]) {
    test(
      'HTTP ${error.$1} fails with a safe message and does not persist a session',
      () async {
        final store = MemoryStore();
        final service = createTestLoginService(
          handler: (_) async => jsonResponse({
            'detail': error.$1 == 422
                ? [
                    {
                      'loc': ['body', 'password'],
                      'msg': 'Invalid value',
                      'type': 'string_too_long',
                      'input': 'NEVER DISPLAY INPUT',
                    },
                  ]
                : 'Private server details',
          }, error.$1),
          store: store,
        );
        final controller = LoginController(service);
        addTearDown(controller.dispose);
        expect(
          await controller.login('test@example.com', 'rejected-password'),
          isFalse,
        );
        expect(controller.errorMessage, error.$2);
        expect(controller.session, isNull);
        expect(controller.isLoading, isFalse);
        expect(store.tokens, isNull);
      },
    );
  }

  test('An offline login is distinguished from a timeout', () async {
    final service = createTestLoginService(
      handler: (_) async =>
          throw http.ClientException('private socket information'),
    );
    await expectLater(
      service.login('test@example.com', 'secret'),
      throwsA(
        isA<CustomException>()
            .having((error) => error.code, 'code', 'connection')
            .having(
              (error) => error.message,
              'message',
              AuthMessages.connection,
            ),
      ),
    );
  });

  test('A slow login resets loading and shows the timeout message', () async {
    final pending = Completer<http.Response>();
    final service = createTestLoginService(
      handler: (_) => pending.future,
      timeout: const Duration(milliseconds: 5),
    );
    final controller = LoginController(service);
    addTearDown(controller.dispose);
    final result = controller.login('test@example.com', 'secret');
    expect(controller.isLoading, isTrue);
    expect(await result, isFalse);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, LoginApi.timeoutMessage);
    pending.complete(jsonResponse(sessionJson()));
  });

  for (final kind in ['json', 'user', 'access', 'refresh', 'ttl', 'type']) {
    test('Rejects invalid success response: $kind', () async {
      final json = sessionJson();
      switch (kind) {
        case 'user':
          json.remove('user');
        case 'access':
          json['access_token'] = '';
        case 'refresh':
          json.remove('refresh_token');
        case 'ttl':
          json['expires_in'] = '3600';
        case 'type':
          json['token_type'] = 'cookie';
      }
      final store = MemoryStore();
      final service = createTestLoginService(
        handler: (_) async => kind == 'json'
            ? http.Response('<html>Error</html>', 200)
            : jsonResponse(json),
        store: store,
      );
      await expectLater(
        service.login('test@example.com', 'secret'),
        throwsA(
          isA<CustomException>()
              .having((error) => error.code, 'code', 'invalid_response')
              .having(
                (error) => error.message,
                'message',
                LoginService.invalidResponseMessage,
              ),
        ),
      );
      expect(store.tokens, isNull);
    });
  }

  for (final blockedUser in [
    <String, dynamic>{'active': false},
    <String, dynamic>{'role': 'customer'},
  ]) {
    test(
      'Rejects a successful response without an active staff account: $blockedUser',
      () async {
        final json = sessionJson();
        (json['user'] as Map<String, dynamic>).addAll(blockedUser);
        final store = MemoryStore();
        final service = createTestLoginService(
          handler: (_) async => jsonResponse(json),
          store: store,
        );
        await expectLater(
          service.login('test@example.com', 'secret'),
          throwsA(
            isA<CustomException>().having(
              (error) => error.message,
              'message',
              LoginApi.accessDeniedMessage,
            ),
          ),
        );
        expect(store.tokens, isNull);
      },
    );
  }

  test(
    'Secure storage failure prevents an authenticated controller session',
    () async {
      final service = createTestLoginService(
        handler: (_) async => jsonResponse(sessionJson()),
        store: FailingStore(),
      );
      final controller = LoginController(service);
      addTearDown(controller.dispose);
      expect(await controller.login('test@example.com', 'secret'), isFalse);
      expect(controller.session, isNull);
      expect(controller.isLoading, isFalse);
    },
  );

  test('Login tokens are read unchanged by the existing day service', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureTokenStore();
    final client = MockClient((request) async {
      if (request.url.path == ApiRoutes.login) {
        return jsonResponse(sessionJson());
      }
      expect(request.url.path, ApiRoutes.myDay);
      expect(request.headers['Authorization'], 'Bearer test-only-access');
      return jsonResponse({'date': '2026-11-18', 'visits': []});
    });
    addTearDown(client.close);
    final service = LoginService.api(
      loginApi: LoginApi(
        httpClient: client,
        baseUrl: 'https://example.com',
        contract: contract,
      ),
      sessionApi: AuthSessionApi(
        httpClient: client,
        baseUrl: 'https://example.com',
        contract: contract,
      ),
      contract: contract,
      tokenStore: store,
    );
    addTearDown(service.dispose);
    await service.login('test@example.com', 'secret');
    final dayService = MyDayService.api(
      api: MyDayApi(httpClient: client, baseUrl: 'https://example.com'),
      tokenStore: const SecureTokenStore(),
    );
    expect((await dayService.load()).visits, isEmpty);
    expect((await store.read())!.refreshToken, 'test-only-refresh');
  });

  test(
    'Logout clears local tokens even when the server is unreachable',
    () async {
      final store = MemoryStore()
        ..tokens = const AuthTokens(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
        );
      final service = createTestLoginService(
        handler: (_) async => throw http.ClientException('offline'),
        store: store,
      );
      await expectLater(service.logout(), throwsA(isA<CustomException>()));
      expect(store.tokens, isNull);
    },
  );

  test('Secure storage persists the pair and removes it on logout', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureTokenStore();
    final service = createTestLoginService(
      handler: (request) async => request.url.path == ApiRoutes.logout
          ? http.Response('', 204)
          : jsonResponse(sessionJson()),
      store: store,
    );
    expect(await store.read(), isNull);
    await service.login('test@example.com', 'test-password');
    expect((await store.read())!.accessToken, 'test-only-access');
    expect((await store.read())!.refreshToken, 'test-only-refresh');
    await service.logout();
    expect(await store.read(), isNull);
  });

  test('Refresh is single flight and stores the rotated pair; me and logout use Bearer', () async {
    final store = MemoryStore();
    final paths = <String>[];
    final gate = Completer<http.Response>();
    final service = createTestLoginService(
      handler: (request) async {
        paths.add(request.url.path);
        if (request.url.path == ApiRoutes.login) {
          return jsonResponse(sessionJson());
        }
        if (request.url.path == ApiRoutes.refresh) {
          expect(jsonDecode(request.body), {
            'refresh_token': 'test-only-refresh',
          });
          expect(request.headers['Authorization'], isNull);
          return gate.future;
        }
        expect(request.headers['Authorization'], 'Bearer rotated-access');
        if (request.url.path == ApiRoutes.me) {
          return jsonResponse({'user': sessionJson()['user']});
        }
        expect(request.url.path, ApiRoutes.logout);
        expect(jsonDecode(request.body), {'refresh_token': 'rotated-refresh'});
        return http.Response('', 204);
      },
      store: store,
    );
    await service.login('test@example.com', 'secret');
    final first = service.refresh();
    final second = service.refresh();
    expect(identical(first, second), isTrue);
    gate.complete(
      jsonResponse(
        sessionJson()..addAll({
          'access_token': 'rotated-access',
          'refresh_token': 'rotated-refresh',
        }),
      ),
    );
    await Future.wait([first, second]);
    expect(paths.where((path) => path == ApiRoutes.refresh), hasLength(1));
    expect(store.tokens!.refreshToken, 'rotated-refresh');
    expect((await service.me()).id, 'test-user');
    await service.logout();
    expect(store.tokens, isNull);
  });

  testWidgets('Confirmed API login navigates to the existing home screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(494, 936);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = createTestLoginService(
      handler: (_) async => jsonResponse(sessionJson()),
    );
    await tester.pumpWidget(MainApp(loginService: service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Mis servicios de hoy'), findsOneWidget);
    expect(find.text('Técnico de prueba'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
      isFalse,
    );
  });
}
