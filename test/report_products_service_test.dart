import 'dart:async';
import 'dart:convert';

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/api/services/report_products_service.dart';
import 'package:controltec_app/base/custom_exception.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/models/report_context.dart';
import 'package:controltec_app/models/report_product.dart';
import 'package:controltec_app/screens/validators/product_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/login_test_support.dart';
import 'support/products_test_support.dart';
import 'support/session_test_support.dart';

const _tokens = AuthTokens(
  accessToken: 'saved-access',
  refreshToken: 'saved-refresh',
);
ProductAddition _addition() => ProductAddition(
  visitId: 'visit-0',
  application: const ProductApplication(
    productId: 'product-1',
    area: 'Cocina',
    technique: ApplicationTechnique.aspersion,
    extraInfo: 'Aplicación de prueba',
  ),
);

void main() {
  test('Context reads the real catalog, applied rows and dose without altering station parsing', () {
    final report = ReportContext.fromJson(
      productsContext(products: [appliedProduct()], withStation: true),
    );
    expect(report.productOptions.single.recommendedDose, '10 ml/L');
    expect(report.products.single.productId, 'product-1');
    expect(report.products.single.appliedDose, '10 ml/L');
    expect(report.doneStations, 1);
    expect(report.stations.single.notes, 'Inspección existente');
  });

  test('Validation requires product, area, one technique and observations; dose belongs to catalog', () {
    const product = CatalogProduct(id: 'product-1', name: 'Producto');
    String? validate({
      CatalogProduct? selected = product,
      String area = 'Cocina',
      ApplicationTechnique? technique = ApplicationTechnique.aspersion,
      String info = 'Aplicado',
    }) => ProductValidator.validate(
      product: selected,
      area: area,
      technique: technique,
      extraInfo: info,
    );
    expect(validate(selected: null), 'Seleccione un producto del catálogo');
    expect(validate(area: '  '), 'Complete todos los campos obligatorios');
    expect(validate(technique: null), 'Complete todos los campos obligatorios');
    expect(validate(info: '  '), 'Complete todos los campos obligatorios');
    expect(validate(area: 'a' * 201), isNotNull);
    expect(validate(info: 'a' * 1001), isNotNull);
    expect(validate(), isNull);
    expect(ApplicationTechnique.values.map((t) => t.name), [
      'aspersion',
      'termonebulizacion',
      'micronizacion',
      'inyeccion',
      'monitoreo',
      'espolvoreo',
    ]);
  });

  test('Replacing PUT reads fresh rows and retains every existing product and field', () async {
    final existing = [
      appliedProduct(
        id: 'other',
        productId: 'other-product',
        area: 'Almacén',
        technique: 'monitoreo',
        info: 'Registro previo',
      ),
    ];
    final store = MemoryStore()..tokens = _tokens;
    int reads = 0;
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async {
        expect(request.headers['Authorization'], 'Bearer saved-access');
        if (request.url.path == ApiRoutes.reportContext('visit-0')) {
          reads++;
          return jsonResponse(productsContext(products: existing));
        }
        expect(request.url.path, ApiRoutes.reportProducts('visit-0'));
        expect(request.method, 'PUT');
        expect(request.headers['Content-Type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, ['products']);
        final submitted = body['products'] as List;
        expect(submitted, hasLength(2));
        expect(submitted.first, {
          'product_id': 'other-product',
          'area': 'Almacén',
          'technique': 'monitoreo',
          'applied_dose': '10 ml/L',
          'extra_info': 'Registro previo',
        });
        expect(submitted.last, {
          'product_id': 'product-1',
          'area': 'Cocina',
          'technique': 'aspersion',
          'extra_info': 'Aplicación de prueba',
        });
        return jsonResponse(savedProductResponse(submitted));
      },
    );
    final result = await ReportProductsService(dependencies.reportService!)
        .execute(_addition());
    expect(reads, 1);
    expect(result, hasLength(2));
    expect(result.last.appliedDose, '10 ml/L');
  });

  test('A lost successful response is confirmed by GET on retry without adding twice', () async {
    final store = MemoryStore()..tokens = _tokens;
    List<Map<String, dynamic>> saved = [];
    int writes = 0;
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async {
        if (request.method == 'GET') {
          return jsonResponse(productsContext(products: saved));
        }
        writes++;
        saved = savedProductResponse(
          jsonDecode(request.body)['products'] as List,
        );
        throw http.ClientException('lost response');
      },
    );
    final service = ReportProductsService(dependencies.reportService!);
    final addition = _addition();
    await expectLater(
      service.execute(addition),
      throwsA(isA<CustomException>()),
    );
    expect(store.tokens, same(_tokens));
    final restored = await service.execute(addition);
    expect(restored, hasLength(1));
    expect(writes, 1);
  });

  test('Distinct confirmed additions may intentionally use the same product and preserve multiplicity', () async {
    final store = MemoryStore()..tokens = _tokens;
    List<Map<String, dynamic>> saved = [];
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async {
        if (request.method == 'GET') {
          return jsonResponse(productsContext(products: saved));
        }
        saved = savedProductResponse(
          jsonDecode(request.body)['products'] as List,
        );
        return jsonResponse(saved);
      },
    );
    final service = ReportProductsService(dependencies.reportService!);
    await service.execute(_addition());
    expect(await service.execute(_addition()), hasLength(2));
    expect(await service.load('visit-0').then((r) => r.products), hasLength(2));
  });

  test('Products use the shared refresh and retry the identical replacing JSON once', () async {
    final store = MemoryStore()..tokens = _tokens;
    int refreshes = 0;
    final writes = <String>[];
    final dependencies = sessionDependencies(
      store: store,
      handler: (request) async {
        if (request.url.path == ApiRoutes.refresh) {
          refreshes++;
          return jsonResponse(mobileSession());
        }
        if (request.method == 'GET') return jsonResponse(productsContext());
        writes.add(request.body);
        if (writes.length == 1) return jsonResponse({'detail': 'expired'}, 401);
        expect(request.headers['Authorization'], 'Bearer test-only-access');
        return jsonResponse(
          savedProductResponse(jsonDecode(request.body)['products'] as List),
        );
      },
    );
    final result = await ReportProductsService(dependencies.reportService!)
        .execute(_addition());
    expect(result, hasLength(1));
    expect(refreshes, 1);
    expect(writes, hasLength(2));
    expect(writes.first, writes.last);
  });

  test(
    'Legacy rows with no accepted technique block a destructive replacement',
    () async {
      final store = MemoryStore()..tokens = _tokens;
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          expect(request.method, 'GET');
          return jsonResponse(
            productsContext(products: [appliedProduct(technique: null)]),
          );
        },
      );
      await expectLater(
        ReportProductsService(dependencies.reportService!).execute(_addition()),
        throwsA(
          isA<CustomException>().having(
            (e) => e.code,
            'code',
            'legacy_product',
          ),
        ),
      );
    },
  );

  for (final status in [400, 403, 404, 409, 415, 422, 429, 500]) {
    test(
      'HTTP $status produces a safe error instead of exposing a server exception',
      () async {
        final store = MemoryStore()..tokens = _tokens;
        final dependencies = sessionDependencies(
          store: store,
          handler: (request) async => request.method == 'GET'
              ? jsonResponse(productsContext())
              : jsonResponse({'detail': 'INTERNAL SQL PRIVATE TRACE'}, status),
        );
        await expectLater(
          ReportProductsService(dependencies.reportService!)
              .execute(_addition()),
          throwsA(
            isA<CustomException>().having(
              (e) => e.message,
              'safe message',
              isNot(contains('PRIVATE')),
            ),
          ),
        );
      },
    );
  }

  test(
    'Timeout and malformed confirmations never count as a successful addition',
    () async {
      final store = MemoryStore()..tokens = _tokens;
      bool timeout = true;
      final dependencies = sessionDependencies(
        store: store,
        handler: (request) async {
          if (request.method == 'GET') return jsonResponse(productsContext());
          if (timeout) throw TimeoutException('test');
          return jsonResponse([]);
        },
      );
      final service = ReportProductsService(dependencies.reportService!);
      await expectLater(
        service.execute(_addition()),
        throwsA(isA<CustomException>()),
      );
      timeout = false;
      await expectLater(
        service.execute(_addition()),
        throwsA(isA<CustomException>()),
      );
      expect(store.tokens, isNotNull);
    },
  );
}
