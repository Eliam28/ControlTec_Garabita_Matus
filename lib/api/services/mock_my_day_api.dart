import 'dart:convert';

import '../../base/handler.dart';

/// Datos ficticios con la misma forma que responde GET /scheduling/my-day.
/// Se usa mientras se desarrolla, sin conexión a la API.
class MockMyDayApi implements Handler<void, String> {
  const MockMyDayApi();

  @override
  Future<String> execute(void input) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return jsonEncode({
      'date': today,
      'visits': [
        {
          'id': 'visita-1',
          'status': 'completado',
          'scheduled_time_start': '09:00:00',
          'scheduled_time_end': '09:45:00',
          'customer_name': 'Panadería El Trigo',
          'service_name': 'Control de roedores',
          'location_address': 'Calle Inventada 12, Col. Centro, Mérida',
          'notes': 'Revisar los 3 cebaderos.',
        },
        {
          'id': 'visita-2',
          'status': 'en_progreso',
          'scheduled_time_start': '11:00:00',
          'scheduled_time_end': '12:00:00',
          'customer_name': 'Jorge Ramírez',
          'service_name': 'Fumigación general',
          'location_address': 'Calle 00 #123, Col. Ejemplo, Mérida',
          'notes': 'Tocar el timbre dos veces.',
        },
        {
          'id': 'visita-3',
          'status': 'programado',
          'scheduled_time_start': '15:00:00',
          'scheduled_time_end': '15:40:00',
          'customer_name': 'Hotel Brisa',
          'service_name': 'Control de rastreros',
          'location_address': 'Av. Imaginaria 450, Col. Playa, Mérida',
        },
        {
          'id': 'visita-4',
          'status': 'programado',
          'scheduled_time_start': '17:00:00',
          'scheduled_time_end': '17:45:00',
          'customer_name': 'Bodegas del Sur',
          'service_name': 'Control de roedores',
          'location_address': 'Carretera Ficticia km 3, Mérida',
        },
      ],
    });
  }
}
