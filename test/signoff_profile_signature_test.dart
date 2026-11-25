import 'dart:async';
import 'dart:convert';

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/api/app_dependencies.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/models/report_context.dart';
import 'package:controltec_app/screens/signature_screen.dart';
import 'package:controltec_app/screens/signoff_tab.dart';
import 'package:controltec_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/login_test_support.dart';
import 'support/products_test_support.dart';
import 'support/session_test_support.dart';

const _tokens = AuthTokens(
  accessToken: 'saved-access',
  refreshToken: 'saved-refresh',
);

Future<AppDependencies> _open(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) handler,
  void Function(String)? onCompleted,
  Size size = const Size(456, 886),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dependencies = sessionDependencies(
    store: MemoryStore()..tokens = _tokens,
    handler: handler,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SignoffTab(
          service: dependencies.reportService!,
          report: ReportContext.fromJson(productsContext()),
          onCompleted: onCompleted ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return dependencies;
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester) async {
  final capture = find.widgetWithText(FilledButton, 'Capturar firma').first;
  await _reveal(tester, capture);
  await tester.tap(capture);
  await tester.pumpAndSettle();
  expect(find.byType(SignatureScreen), findsOneWidget);
  final canvas = find.descendant(
    of: find.byType(SignatureScreen),
    matching: find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onPanStart != null,
    ),
  );
  await tester.drag(canvas, const Offset(75, 30));
  await tester.pump();
  final save = tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar firma'))
      .onPressed!;
  // Await the actual PNG export instead of racing a fixed delay in fake time.
  await tester.runAsync(() async => await (save as dynamic)());
  await tester.pumpAndSettle();
  expect(find.byType(SignatureScreen), findsNothing);
}

