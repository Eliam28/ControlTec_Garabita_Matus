import 'dart:async';
import 'dart:convert';

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/api/services/session_http_client.dart';
import 'package:controltec_app/api/services/token_store.dart';
import 'package:controltec_app/base/custom_exception.dart';
import 'package:controltec_app/main.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/screens/controllers/login_controller.dart';
import 'package:controltec_app/screens/home_screen.dart';
import 'package:controltec_app/screens/login_screen.dart';
import 'package:controltec_app/screens/session_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/login_test_support.dart';
import 'support/session_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tokens = AuthTokens(
    accessToken: 'saved-access',
    refreshToken: 'saved-refresh',
  );

  test(
    'Stored credentials are checked with me before restoring the user',
    () async {
      final store = MemoryStore()..tokens = tokens;
      final paths = <String>[];
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          paths.add(request.url.path);
          expect(request.headers['Authorization'], 'Bearer saved-access');
          return jsonResponse({'user': mobileSession()['user']});
        },
      );
      final restored = await dependencies.loginService.restoreSession();
      expect(restored!.technician.name, 'Juan Pérez');
      expect(paths, [ApiRoutes.me]);
    },
  );

  test(
    'A known expired access token renews once and persists expiration metadata',
    () async {
      final store = MemoryStore()
        ..tokens = AuthTokens(
          accessToken: 'expired',
          refreshToken: 'saved-refresh',
          accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          refreshExpiresAt: DateTime.now().add(const Duration(days: 1)),
        );
      final paths = <String>[];
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          paths.add(request.url.path);
          expect(request.url.path, ApiRoutes.refresh);
          expect(jsonDecode(request.body), {'refresh_token': 'saved-refresh'});
          return jsonResponse(mobileSession());
        },
      );
      expect(
        (await dependencies.loginService.restoreSession())!.technician.name,
        'Juan Pérez',
      );
      expect(paths, [ApiRoutes.refresh]);
      expect(store.tokens!.accessToken, 'test-only-access');
      expect(store.tokens!.accessExpiresAt!.isAfter(DateTime.now()), isTrue);
      expect(
        AuthTokens.fromJson(store.tokens!.toJson()).refreshExpiresAt,
        store.tokens!.refreshExpiresAt,
      );
    },
  );

  test(
    '401 from me is recovered using refresh without repeating login',
    () async {
      final store = MemoryStore()..tokens = tokens;
      final paths = <String>[];
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          paths.add(request.url.path);
          return request.url.path == ApiRoutes.me
              ? http.Response('', 401)
              : jsonResponse(mobileSession());
        },
      );
      expect(await dependencies.loginService.restoreSession(), isNotNull);
      expect(paths, [ApiRoutes.me, ApiRoutes.refresh]);
    },
  );

  test('A revoked refresh clears the stored pair and returns to an unauthenticated state', () async {
    final store = MemoryStore()..tokens = tokens;
    final dependencies = sessionDependencies(
      store: store,
      handler: (_) async => http.Response('', 401),
    );
    final controller = LoginController(dependencies.loginService);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.session, isNull);
    expect(controller.recoveryError, isNull);
    expect(controller.isCheckingSession, isFalse);
    expect(store.tokens, isNull);
  });

  test(
    'A refresh that was already expired locally is discarded without HTTP',
    () async {
      final store = MemoryStore()
        ..tokens = AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          refreshExpiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        );
      final dependencies = sessionDependencies(
        store: store,
        handler: (_) async => throw StateError('Must not send'),
      );
      expect(await dependencies.loginService.restoreSession(), isNull);
      expect(store.tokens, isNull);
    },
  );

  for (final status in [403, 500]) {
    test(
      'Restore HTTP $status ${status == 403 ? 'invalidates' : 'preserves'} the saved session',
      () async {
        final store = MemoryStore()..tokens = tokens;
        final dependencies = sessionDependencies(
          store: store,
          handler: (_) async => http.Response('', status),
        );
        final controller = LoginController(dependencies.loginService);
        addTearDown(controller.dispose);
        await controller.initialize();
        expect(controller.session, isNull);
        expect(store.tokens == null, status == 403);
        expect(controller.recoveryError == null, status == 403);
      },
    );
  }

  test(
    'A temporary outage preserves tokens and permits recovery on retry',
    () async {
      final store = MemoryStore()..tokens = tokens;
      bool offline = true;
      final dependencies = sessionDependencies(
        store: store,
        handler: (_) async {
          if (offline) throw http.ClientException('offline');
          return jsonResponse({'user': mobileSession()['user']});
        },
      );
      final controller = LoginController(dependencies.loginService);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.recoveryError, isNotNull);
      expect(store.tokens, same(tokens));
      offline = false;
      await controller.initialize();
      expect(controller.session!.technician.name, 'Juan Pérez');
      expect(controller.recoveryError, isNull);
    },
  );

  test('Concurrent protected 401 responses share a refresh and retry with the rotated token', () async {
    final store = MemoryStore()..tokens = tokens;
    int refreshes = 0;
    final refreshGate = Completer<http.Response>();
    final started = Completer<void>();
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async {
        if (request.url.path == ApiRoutes.refresh) {
          refreshes++;
          if (!started.isCompleted) started.complete();
          return refreshGate.future;
        }
        if (request.headers['Authorization'] == 'Bearer saved-access') {
          return http.Response('', 401);
        }
        expect(request.headers['Authorization'], 'Bearer test-only-access');
        return http.Response('ok', 200);
      },
    );
    final client =
        dependencies.loginService.loginApi!.httpClient as SessionHttpClient;
    final first = client.get(
      Uri.parse('https://example.com${ApiRoutes.myDay}'),
    );
    final second = client.get(
      Uri.parse('https://example.com${ApiRoutes.signatureImage}'),
    );
    await started.future;
    refreshGate.complete(jsonResponse(mobileSession()));
    expect(
      (await Future.wait([first, second]))
          .every((response) => response.statusCode == 200),
      isTrue,
    );
    expect(refreshes, 1);
  });

  test('A second rejected Bearer invalidates the session after one refresh attempt', () async {
    final store = MemoryStore()..tokens = tokens;
    int invalidations = 0;
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async => request.url.path == ApiRoutes.refresh
          ? jsonResponse(mobileSession())
          : http.Response('', 401),
    );
    dependencies.loginService.onSessionInvalidated = () => invalidations++;
    final response = await dependencies.loginService.loginApi!.httpClient.get(
      Uri.parse('https://example.com${ApiRoutes.myDay}'),
    );
    expect(response.statusCode, 401);
    expect(invalidations, 1);
    expect(store.tokens, isNull);
  });

  test('Revalidating an active session preserves it during outages but removes it after revocation', () async {
    final store = MemoryStore()..tokens = tokens;
    int status = 200;
    final dependencies = sessionDependencies(
      store: store,
      handler: (_) async {
        if (status == 0) throw http.ClientException('offline');
        return status == 200
            ? jsonResponse({'user': mobileSession()['user']})
            : http.Response('', status);
      },
    );
    final controller = LoginController(dependencies.loginService);
    addTearDown(controller.dispose);
    await controller.initialize();
    status = 0;
    await controller.validateActiveSession();
    expect(controller.session, isNotNull);
    expect(store.tokens, isNotNull);
    status = 401;
    await controller.validateActiveSession();
    expect(controller.session, isNull);
    expect(store.tokens, isNull);
  });

  test('A late refresh cannot restore tokens after logout', () async {
    final store = MemoryStore()..tokens = tokens;
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async {
        if (request.url.path == ApiRoutes.refresh) {
          started.complete();
          return gate.future;
        }
        return http.Response('', 204);
      },
    );
    final refresh = dependencies.loginService.refresh();
    await started.future;
    await dependencies.loginService.logout();
    final check = expectLater(
      refresh,
      throwsA(
        isA<CustomException>().having((e) => e.code, 'code', 'stale_session'),
      ),
    );
    gate.complete(jsonResponse(mobileSession()));
    await check;
    expect(store.tokens, isNull);
  });

  testWidgets('Startup shows a loading screen instead of flashing login', (
    tester,
  ) async {
    final store = MemoryStore()..tokens = tokens;
    final gate = Completer<http.Response>();
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async => request.url.path == ApiRoutes.me
          ? gate.future
          : jsonResponse(todayVisits()),
    );
    await tester.pumpWidget(MainApp(dependencies: dependencies));
    expect(find.byType(SessionLoadingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    gate.complete(jsonResponse({'user': mobileSession()['user']}));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets(
    'A network outage at startup shows retry and retains the secure session',
    (tester) async {
      final store = MemoryStore()..tokens = tokens;
      bool offline = true;
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          if (offline) throw http.ClientException('offline');
          return jsonResponse(
            request.url.path == ApiRoutes.me
                ? {'user': mobileSession()['user']}
                : todayVisits(),
          );
        },
      );
      await tester.pumpWidget(MainApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(store.tokens, isNotNull);
      offline = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Destroying and recreating the app restores from secure storage without another login',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = SecureTokenStore();
      int logins = 0;
      Future<http.Response> handler(http.Request request) async {
        if (request.url.path == ApiRoutes.login) {
          logins++;
          return jsonResponse(mobileSession());
        }
        return jsonResponse(
          request.url.path == ApiRoutes.me
              ? {'user': mobileSession()['user']}
              : todayVisits(),
        );
      }

      final first = sessionDependencies(store: store, handler: handler);
      await first.loginService.login('test@example.com', 'test-password');
      await tester.pumpWidget(MainApp(dependencies: first));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final second = sessionDependencies(
        store: const SecureTokenStore(),
        handler: handler,
      );
      await tester.pumpWidget(MainApp(dependencies: second));
      expect(find.byType(LoginScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(logins, 1);
    },
  );
}
