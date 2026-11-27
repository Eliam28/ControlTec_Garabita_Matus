import 'dart:convert';
import 'dart:io';

import 'package:controltec_app/api/api_routes.dart';
import 'package:controltec_app/api/services/evidence_draft_store.dart';
import 'package:controltec_app/api/services/report_evidence_service.dart';
import 'package:controltec_app/base/custom_exception.dart';
import 'package:controltec_app/models/auth_tokens.dart';
import 'package:controltec_app/models/report_context.dart';
import 'package:controltec_app/models/report_evidence.dart';
import 'package:controltec_app/screens/controllers/report_evidence_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'support/evidence_test_support.dart';
import 'support/login_test_support.dart';
import 'support/products_test_support.dart';
import 'support/session_test_support.dart';

const tokens = AuthTokens(
  accessToken: 'saved-access',
  refreshToken: 'saved-refresh',
);
EvidencePhoto _photo(int i) =>
    EvidencePhoto(id: 'photo-$i', bytes: evidencePng(i), mimeType: 'image/png');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Station metadata includes inspection images and deduplicates the evidence table without inventing IDs', () async {
    final json = productsContext(withStation: true);
    json['report_id'] = 'report-1';
    ((json['stations'] as List).single['inspection'] as Map)['photo_path'] =
        'report-1/station.png';
    json['evidence'] = [
      {
        'id': 'evidence-1',
        'photo_path': 'report-1/station.png',
        'station_code': 'CB-001',
      },
      {
        'id': 'evidence-2',
        'photo_path': 'report-1/general.png',
        'station_code': null,
      },
    ];
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = tokens,
      handler: (_) async => jsonResponse(mobileSession()['user']!),
    );
    final controller = ReportEvidenceController(
      visitId: 'visit-0',
      service: dependencies.reportService!,
    );
    addTearDown(controller.dispose);
    controller.acceptContext(ReportContext.fromJson(json));
    expect(controller.reportId, 'report-1');
    expect(controller.stationPhotos.single.stationCode, 'CB-001');
    expect(controller.savedPhotos.single.id, 'evidence-2');
    expect(controller.additionalCount, 1);
  });

  test('Camera and gallery combine to four private copies without any completion request', () async {
    final picker = EvidenceTestPicker()
      ..camera = evidenceFile(1)
      ..gallery = [evidenceFile(2), evidenceFile(3), evidenceFile(4)];
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = tokens,
      handler: (request) async {
        expect(request.url.path, ApiRoutes.profile);
        return jsonResponse(mobileSession()['user']!);
      },
    );
    final controller = ReportEvidenceController(
      visitId: 'visit-0',
      service: dependencies.reportService!,
      picker: picker,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.pick(camera: true);
    await controller.pick(camera: false);
    expect(controller.photos, hasLength(4));
    expect(picker.requestedLimit, 3);
    expect(controller.photos.first.bytes, orderedEquals(evidencePng(1)));
    await expectLater(
      controller.pick(camera: true),
      throwsA(isA<CustomException>()),
    );
    expect(picker.cameraCalls, 1);
    await controller.remove(controller.photos[1]);
    expect(controller.additionalCount, 3);
    expect(controller.photos.map((p) => p.bytes.last), [1, 3, 4]);
    final recovered = ReportEvidenceController(
      visitId: 'visit-0',
      service: dependencies.reportService!,
      picker: picker,
    );
    addTearDown(recovered.dispose);
    await recovered.initialize();
    expect(recovered.photos.map((p) => p.bytes.last), [1, 3, 4]);
  });

  test('Cancelled, duplicate, over-limit, invalid and oversized files never corrupt previous photos', () async {
    final picker = EvidenceTestPicker();
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = tokens,
      handler: (_) async => jsonResponse(mobileSession()['user']!),
    );
    final controller = ReportEvidenceController(
      visitId: 'visit-0',
      service: dependencies.reportService!,
      picker: picker,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.pick(camera: true);
    expect(controller.photos, isEmpty);
    picker.camera = evidenceFile(1);
    await controller.pick(camera: true);
    await controller.pick(camera: true);
    expect(controller.photos, hasLength(1));
    picker.gallery = [for (var i = 2; i <= 5; i++) evidenceFile(i)];
    await expectLater(
      controller.pick(camera: false),
      throwsA(isA<CustomException>()),
    );
    expect(controller.photos, hasLength(1));
    picker.gallery = [
      XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'broken.png'),
    ];
    await expectLater(
      controller.pick(camera: false),
      throwsA(isA<CustomException>()),
    );
    picker.gallery = [
      XFile.fromData(Uint8List(EvidencePhoto.maxBytes + 1), name: 'big.jpg'),
    ];
    await expectLater(
      controller.pick(camera: false),
      throwsA(isA<CustomException>()),
    );
    expect(controller.photos, hasLength(1));
    picker.failure = PlatformException(code: 'camera_access_denied');
    await expectLater(
      controller.pick(camera: true),
      throwsA(
        isA<CustomException>().having(
          (e) => e.message,
          'message',
          contains('Permite el acceso'),
        ),
      ),
    );
    expect(controller.busy, isFalse);
  });

  test('File drafts survive reconstruction and remain isolated by technician and visit', () async {
    final root = await Directory.systemTemp.createTemp(
      'controltec-evidence-test-',
    );
    addTearDown(() => root.delete(recursive: true));
    final store = FileEvidenceDraftStore(directory: () async => root);
    await store.save(
      'tech-1',
      'visit-1',
      [_photo(1), _photo(2)],
      store.revision,
      pickerPending: true,
    );
    final reopened = FileEvidenceDraftStore(directory: () async => root);
    final draft = await reopened.load('tech-1', 'visit-1', reopened.revision);
    expect(draft.pickerPending, isTrue);
    expect(await reopened.hasPendingPicker('tech-1'), isTrue);
    expect(await reopened.hasPendingPicker('tech-2'), isFalse);
    expect(draft.photos.last.bytes, orderedEquals(evidencePng(2)));
    expect(
      (await reopened.load('tech-2', 'visit-1', reopened.revision)).photos,
      isEmpty,
    );
    expect(
      (await reopened.load('tech-1', 'visit-2', reopened.revision)).photos,
      isEmpty,
    );
    await reopened.remove('tech-1', 'visit-1', reopened.revision);
    expect(
      (await reopened.load('tech-1', 'visit-1', reopened.revision)).photos,
      isEmpty,
    );
    expect(await reopened.hasPendingPicker('tech-1'), isFalse);
  });

  test(
    'Logout invalidates late draft writes and removes private copies',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'controltec-evidence-logout-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final store = FileEvidenceDraftStore(directory: () async => root);
      final revision = store.revision;
      await store.save('tech-1', 'visit-1', [_photo(1)], revision);
      await store.clearAll();
      await expectLater(
        store.save('tech-1', 'visit-1', [_photo(2)], revision),
        throwsA(isA<CustomException>()),
      );
      expect(
        (await store.load('tech-1', 'visit-1', store.revision)).photos,
        isEmpty,
      );
    },
  );

  test(
    'Corrupted drafts are reported rather than silently discarded',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'controltec-evidence-corrupt-',
      );
      addTearDown(() => root.delete(recursive: true));
      final store = FileEvidenceDraftStore(directory: () async => root);
      await store.save('tech-1', 'visit-1', [_photo(1)], 0);
      await File('${root.path}/tech-1/visit-1.json').writeAsString('invalid');
      await expectLater(
        store.load('tech-1', 'visit-1', 0),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('Android recovers only a picker operation marked for this report and keeps earlier photos', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final picker = EvidenceTestPicker()
      ..lostData = LostDataResponse(
        files: [evidenceFile(2)],
        type: RetrieveType.image,
      );
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = tokens,
      handler: (_) async => jsonResponse(mobileSession()['user']!),
    );
    final store = dependencies.reportService!.evidenceDrafts!;
    await store.save(
      'test-user',
      'visit-0',
      [_photo(1)],
      store.revision,
      pickerPending: true,
    );
    final controller = ReportEvidenceController(
      visitId: 'visit-0',
      service: dependencies.reportService!,
      picker: picker,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.photos.map((p) => p.bytes.last), [1, 2]);
    expect(
      (await store.load('test-user', 'visit-0', store.revision)).pickerPending,
      isFalse,
    );
  });

  test('Application logout cleanup removes drafts and prevents an old controller from restoring them', () async {
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = tokens,
      handler: (_) async => jsonResponse(mobileSession()['user']!),
    );
    final controller = ReportEvidenceController(
      visitId: 'visit-0',
      service: dependencies.reportService!,
      picker: EvidenceTestPicker()..camera = evidenceFile(1),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.pick(camera: true);
    dependencies.clearSessionData();
    await controller.pick(camera: true);
    final store = dependencies.reportService!.evidenceDrafts!;
    expect(
      (await store.load('test-user', 'visit-0', store.revision)).photos,
      isEmpty,
    );
  });

  test('A context confirming the report was closed clears its remaining local draft without another completion', () async {
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = tokens,
      handler: (request) async {
        expect(request.url.path, ApiRoutes.profile);
        return jsonResponse(mobileSession()['user']!);
      },
    );
    final controller = ReportEvidenceController(
      visitId: 'visit-0',
      service: dependencies.reportService!,
      picker: EvidenceTestPicker()..camera = evidenceFile(1),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.pick(camera: true);
    controller.acceptContext(
      ReportContext.fromJson(
        productsContext()..['visit_status'] = 'completado',
      ),
    );
    final store = dependencies.reportService!.evidenceDrafts!;
    expect(controller.photos, isEmpty);
    expect(controller.closed, isTrue);
    expect(controller.beginCompletion(), isFalse);
    expect(
      (await store.load('test-user', 'visit-0', store.revision)).photos,
      isEmpty,
    );
  });

  test(
    'Authorized file proxy uses report_id and refreshes the shared token once',
    () async {
      int refreshes = 0;
      final dependencies = sessionDependencies(
        store: MemoryStore()..tokens = tokens,
        handler: (request) async {
          if (request.url.path == ApiRoutes.refresh) {
            refreshes++;
            return jsonResponse(mobileSession());
          }
          expect(
            request.url.path,
            ApiRoutes.reportFile('report-1', 'station.png'),
          );
          if (request.headers['Authorization'] == 'Bearer saved-access') {
            return jsonResponse({}, 401);
          }
          return http.Response.bytes(evidencePng(1), 200);
        },
      );
      final bytes = await ReportEvidenceService(dependencies.reportService!)
          .execute((
            reportId: 'report-1',
            photoPath: 'private/report-1/station.png',
          ));
      expect(bytes, orderedEquals(evidencePng(1)));
      expect(refreshes, 1);
    },
  );

  test(
    'Remote URLs and traversal paths never receive authentication credentials',
    () async {
      final dependencies = sessionDependencies(
        store: MemoryStore()..tokens = tokens,
        handler: (_) async {
          fail('Unexpected HTTP request');
        },
      );
      final service = ReportEvidenceService(dependencies.reportService!);
      for (final path in [
        'https://evil.test/p.png',
        '//evil.test/p.png',
        '../p.png',
        'report-1/%2Fescape.png',
      ]) {
        await expectLater(
          service.execute((reportId: 'report-1', photoPath: path)),
          throwsA(isA<CustomException>()),
        );
      }
    },
  );

  test('The existing completion uploads repeated photos fields and preserves both signatures, fields and payment status', () async {
    final dependencies = sessionDependencies(
      store: MemoryStore()..tokens = tokens,
      handler: (request) async {
        expect(request.url.path, ApiRoutes.completeReport('visit-0'));
        expect(request.method, 'POST');
        final body = latin1.decode(request.bodyBytes);
        expect(
          RegExp('name="photos"; filename=').allMatches(body),
          hasLength(2),
        );
        expect(body, contains('name="signature"'));
        expect(body, contains('name="technician_signature"'));
        expect(body, contains('name="client_key"'));
        expect(body.toLowerCase(), contains('content-type: image/png'));
        return jsonResponse({'payment_status': 'pendiente'}, 201);
      },
    );
    final status = await dependencies.reportService!.complete(
      visitId: 'visit-0',
      receivedBy: 'Cliente',
      amount: '100',
      recommendations: 'Recomendaciones',
      notes: 'Notas',
      signature: signaturePng(),
      technicianSignature: signaturePng(),
      photos: [_photo(1), _photo(2)],
      clientKey: 'stable-key',
    );
    expect(status, 'pendiente');
  });
}
