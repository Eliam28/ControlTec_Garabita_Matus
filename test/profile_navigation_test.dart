import 'dart:async';
import 'dart:ui' as ui;

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/main.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/models/signature_image.dart';
import 'package:controltec_app/screens/controllers/login_controller.dart';
import 'package:controltec_app/screens/controllers/profile_controller.dart';
import 'package:controltec_app/screens/home_screen.dart';
import 'package:controltec_app/screens/login_screen.dart';
import 'package:controltec_app/screens/profile_screen.dart';
import 'package:controltec_app/screens/signature_dialog.dart';
import 'package:controltec_app/theme/app_theme.dart';
import 'package:controltec_app/widgets/signature_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'support/login_test_support.dart';
import 'support/session_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storedTokens = AuthTokens(
    accessToken: 'saved-access',
    refreshToken: 'saved-refresh',
  );

  Future<void> settleImage(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  Future<ProfileController> openProfile(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request) handler,
    ImagePicker? picker,
    String name = 'Juan Pérez',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(494, 936);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = MemoryStore()..tokens = storedTokens;
    final dependencies = sessionDependencies(store: store, handler: handler);
    final authentication = LoginController(dependencies.loginService);
    addTearDown(authentication.dispose);
    await authentication.initialize();
    final controller = ProfileController(
      authentication: authentication,
      loginService: dependencies.loginService,
      profileService: dependencies.profileService!,
      myDayService: dependencies.myDayService,
      daySnapshot: dependencies.daySnapshot!,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(
          controller: controller,
          imagePicker: picker ?? TestImagePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('Tabs preserve My day and reuse its response for the profile', (
    tester,
  ) async {
    final store = MemoryStore()..tokens = storedTokens;
    int dayRequests = 0;
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async {
        if (request.url.path == ApiRoutes.me) {
          return jsonResponse({'user': mobileSession()['user']});
        }
        expect(request.url.path, ApiRoutes.myDay);
        dayRequests++;
        return jsonResponse(todayVisits());
      },
    );
    await tester.pumpWidget(MainApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    final homeState = tester.state(find.byType(HomeScreen));
    expect(dayRequests, 1);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await tester.tap(find.text('Reportes'));
    await tester.pumpAndSettle();
    expect(find.text('Trabajando en ella :)'), findsOneWidget);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('J'), findsOneWidget);
    expect(find.text('juan@example.com'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      2,
    );
    expect(dayRequests, 1);
    await tester.tap(find.text('Mi día'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(HomeScreen)), same(homeState));
    expect(dayRequests, 1);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .selectedItemColor,
      AppColors.primary,
    );
  });

  testWidgets(
    'Cancel logout keeps the session; confirmed offline logout clears all protected navigation',
    (tester) async {
      final store = MemoryStore()..tokens = storedTokens;
      int logouts = 0;
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          if (request.url.path == ApiRoutes.logout) {
            logouts++;
            throw http.ClientException('offline');
          }
          return jsonResponse(
            request.url.path == ApiRoutes.me
                ? {'user': mobileSession()['user']}
                : todayVisits(),
          );
        },
      );
      await tester.pumpWidget(MainApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Cerrar sesión'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(
        find.text('¿Estás seguro de que deseas cerrar sesión?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store.tokens, isNotNull);
      expect(logouts, 0);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(logouts, 1);
      expect(store.tokens, isNull);
      expect(dependencies.daySnapshot!.snapshot.value, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MainApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Signature pad starts empty, draws, clears and cancels without saving',
    (tester) async {
      int saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => SignatureDialog(
                    onSave: (_) async {
                      saves++;
                      return true;
                    },
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
            .onPressed,
        isNull,
      );
      await tester.drag(find.byType(SignaturePad), const Offset(50, 20));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Limpiar'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(SignatureDialog), findsNothing);
      expect(saves, 0);
    },
  );

  testWidgets(
    'A drawn signature exports transparent PNG instead of a white background',
    (tester) async {
      final pad = SignaturePadController();
      addTearDown(pad.dispose);
      pad.start(const Offset(50, 25), const Size(100, 40));
      pad.add(const Offset(75, 30), const Size(100, 40));
      final image = await tester.runAsync(() => pad.export());
      expect(image!.filename, 'firma.png');
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(image.bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1200);
        expect(frame.image.height, 480);
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(rgba!.getUint8(3), 0);
        frame.image.dispose();
        codec.dispose();
      });
    },
  );

  testWidgets(
    'Gallery preview can be cancelled and only reports success after the server confirms',
    (tester) async {
      final gate = Completer<http.Response>();
      int uploads = 0;
      bool signed = false;
      final controller = await openProfile(
        tester,
        handler: (request) async {
          if (request.url.path == ApiRoutes.signature) {
            uploads++;
            expect(request.method, 'PUT');
            expect(
              request.headers['Content-Type'],
              startsWith('multipart/form-data; boundary='),
            );
            expect(request.bodyBytes, isNotEmpty);
            expect(
              String.fromCharCodes(request.bodyBytes),
              contains('name="signature"'),
            );
            return gate.future;
          }
          if (request.url.path == ApiRoutes.signatureImage) {
            return http.Response.bytes(
              signaturePng(),
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          return jsonResponse(
            request.url.path == ApiRoutes.me
                ? {'user': mobileSession(hasSignature: signed)['user']}
                : todayVisits(),
          );
        },
        picker: TestImagePicker(
          selected: XFile.fromData(signaturePng(), name: 'foto.png'),
        ),
      );
      await tester.tap(find.text('Elegir una foto de mi firma'));
      await settleImage(tester);
      expect(find.byType(SignaturePhotoDialog), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(uploads, 0);
      await tester.tap(find.text('Elegir una foto de mi firma'));
      await settleImage(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pump();
      expect(uploads, 1);
      expect(find.text('Firma guardada correctamente'), findsNothing);
      final pendingSave = find.descendant(
        of: find.byType(SignaturePhotoDialog),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(pendingSave).onPressed, isNull);
      await tester.tap(pendingSave);
      await tester.pump();
      expect(uploads, 1);
      signed = true;
      gate.complete(jsonResponse(mobileSession(hasSignature: true)['user']!));
      await settleImage(tester);
      expect(find.byType(SignaturePhotoDialog), findsNothing);
      expect(controller.technician.hasSignature, isTrue);
      expect(controller.signature, orderedEquals(signaturePng()));
      expect(find.text('Firma guardada correctamente'), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, AppColors.success);
      expect(snack.duration, const Duration(seconds: 3));
    },
  );

  testWidgets(
    'A failed replacement keeps the previously registered signature',
    (tester) async {
      final controller = await openProfile(
        tester,
        handler: (request) async {
          if (request.url.path == ApiRoutes.signature) {
            return http.Response('', 500);
          }
          if (request.url.path == ApiRoutes.signatureImage) {
            return http.Response.bytes(signaturePng(), 200);
          }
          return jsonResponse(
            request.url.path == ApiRoutes.me
                ? {'user': mobileSession(hasSignature: true)['user']}
                : todayVisits(),
          );
        },
      );
      final before = controller.signature;
      expect(before, isNotNull);
      expect(
        await controller.save(
          SignatureImage(bytes: signaturePng(), filename: 'new.png'),
        ),
        isFalse,
      );
      expect(controller.signature, same(before));
      expect(controller.technician.hasSignature, isTrue);
      expect(controller.saveError, isNotNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('Profile and signature dialog remain scrollable at $size', (
      tester,
    ) async {
      await openProfile(
        tester,
        handler: (request) async => jsonResponse(
          request.url.path == ApiRoutes.me
              ? {'user': mobileSession()['user']}
              : todayVisits(),
        ),
      );
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Dibujar mi firma'));
      await tester.tap(find.text('Dibujar mi firma'));
      await tester.pumpAndSettle();
      expect(find.byType(SignatureDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });
  }
}

class TestImagePicker extends ImagePicker {
  TestImagePicker({this.selected});
  final XFile? selected;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    expect(requestFullMetadata, isFalse);
    return selected;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => LostDataResponse.empty();
}
