import 'dart:convert';

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/main.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/screens/home_screen.dart';
import 'package:controltec_app/screens/payment_screen.dart';
import 'package:controltec_app/screens/report_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/login_test_support.dart';
import 'support/session_test_support.dart';

const _tokens = AuthTokens(
  accessToken: 'saved-access',
  refreshToken: 'saved-refresh',
);

Map<String, dynamic> _oneVisit(String status, {String payment = 'pendiente'}) {
  final day = todayVisits();
  final visit = (day['visits'] as List).first as Map<String, dynamic>;
  visit['status'] = status;
  visit['payment_status'] = payment;
  day['visits'] = [visit];
  return day;
}

Map<String, dynamic> _report() => {
  'visit_id': 'visit-0',
  'customer_name': 'Cliente de prueba 0',
  'location_name': 'Sucursal de prueba',
  'scheduled_time_start': '09:00:00',
  'service_price': '100.00',
  'stations': [],
  'pests': [],
};

void main() {
  testWidgets(
    'Merged navigation starts and continues the existing report flow',
    (tester) async {
      final store = MemoryStore()..tokens = _tokens;
      bool started = false;
      int starts = 0;
      int contexts = 0;
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          switch (request.url.path) {
            case ApiRoutes.me:
              return jsonResponse({'user': mobileSession()['user']});
            case ApiRoutes.myDay:
              return jsonResponse(
                _oneVisit(started ? 'en_progreso' : 'programado'),
              );
            case '/scheduling/visits/visit-0/report/start':
              expect(request.method, 'POST');
              starts++;
              started = true;
              return jsonResponse({});
            case '/reports/visits/visit-0/context':
              contexts++;
              return jsonResponse(_report());
            default:
              fail('Unexpected request: ${request.url.path}');
          }
        },
      );
      await tester.pumpWidget(MainApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(home.reportService, same(dependencies.reportService));
      await tester.tap(find.text('Iniciar servicio'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportScreen), findsOneWidget);
      expect(find.text('Estaciones'), findsOneWidget);
      expect(find.text('Firma'), findsOneWidget);
      expect(starts, 1);
      expect(contexts, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Continuar servicio'), findsOneWidget);
      await tester.tap(find.text('Continuar servicio'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportScreen), findsOneWidget);
      expect(starts, 1);
      expect(contexts, 2);
    },
  );

  testWidgets(
    'Merged navigation keeps payment declaration and reloads My day',
    (tester) async {
      final store = MemoryStore()..tokens = _tokens;
      bool paid = false;
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          switch (request.url.path) {
            case ApiRoutes.me:
              return jsonResponse({'user': mobileSession()['user']});
            case ApiRoutes.myDay:
              return jsonResponse(
                _oneVisit('completado', payment: paid ? 'pagado' : 'pendiente'),
              );
            case '/reports/visits/visit-0/payment':
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), {
                'payment_status': 'pagado',
                'payment_method': 'efectivo',
              });
              paid = true;
              return jsonResponse({});
            default:
              fail('Unexpected request: ${request.url.path}');
          }
        },
      );
      await tester.pumpWidget(MainApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar pago'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentScreen), findsOneWidget);
      await tester.tap(find.text('Pagado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Efectivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(paid, isTrue);
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Registrar pago'), findsNothing);
    },
  );

  test('Report multipart requests retain fields and signatures after refreshing the shared session', () async {
    final store = MemoryStore()..tokens = _tokens;
    final uploads = <http.Request>[];
    int refreshes = 0;
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async {
        if (request.url.path == ApiRoutes.refresh) {
          refreshes++;
          expect(jsonDecode(request.body), {
            'refresh_token': _tokens.refreshToken,
          });
          return jsonResponse(mobileSession());
        }
        if (request.url.path == ApiRoutes.completeReport('visit-0')) {
          uploads.add(request);
          if (request.headers['Authorization'] == 'Bearer saved-access') {
            return jsonResponse({'detail': 'expired'}, 401);
          }
          expect(request.headers['Authorization'], 'Bearer test-only-access');
          expect(
            request.headers['Content-Type'],
            startsWith('multipart/form-data; boundary='),
          );
          final body = latin1.decode(request.bodyBytes);
          for (final field in [
            'received_by_name',
            'charged_amount',
            'recommendations',
            'general_notes',
            'signed_at',
            'signature',
            'technician_signature',
          ]) {
            expect(body, contains('name="$field"'));
          }
          return jsonResponse({'payment_status': 'pendiente'});
        }
        fail('Unexpected request: ${request.url.path}');
      },
    );
    final status = await dependencies.reportService!.complete(
      visitId: 'visit-0',
      receivedBy: 'Cliente de prueba',
      amount: '100.00',
      recommendations: 'Recomendaciones de prueba',
      notes: 'Notas de prueba',
      signature: signaturePng(),
      technicianSignature: signaturePng(),
    );
    expect(status, 'pendiente');
    expect(refreshes, 1);
    expect(uploads, hasLength(2));
    expect(uploads.first.bodyBytes, orderedEquals(uploads.last.bodyBytes));
    expect(store.tokens!.refreshToken, 'test-only-refresh');
  });
}
