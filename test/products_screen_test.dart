import 'dart:async';
import 'dart:convert';

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/api/app_dependencies.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/main.dart';
import 'package:controltec_app/screens/payment_screen.dart';
import 'package:controltec_app/screens/applied_products_tab.dart';
import 'package:controltec_app/screens/product_application_screen.dart';
import 'package:controltec_app/screens/report_screen.dart';
import 'package:controltec_app/screens/signoff_tab.dart';
import 'package:controltec_app/screens/station_screen.dart';
import 'package:controltec_app/theme/app_theme.dart';
import 'package:controltec_app/widgets/applied_product_card.dart';
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
      return handler != null
          ? handler(request)
          : jsonResponse(productsContext(withStation: true));
    },
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ReportScreen(
        service: dependencies.reportService!,
        visitId: 'visit-0',
      ),
    ),
  );
  await tester.pumpAndSettle();
  return dependencies;
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Agregar producto'),
    100,
    scrollable: find
        .descendant(
          of: find.byType(AppliedProductsTab),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(find.text('Agregar producto'));
  await tester.pumpAndSettle();
}

Future<void> _selectProduct(WidgetTester tester) async {
  await tester.tap(find.text('Elige del catálogo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Producto de prueba'));
  await tester.pumpAndSettle();
}

Future<void> _complete(WidgetTester tester) async {
  await _selectProduct(tester);
  await tester.enterText(find.byType(TextField).at(0), 'Cocina');
  await tester.tap(find.text('Aspersión'));
  await tester.enterText(find.byType(TextField).at(2), 'Aplicación de prueba');
}

