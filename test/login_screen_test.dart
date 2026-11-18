import 'package:controltec_app/api/services/mock_login_api.dart';
import 'package:controltec_app/api/services/login_service.dart';
import 'package:controltec_app/api/auth_messages.dart';
import 'package:controltec_app/main.dart';
import 'package:controltec_app/screens/home_screen.dart';
import 'package:controltec_app/screens/login_screen.dart';
import 'package:controltec_app/theme/app_theme.dart';
import 'package:controltec_app/widgets/login_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pending_login_api.dart';

void main() {
  Future<void> openLogin(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(494, 936);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = LoginService.mock(
      loginApi: const MockLoginApi(delay: Duration.zero),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(MainApp(loginService: service));
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(LoginButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  for (final data in [
    ('', '', AuthMessages.emptyFields),
    ('', 'secret', AuthMessages.emptyFields),
    ('tecnico@controltec.com', '', AuthMessages.emptyFields),
    ('incorrecto', 'secret', AuthMessages.invalidEmail),
    ('otro@controltec.com', 'Tecnico123', AuthMessages.invalidCredentials),
    ('tecnico@controltec.com', 'incorrecta', AuthMessages.invalidCredentials),
  ]) {
    testWidgets('Shows the requested error for ${data.$1}/${data.$2}', (
      tester,
    ) async {
      await openLogin(tester);
      await tester.enterText(find.byType(TextField).at(0), data.$1);
      await tester.enterText(find.byType(TextField).at(1), data.$2);
      await submit(tester);
      expect(find.text(data.$3), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.duration, const Duration(seconds: 3));
      expect(snack.backgroundColor, AppColors.error);
      expect(snack.behavior, SnackBarBehavior.floating);
      expect((snack.content as Text).style?.color, AppColors.white);
      final theme = Theme.of(tester.element(find.byType(LoginScreen)));
      expect(theme.snackBarTheme.shape, isA<RoundedRectangleBorder>());
    });
  }

  testWidgets(
    'Initial fields are empty, password hidden, button blue, no settings',
    (tester) async {
      await openLogin(tester);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.every((field) => field.controller!.text.isEmpty), isTrue);
      expect(fields.last.obscureText, isTrue);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
      final style = Theme.of(tester.element(find.byType(FilledButton)))
          .filledButtonTheme
          .style!;
      expect(style.backgroundColor!.resolve({}), AppColors.primary);
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        AppColors.primary,
      );
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets('The eye toggles visibility without changing the password', (
    tester,
  ) async {
    await openLogin(tester);
    await tester.enterText(find.byType(TextField).last, 'Mi contraseña');
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    var password = tester.widget<TextField>(find.byType(TextField).last);
    expect(password.obscureText, isFalse);
    expect(password.controller!.text, 'Mi contraseña');
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();
    password = tester.widget<TextField>(find.byType(TextField).last);
    expect(password.obscureText, isTrue);
    expect(password.controller!.text, 'Mi contraseña');
  });

  testWidgets(
    'Recovery replaces the previous error and disappears after three seconds',
    (tester) async {
      await openLogin(tester);
      await submit(tester);
      await tester.tap(find.text('Olvidé mi contraseña'));
      await tester.pumpAndSettle();
      expect(find.text(AuthMessages.emptyFields), findsNothing);
      expect(find.text(AuthMessages.passwordRecovery), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, AppColors.warning);
      expect((snack.content as Text).style!.color, AppColors.warningText);
      expect(snack.duration, const Duration(seconds: 3));
      expect(snack.behavior, SnackBarBehavior.floating);
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.text(AuthMessages.passwordRecovery), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 401));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('Repeated errors replace rather than queue SnackBars', (
    tester,
  ) async {
    await openLogin(tester);
    await submit(tester);
    await submit(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'Correct mock credentials open the main screen and remove the login route',
    (tester) async {
      await openLogin(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'tecnico@controltec.com',
      );
      await tester.enterText(find.byType(TextField).last, 'Tecnico123');
      await submit(tester);
      expect(find.text('Mis servicios de hoy'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      final context = tester.element(find.byType(HomeScreen));
      expect(Navigator.of(context).canPop(), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Pending login stays blue, disables input and blocks repeated submission',
    (tester) async {
      await openLogin(tester);
      final api = PendingLoginApi();
      final service = LoginService.mock(loginApi: api);
      await tester.pumpWidget(MainApp(key: UniqueKey(), loginService: service));
      await tester.enterText(
        find.byType(TextField).first,
        'tecnico@controltec.com',
      );
      await tester.enterText(find.byType(TextField).last, 'Tecnico123');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => !field.enabled!),
        isTrue,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(api.calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      api.result.complete(mockResponse);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366),
  ]) {
    testWidgets(
      'Layout scrolls without overflow at $size and with a keyboard',
      (tester) async {
        await openLogin(tester);
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(
          find.byType(TextField).first,
          'tecnico@controltec.com',
        );
        await tester.enterText(find.byType(TextField).last, 'incorrecta');
        await submit(tester);
        expect(find.text(AuthMessages.invalidCredentials), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Large accessibility text remains scrollable', (tester) async {
    await openLogin(tester);
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await submit(tester);
    expect(find.text(AuthMessages.emptyFields), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
