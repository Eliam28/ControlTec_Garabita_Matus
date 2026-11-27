import 'dart:async';
import 'dart:convert';

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/api/app_dependencies.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/models/report_context.dart';
import 'package:controltec_app/screens/controllers/report_evidence_controller.dart';
import 'package:controltec_app/screens/controllers/login_controller.dart';
import 'package:controltec_app/screens/controllers/profile_controller.dart';
import 'package:controltec_app/screens/profile_screen.dart';
import 'package:controltec_app/screens/evidence_tab.dart';
import 'package:controltec_app/screens/payment_screen.dart';
import 'package:controltec_app/screens/report_screen.dart';
import 'package:controltec_app/screens/signature_screen.dart';
import 'package:controltec_app/theme/app_theme.dart';
import 'package:controltec_app/widgets/evidence_photo_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'support/evidence_test_support.dart';
import 'support/login_test_support.dart';
import 'support/products_test_support.dart';
import 'support/session_test_support.dart';

const _tokens = AuthTokens(
  accessToken: 'saved-access',
  refreshToken: 'saved-refresh',
);

Future<void> _settleEvidence(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final tab = tester.widget<EvidenceTab>(
    find.byType(EvidenceTab, skipOffstage: false),
  );
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (tab.controller.ready &&
        !tab.controller.busy &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

Future<AppDependencies> _open(
  WidgetTester tester,
  EvidenceTestPicker picker, {
  Map<String, dynamic>? context,
  Future<http.Response> Function(http.Request)? handler,
  Size size = const Size(456, 886),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dependencies = sessionDependencies(
    store: MemoryStore()..tokens = _tokens,
    handler: (request) async {
      if (request.url.path == ApiRoutes.profile) {
        return jsonResponse(mobileSession()['user']!);
      }
      if (request.url.path == ApiRoutes.reportContext('visit-0')) {
        return jsonResponse(context ?? productsContext());
      }
      return handler != null
          ? handler(request)
          : http.Response.bytes(evidencePng(1), 200);
    },
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ReportScreen(
        service: dependencies.reportService!,
        visitId: 'visit-0',
        evidencePicker: picker,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await _settleEvidence(tester);
  return dependencies;
}

Future<void> _press(WidgetTester tester, String label) async {
  final button = find.widgetWithText(OutlinedButton, label);
  await tester.ensureVisible(button);
  final callback = tester.widget<OutlinedButton>(button).onPressed!;
  await tester.runAsync(() async => await (callback as dynamic)());
  await tester.pumpAndSettle();
}

Future<void> _signCustomer(WidgetTester tester) async {
  final capture = find.widgetWithText(FilledButton, 'Capturar firma');
  await tester.scrollUntilVisible(
    capture,
    150,
    scrollable: find.byType(Scrollable).last,
  );
  await Scrollable.ensureVisible(tester.element(capture), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(capture);
  await tester.pumpAndSettle();
  final canvas = find.descendant(
    of: find.byType(SignatureScreen),
    matching: find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onPanStart != null,
    ),
  );
  await tester.drag(canvas, const Offset(60, 30));
  await tester.pump();
  final callback = tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar firma'))
      .onPressed!;
  await tester.runAsync(() async => await (callback as dynamic)());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Profile signature recovery does not consume a photo pending for a service',
    (tester) async {
      final picker = EvidenceTestPicker()
        ..lostData = LostDataResponse(
          files: [evidenceFile(1)],
          type: RetrieveType.image,
        );
      final dependencies = sessionDependencies(
        store: MemoryStore()..tokens = _tokens,
        handler: (request) async {
          if (request.url.path == ApiRoutes.me) {
            return jsonResponse({'user': mobileSession()['user']});
          }
          expect(request.url.path, ApiRoutes.myDay);
          return jsonResponse(todayVisits());
        },
      );
      final authentication = LoginController(dependencies.loginService);
      addTearDown(authentication.dispose);
      await authentication.initialize();
      final store = dependencies.reportService!.evidenceDrafts!;
      await store.save(
        'test-user',
        'visit-0',
        [],
        store.revision,
        pickerPending: true,
      );
      final profile = ProfileController(
        authentication: authentication,
        loginService: dependencies.loginService,
        profileService: dependencies.profileService!,
        myDayService: dependencies.myDayService,
        daySnapshot: dependencies.daySnapshot!,
        evidenceDrafts: store,
      );
      addTearDown(profile.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ProfileScreen(controller: profile, imagePicker: picker),
        ),
      );
      await tester.pumpAndSettle();
      expect(picker.lostReads, 0);
      expect(find.text('Foto de mi firma'), findsNothing);
      expect(await store.hasPendingPicker('test-user'), isTrue);
    },
  );
  testWidgets(
    'Camera, gallery, enlarged preview, deletion and all four stages preserve the photo draft',
    (tester) async {
      final picker = EvidenceTestPicker()
        ..camera = evidenceFile(1)
        ..gallery = [evidenceFile(2), evidenceFile(3)];
      final dependencies = await _open(tester, picker);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
      expect(find.text('Fotografías de estaciones · 0'), findsOneWidget);
      expect(find.text('Ninguna estación lleva fotografía.'), findsOneWidget);
      await _press(tester, 'Tomar foto');
      await _press(tester, 'Elegir fotos');
      expect(find.text('Fotografías adicionales · 3/4'), findsOneWidget);
      expect(picker.requestedLimit, 3);
      expect(find.byType(EvidencePhotoTile), findsNWidgets(3));
      await tester.ensureVisible(find.byType(EvidencePhotoTile).first);
      await tester.tap(find.byType(EvidencePhotoTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(EvidencePhotoViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final remove = find
          .byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Quitar fotografía',
          )
          .first;
      await tester.ensureVisible(remove);
      final callback = tester.widget<IconButton>(remove).onPressed!;
      await tester.runAsync(() async => await (callback as dynamic)());
      await tester.pumpAndSettle();
      expect(find.text('Fotografías adicionales · 2/4'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Productos aplicados'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Fotografías adicionales · 2/4'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 3);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Fotografías adicionales · 2/4'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final recovered = ReportEvidenceController(
        visitId: 'visit-0',
        service: dependencies.reportService!,
        picker: picker,
      );
      addTearDown(recovered.dispose);
      recovered.acceptContext(ReportContext.fromJson(productsContext()));
      await tester.runAsync(recovered.initialize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: EvidenceTab(controller: recovered, onContinue: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fotografías adicionales · 2/4'), findsOneWidget);
    },
  );

  testWidgets(
    'Station and saved images use the authenticated proxy and offer no removal',
    (tester) async {
      final context = productsContext(withStation: true)
        ..['report_id'] = 'report-1';
      (context['stations'] as List).single['inspection']['photo_path'] =
          'report-1/station.png';
      context['evidence'] = [
        {
          'id': 'station-photo',
          'photo_path': 'report-1/station.png',
          'station_code': 'CB-001',
        },
        {
          'id': 'saved-photo',
          'photo_path': 'report-1/additional.png',
          'station_code': null,
        },
      ];
      final paths = <String>[];
      await _open(
        tester,
        EvidenceTestPicker(),
        context: context,
        handler: (request) async {
          expect(request.headers['Authorization'], 'Bearer saved-access');
          paths.add(request.url.path);
          return http.Response.bytes(evidencePng(paths.length), 200);
        },
      );
      expect(find.text('Fotografías de estaciones · 1'), findsOneWidget);
      expect(find.text('Fotografías adicionales · 1/4'), findsOneWidget);
      expect(find.byTooltip('Quitar fotografía'), findsNothing);
      expect(paths.toSet(), {
        ApiRoutes.reportFile('report-1', 'station.png'),
        ApiRoutes.reportFile('report-1', 'additional.png'),
      });
      expect(find.textContaining('report-1/'), findsNothing);
      await tester.tap(find.byType(EvidencePhotoTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Estación CB-001'), findsOneWidget);
    },
  );

  testWidgets(
    'Permissions, cancelled camera and over-limit selection report safe errors without adding photos',
    (tester) async {
      final picker = EvidenceTestPicker();
      await _open(tester, picker);
      await _press(tester, 'Tomar foto');
      expect(find.text('Fotografías adicionales · 0/4'), findsOneWidget);
      picker.failure = PlatformException(code: 'camera_access_denied');
      await _press(tester, 'Tomar foto');
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        AppColors.error,
      );
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 3),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      picker.failure = null;
      picker.gallery = [for (var i = 1; i <= 5; i++) evidenceFile(i)];
      await _press(tester, 'Elegir fotos');
      expect(
        find.text('La selección supera el máximo de 4 fotografías adicionales'),
        findsOneWidget,
      );
      expect(find.text('Fotografías adicionales · 0/4'), findsOneWidget);
    },
  );

  testWidgets(
    'A failed station image keeps its count and retries without exposing Storage paths',
    (tester) async {
      var unavailable = true;
      final context = productsContext()
        ..['report_id'] = 'report-1'
        ..['evidence'] = [
          {
            'id': 'photo-1',
            'photo_path': 'report-1/station.png',
            'station_code': 'CB-001',
          },
        ];
      await _open(
        tester,
        EvidenceTestPicker(),
        context: context,
        handler: (request) async => unavailable
            ? jsonResponse({'detail': 'private storage error'}, 500)
            : http.Response.bytes(evidencePng(1), 200),
      );
      expect(find.text('Fotografías de estaciones · 1'), findsOneWidget);
      expect(find.text('Reintentar foto'), findsOneWidget);
      expect(find.textContaining('private storage'), findsNothing);
      unavailable = false;
      await tester.tap(find.text('Reintentar foto'));
      await _settleEvidence(tester);
      expect(find.text('Reintentar foto'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets(
    'Pending native capture disables repeated submission and navigation until cancelled',
    (tester) async {
      final picker = EvidenceTestPicker()..cameraGate = Completer<XFile?>();
      await _open(tester, picker);
      final callback = tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Tomar foto'),
          )
          .onPressed!;
      final pending = (callback as dynamic)() as Future<void>;
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Tomar foto'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continuar'),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
      expect(picker.cameraCalls, 1);
      picker.cameraGate!.complete(null);
      await pending;
      await tester.pumpAndSettle();
      expect(find.text('Fotografías adicionales · 0/4'), findsOneWidget);
    },
  );

  testWidgets(
    'The existing signature completion retains photos after failure and clears the draft only after confirmation',
    (tester) async {
      final picker = EvidenceTestPicker()..camera = evidenceFile(1);
      final calls = <http.Request>[];
      final gate = Completer<http.Response>();
      final dependencies = sessionDependencies(
        store: MemoryStore()..tokens = _tokens,
        handler: (request) async {
          if (request.url.path == ApiRoutes.me) {
            return jsonResponse({
              'user': mobileSession(hasSignature: true)['user'],
            });
          }
          if (request.url.path == ApiRoutes.profile) {
            return jsonResponse(mobileSession(hasSignature: true)['user']!);
          }
          if (request.url.path == ApiRoutes.signatureImage) {
            return http.Response.bytes(signaturePng(), 200);
          }
          if (request.url.path == ApiRoutes.myDay) {
            final day = todayVisits();
            final visit = (day['visits'] as List).first;
            visit['status'] = 'en_progreso';
            day['visits'] = [visit];
            return jsonResponse(day);
          }
          if (request.url.path == ApiRoutes.reportContext('visit-0')) {
            return jsonResponse(productsContext()..['report_id'] = 'report-1');
          }
          expect(request.url.path, ApiRoutes.completeReport('visit-0'));
          calls.add(request);
          if (calls.length == 1) throw http.ClientException('offline');
          return gate.future;
        },
      );
      // Open the existing flow with the native picker injected only for this test.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute<String>(
                      builder: (_) => ReportScreen(
                        service: dependencies.reportService!,
                        visitId: 'visit-0',
                        evidencePicker: picker,
                      ),
                    ),
                  )
                  .then((result) {
                    if (result == 'pendiente' && context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PaymentScreen(
                            service: dependencies.reportService!,
                            visitId: 'visit-0',
                            customerName: 'Cliente',
                          ),
                        ),
                      );
                    }
                  }),
              child: const Text('Abrir servicio'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir servicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await _settleEvidence(tester);
      await _press(tester, 'Tomar foto');
      expect(calls, isEmpty);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'Recomendaciones');
      await _signCustomer(tester);
      await tester.tap(find.text('Terminar servicio'));
      await tester.pumpAndSettle();
      final drafts = dependencies.reportService!.evidenceDrafts!;
      expect(
        (await drafts.load('test-user', 'visit-0', drafts.revision)).photos,
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar servicio'));
      await tester.pump();
      expect(calls, hasLength(2));
      for (final request in calls) {
        final body = latin1.decode(request.bodyBytes);
        expect(body, contains('name="photos"; filename='));
        expect(body, contains('\r\nvisit-0\r\n'));
        expect(body, isNot(contains('name="technician_signature"')));
      }
      expect(
        (await drafts.load('test-user', 'visit-0', drafts.revision)).photos,
        hasLength(1),
      );
      gate.complete(jsonResponse({'payment_status': 'pendiente'}, 201));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(
        (await drafts.load('test-user', 'visit-0', drafts.revision)).photos,
        isEmpty,
      );
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'Evidence controls remain scrollable without overflow at $size',
      (tester) async {
        await _open(tester, EvidenceTestPicker(), size: size);
        expect(find.text('Fotografías adicionales · 0/4'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Continuar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
