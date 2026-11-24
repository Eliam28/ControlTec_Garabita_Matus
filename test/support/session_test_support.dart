import 'dart:convert';
import 'dart:typed_data';

import 'package:controltec_app/api/app_config.dart';
import 'package:controltec_app/api/app_dependencies.dart';
import 'package:controltec_app/api/services/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'login_test_support.dart';

Uint8List signaturePng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAABCAYAAAD5PA/NAAAADklEQVR4nGMQUDD4j4wBKPUFfT1eD/QAAAAASUVORK5CYII=',
);

Map<String, dynamic> mobileSession({
  String name = 'Juan Pérez',
  bool hasSignature = false,
}) {
  final result = sessionJson();
  (result['user'] as Map<String, dynamic>).addAll({
    'full_name': name,
    'email': 'juan@example.com',
    'has_signature': hasSignature,
  });
  return result;
}

Map<String, dynamic> todayVisits() => {
  'date': DateTime.now().toIso8601String().substring(0, 10),
  'visits': [
    for (int i = 0; i < 3; i++)
      {
        'id': 'visit-$i',
        'customer_id': 'customer-$i',
        'location_id': 'location-$i',
        'service_id': 'service-$i',
        'status': i < 2 ? 'completado' : 'programado',
        'scheduled_date': DateTime.now().toIso8601String().substring(0, 10),
        'scheduled_time_start': '09:00:00',
        'scheduled_time_end': '10:00:00',
        'customer_name': 'Cliente de prueba $i',
        'service_name': 'Servicio de prueba',
        'location_address': 'Dirección de prueba',
      },
  ],
};

AppDependencies sessionDependencies({
  required Future<http.Response> Function(http.Request) handler,
  TokenStore? store,
}) {
  final dependencies = AppDependencies.fromConfig(
    const AppConfig(apiBaseUrl: 'https://example.com'),
    client: MockClient(handler),
    tokenStore: store ?? MemoryStore(),
  );
  addTearDown(dependencies.dispose);
  return dependencies;
}