void main() {
  test('Stored signature remains server-side while the client signature and original fields are uploaded', () async {
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = _tokens,
      handler: (request) async {
        expect(request.url.path, ApiRoutes.completeReport('visit-0'));
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer saved-access');
        final body = latin1.decode(request.bodyBytes);
        for (final name in [
          'signature',
          'received_by_name',
          'charged_amount',
          'recommendations',
          'general_notes',
          'signed_at',
        ]) {
          expect(body, contains('name="$name"'));
        }
        expect(body, isNot(contains('name="technician_signature"')));
        return jsonResponse({'payment_status': 'pendiente'}, 201);
      },
    );
    expect(
      await dependencies.reportService!.complete(
        visitId: 'visit-0',
        receivedBy: 'Cliente',
        amount: '100.00',
        recommendations: 'Recomendaciones',
        notes: 'Observaciones',
        signature: signaturePng(),
      ),
      'pendiente',
    );
  });

  test('Profile and preview reuse authentication and recover an expired access token', () async {
    int refreshes = 0;
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = _tokens,
      handler: (request) async {
        if (request.url.path == ApiRoutes.profile) {
          return jsonResponse(mobileSession(hasSignature: true)['user']!);
        }
        if (request.url.path == ApiRoutes.refresh) {
          refreshes++;
          return jsonResponse(mobileSession(hasSignature: true));
        }
        expect(request.url.path, ApiRoutes.signatureImage);
        if (request.headers['Authorization'] == 'Bearer saved-access') {
          return jsonResponse({'detail': 'expired'}, 401);
        }
        expect(request.headers['Authorization'], 'Bearer test-only-access');
        return http.Response.bytes(
          signaturePng(),
          200,
          headers: {'content-type': 'image/png'},
        );
      },
    );
    expect((await dependencies.reportService!.profile()).hasSignature, isTrue);
    expect(
      await dependencies.reportService!.profileSignature(),
      orderedEquals(signaturePng()),
    );
    expect(refreshes, 1);
  });

  testWidgets(
    'Registered signature is displayed and only the client must draw before completion',
    (tester) async {
      String? completed;
      int writes = 0;
      await _open(
        tester,
        onCompleted: (value) => completed = value,
        handler: (request) async {
          if (request.url.path == ApiRoutes.profile) {
            return jsonResponse(mobileSession(hasSignature: true)['user']!);
          }
          if (request.url.path == ApiRoutes.signatureImage) {
            return http.Response.bytes(signaturePng(), 200);
          }
          expect(request.url.path, ApiRoutes.completeReport('visit-0'));
          writes++;
          final body = latin1.decode(request.bodyBytes);
          expect(body, contains('name="signature"'));
          expect(body, isNot(contains('name="technician_signature"')));
          return jsonResponse({'payment_status': 'pendiente'}, 201);
        },
      );
      final finish = find.widgetWithText(FilledButton, 'Terminar servicio');
      expect(tester.widget<FilledButton>(finish).onPressed, isNull);
      await tester.enterText(
        find.byType(TextField).at(2),
        'Recomendaciones conservadas',
      );
      await _reveal(
        tester,
        find.text('Se usará la firma registrada en tu perfil.'),
      );
      expect(
        find.widgetWithText(FilledButton, 'Capturar firma'),
        findsOneWidget,
      );
      expect(
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
        orderedEquals(signaturePng()),
      );
      await _capture(tester);
      expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);
      await tester.tap(finish);
      await tester.pump();
      expect(completed, 'pendiente');
      expect(writes, 1);
    },
  );

  testWidgets(
    'Without a registered signature the original two captures are still required and uploaded',
    (tester) async {
      String? completed;
      await _open(
        tester,
        onCompleted: (value) => completed = value,
        handler: (request) async {
          if (request.url.path == ApiRoutes.profile) {
            return jsonResponse(mobileSession()['user']!);
          }
          expect(request.url.path, ApiRoutes.completeReport('visit-0'));
          final body = latin1.decode(request.bodyBytes);
          expect(body, contains('name="signature"'));
          expect(body, contains('name="technician_signature"'));
          return jsonResponse({'payment_status': 'pendiente'}, 201);
        },
      );
      await tester.enterText(find.byType(TextField).at(2), 'Recomendaciones');
      await _capture(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Terminar servicio'),
            )
            .onPressed,
        isNull,
      );
      await _capture(tester);
      final finish = find.widgetWithText(FilledButton, 'Terminar servicio');
      expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);
      await tester.tap(finish);
      await tester.pump();
      expect(completed, 'pendiente');
    },
  );

  testWidgets(
    'Profile lookup failure can retry without discarding client fields or assuming a missing signature',
    (tester) async {
      bool offline = true;
      await _open(
        tester,
        handler: (request) async {
          expect(request.url.path, ApiRoutes.profile);
          if (offline) throw http.ClientException('offline');
          return jsonResponse(mobileSession()['user']!);
        },
      );
      await tester.enterText(
        find.byType(TextField).at(2),
        'Información conservada',
      );
      await _reveal(tester, find.text('Reintentar'));
      expect(
        find.text('No fue posible consultar si tienes una firma registrada'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Terminar servicio'),
            )
            .onPressed,
        isNull,
      );
      offline = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byType(TextField).at(2));
      expect(find.text('Información conservada'), findsOneWidget);
      expect(
        find.text('Se usará la firma registrada en tu perfil.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'A failed preview retries the real image and never requests a replacement signature',
    (tester) async {
      bool unavailable = true;
      await _open(
        tester,
        handler: (request) async {
          if (request.url.path == ApiRoutes.profile) {
            return jsonResponse(mobileSession(hasSignature: true)['user']!);
          }
          expect(request.url.path, ApiRoutes.signatureImage);
          if (unavailable) {
            return jsonResponse({'detail': 'private error'}, 500);
          }
          return http.Response.bytes(signaturePng(), 200);
        },
      );
      await _reveal(tester, find.text('Reintentar vista previa'));
      expect(
        find.text('No fue posible mostrar tu firma registrada'),
        findsOneWidget,
      );
      unavailable = false;
      await tester.tap(find.text('Reintentar vista previa'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar vista previa'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Capturar firma'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'If the registered signature is removed before completion the client signature is preserved',
    (tester) async {
      bool registered = true;
      int writes = 0;
      String? completed;
      await _open(
        tester,
        onCompleted: (value) => completed = value,
        handler: (request) async {
          if (request.url.path == ApiRoutes.profile) {
            return jsonResponse(
              mobileSession(hasSignature: registered)['user']!,
            );
          }
          if (request.url.path == ApiRoutes.signatureImage) {
            return http.Response.bytes(signaturePng(), 200);
          }
          writes++;
          if (writes == 1) {
            registered = false;
            return jsonResponse({
              'detail': 'Se requiere la firma del técnico',
            }, 422);
          }
          expect(
            latin1.decode(request.bodyBytes),
            contains('name="technician_signature"'),
          );
          return jsonResponse({'payment_status': 'pendiente'}, 201);
        },
      );
      await tester.enterText(find.byType(TextField).at(2), 'Recomendaciones');
      await _capture(tester);
      await tester.tap(find.text('Terminar servicio'));
      await tester.pumpAndSettle();
      expect(completed, isNull);
      expect(
        find.text('Se usará la firma registrada en tu perfil.'),
        findsNothing,
      );
      expect(find.byType(Image), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await _capture(tester);
      await tester.tap(find.text('Terminar servicio'));
      await tester.pump();
      expect(completed, 'pendiente');
      expect(writes, 2);
    },
  );

  testWidgets(
    'A late profile response does not update a disposed service screen',
    (tester) async {
      final gate = Completer<http.Response>();
      final dependencies = sessionDependencies(
        store: MemoryStore()..tokens = _tokens,
        handler: (request) => gate.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignoffTab(
              service: dependencies.reportService!,
              report: ReportContext.fromJson(productsContext()),
              onCompleted: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete(jsonResponse(mobileSession()['user']!));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