void main() {
  testWidgets(
    'Completing the existing signature still opens payment for the same visit',
    (tester) async {
      final dependencies = sessionDependencies(
        store: MemoryStore()..tokens = _tokens,
        handler: (request) async {
          if (request.url.path == ApiRoutes.profile) {
            return jsonResponse(mobileSession()['user']!);
          }
          if (request.url.path == ApiRoutes.me) {
            return jsonResponse({'user': mobileSession()['user']});
          }
          if (request.url.path == ApiRoutes.myDay) {
            final day = todayVisits();
            final visit = (day['visits'] as List).first as Map<String, dynamic>;
            visit['status'] = 'programado';
            day['visits'] = [visit];
            return jsonResponse(day);
          }
          if (request.url.path == ApiRoutes.startReport('visit-0')) {
            return jsonResponse({});
          }
          expect(request.url.path, ApiRoutes.reportContext('visit-0'));
          return jsonResponse(productsContext());
        },
      );
      await tester.pumpWidget(MainApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar servicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final signoff = tester.widget<SignoffTab>(find.byType(SignoffTab));
      expect(signoff.report.visitId, 'visit-0');
      signoff.onCompleted('pendiente');
      await tester.pumpAndSettle();
      expect(
        tester.widget<PaymentScreen>(find.byType(PaymentScreen)).visitId,
        'visit-0',
      );
    },
  );

  testWidgets('Large accessibility text keeps the form scrollable', (
    tester,
  ) async {
    await _open(tester, size: const Size(320, 568));
    await _openForm(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final observations = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.maxLines == 5,
    );
    await tester.scrollUntilVisible(
      observations,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ProductApplicationScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(observations, 'Información accesible');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Agregar'), findsOneWidget);
  });

  testWidgets(
    'Stations, empty products and signature retain their state with the same visit',
    (tester) async {
      int contexts = 0;
      await _open(
        tester,
        handler: (request) async {
          expect(request.url.path, ApiRoutes.reportContext('visit-0'));
          contexts++;
          return jsonResponse(productsContext(withStation: true));
        },
      );
      expect(find.text('1 de 1'), findsOneWidget);
      await tester.tap(find.text('CB-001'));
      await tester.pumpAndSettle();
      expect(find.byType(StationScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Sin productos aplicados'), findsOneWidget);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      final reads = contexts;
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(ProductApplicationScreen), findsNothing);
      expect(contexts, reads);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(SignoffTab), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Nombre conservado');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Sin productos aplicados'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Nombre conservado'), findsOneWidget);
      await tester.tap(find.text('Aplicación'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('1 de 1'), findsOneWidget);
      expect(contexts, reads);
    },
  );

  testWidgets(
    'Add stays blue and validates only on tap with red floating three second messages',
    (tester) async {
      await _open(tester);
      await _openForm(tester);
      final button = find.widgetWithText(FilledButton, 'Agregar');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      final style = FilledButtonTheme.of(tester.element(button)).style!;
      expect(style.backgroundColor!.resolve({}), AppColors.primary);
      expect(
        tester.widget<FilledButton>(button).style!.backgroundColor!.resolve({
          WidgetState.disabled,
        }),
        AppColors.primary,
      );
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .where((chip) => chip.selected),
        isEmpty,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Seleccione un producto del catálogo'), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.duration, const Duration(seconds: 3));
      expect(snack.backgroundColor, AppColors.error);
      expect(snack.behavior, SnackBarBehavior.floating);
      await _selectProduct(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).readOnly,
        isTrue,
      );
      expect(find.text('10 ml/L'), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text('Complete todos los campos obligatorios'),
        findsOneWidget,
      );
      expect(find.byType(ProductApplicationScreen), findsOneWidget);
    },
  );

  testWidgets('Dirty form requires an explicit discard and sends no products', (
    tester,
  ) async {
    await _open(
      tester,
      handler: (request) async {
        expect(request.method, 'GET');
        return jsonResponse(productsContext());
      },
    );
    await _openForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Borrador');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar producto?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Borrador'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductApplicationScreen), findsNothing);
    expect(find.text('Sin productos aplicados'), findsOneWidget);
  });

  testWidgets(
    'Only confirmed saves close the form and update all products, including after reopening',
    (tester) async {
      final gate = Completer<http.Response>();
      List<Map<String, dynamic>> saved = [
        appliedProduct(id: 'previous', area: 'Almacén'),
      ];
      int writes = 0;
      final dependencies = await _open(
        tester,
        handler: (request) async {
          if (request.method == 'GET') {
            return jsonResponse(productsContext(products: saved));
          }
          writes++;
          saved = savedProductResponse(
            jsonDecode(request.body)['products'] as List,
          );
          return gate.future;
        },
      );
      await _openForm(tester);
      await _complete(tester);
      await tester.tap(find.text('Agregar'));
      await tester.pump();
      expect(writes, 1);
      expect(find.text('Producto agregado correctamente'), findsNothing);
      final pendingButton = find.descendant(
        of: find.byType(ProductApplicationScreen),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(pendingButton).onPressed, isNull);
      await tester.tap(pendingButton);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ProductApplicationScreen), findsOneWidget);
      expect(writes, 1);
      gate.complete(jsonResponse(saved));
      await tester.pumpAndSettle();
      expect(find.byType(ProductApplicationScreen), findsNothing);
      expect(find.byType(AppliedProductCard), findsNWidgets(2));
      expect(find.text('Producto agregado correctamente'), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, AppColors.success);
      expect(snack.duration, const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ReportScreen(
            service: dependencies.reportService!,
            visitId: 'visit-0',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(AppliedProductCard), findsNWidgets(2));
      expect(writes, 1);
    },
  );

  testWidgets(
    'Failed save preserves draft fields and previous products for retry',
    (tester) async {
      int writes = 0;
      await _open(
        tester,
        handler: (request) async {
          if (request.method == 'GET') {
            return jsonResponse(
              productsContext(products: [appliedProduct(area: 'Almacén')]),
            );
          }
          writes++;
          return jsonResponse({'detail': 'private SQL exception'}, 500);
        },
      );
      await _openForm(tester);
      await _complete(tester);
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductApplicationScreen), findsOneWidget);
      expect(find.text('Cocina'), findsOneWidget);
      expect(find.text('Aplicación de prueba'), findsOneWidget);
      expect(find.textContaining('private SQL'), findsNothing);
      expect(find.text('Producto agregado correctamente'), findsNothing);
      expect(writes, 1);
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      expect(writes, 2);
    },
  );

  testWidgets(
    'Empty catalog can recover through retry without inventing a product',
    (tester) async {
      bool available = false;
      await _open(
        tester,
        handler: (request) async => jsonResponse(
          productsContext(options: available ? [catalogProduct()] : []),
        ),
      );
      await _openForm(tester);
      expect(
        find.text('No hay productos disponibles en el catálogo'),
        findsOneWidget,
      );
      available = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      await _selectProduct(tester);
      expect(find.text('10 ml/L'), findsOneWidget);
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('Products and form scroll with keyboard at $size', (
      tester,
    ) async {
      await _open(tester, size: size);
      await _openForm(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 170);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final add = find.widgetWithText(FilledButton, 'Agregar');
      expect(
        tester.getBottomRight(add).dy,
        lessThanOrEqualTo(size.height - 170),
      );
      final observations = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.maxLines == 5,
      );
      await tester.scrollUntilVisible(
        observations,
        100,
        scrollable: find
            .descendant(
              of: find.byType(ProductApplicationScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(observations, 'Observaciones visibles');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Observaciones visibles'), findsOneWidget);
    });
  }
}
