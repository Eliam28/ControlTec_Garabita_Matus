import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../base/custom_exception.dart';
import '../../models/report_context.dart';
import '../api_routes.dart';
import '../auth_messages.dart';
import 'token_store.dart';

/// Todas las peticiones del reporte de un servicio:
/// iniciar, leer, guardar estaciones, firmar y declarar el pago.
class ReportService {
  const ReportService({
    required this.httpClient,
    required this.baseUrl,
    required this.tokenStore,
  });

  final http.Client httpClient;
  final String baseUrl;
  final TokenStore tokenStore;

  /// El servicio pasa de Programado a En progreso.
  Future<void> start(String visitId) =>
      _send(http.Request('POST', _uri(ApiRoutes.startReport(visitId))));

  Future<ReportContext> load(String visitId) async {
    final body = await _send(
      http.Request('GET', _uri(ApiRoutes.reportContext(visitId))),
    );
    return ReportContext.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// Guarda la inspección de una estación. Guardarla otra vez la corrige.
  Future<void> saveStation({
    required String visitId,
    required String stationId,
    required String findingId,
    required String condition,
    required List<String> pestIds,
    required String notes,
  }) {
    final request = http.MultipartRequest(
      'PUT',
      _uri(ApiRoutes.reportStation(visitId, stationId)),
    );
    request.fields.addAll({
      'finding_id': findingId,
      'station_condition': condition,
      'pest_ids': jsonEncode(pestIds),
      if (notes.isNotEmpty) 'notes': notes,
    });
    return _send(request);
  }

  /// Cierra el reporte con las dos firmas. Devuelve el estado de pago:
  /// «pendiente» si falta preguntar si pagó, «pagado» si el servicio era de $0.
  Future<String> complete({
    required String visitId,
    required String receivedBy,
    required String amount,
    required String recommendations,
    required String notes,
    required Uint8List signature,
    required Uint8List technicianSignature,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri(ApiRoutes.completeReport(visitId)),
    );
    request.fields.addAll({
      'received_by_name': receivedBy,
      'charged_amount': amount,
      'recommendations': recommendations,
      if (notes.isNotEmpty) 'general_notes': notes,
      'signed_at': DateTime.now().toUtc().toIso8601String(),
    });
    request.files.addAll([
      _png('signature', signature),
      _png('technician_signature', technicianSignature),
    ]);
    final body = await _send(request);
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['payment_status'] as String? ?? 'pendiente';
  }

  /// Después de firmar: si el cliente pagó y con qué (o con qué va a pagar).
  Future<void> declarePayment({
    required String visitId,
    required bool paid,
    required String method,
  }) {
    final request = http.Request(
      'POST',
      _uri(ApiRoutes.reportPayment(visitId)),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'payment_status': paid ? 'pagado' : 'sin_pagar',
      'payment_method': method,
    });
    return _send(request);
  }

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');

  http.MultipartFile _png(String field, Uint8List bytes) =>
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: '$field.png',
        contentType: MediaType('image', 'png'),
      );

  /// Manda la petición con el token y convierte cualquier fallo
  /// en un mensaje que se puede enseñar al técnico.
  Future<String> _send(http.BaseRequest request) async {
    final tokens = await tokenStore.read();
    if (tokens == null) {
      throw const CustomException(message: AuthMessages.expiredSession);
    }
    request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    request.headers['Accept'] = 'application/json';

    final http.Response response;
    try {
      response = await http.Response.fromStream(await httpClient.send(request))
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const CustomException(message: AuthMessages.connection);
    } on http.ClientException {
      throw const CustomException(message: AuthMessages.connection);
    }

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 401) {
      throw const CustomException(message: AuthMessages.expiredSession);
    }
    if (response.statusCode >= 300) {
      throw CustomException(
        message: _detail(body) ?? 'No se pudo guardar. Intenta de nuevo',
        status: response.statusCode,
      );
    }
    return body;
  }

  /// La API explica sus errores en «detail» cuando es un texto para el usuario.
  String? _detail(String body) {
    try {
      final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
      return detail is String ? detail : null;
    } on Object {
      return null;
    }
  }
}
