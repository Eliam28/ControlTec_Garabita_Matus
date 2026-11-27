import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../base/custom_exception.dart';
import '../../models/report_context.dart';
import '../../models/report_product.dart';
import '../../models/technician.dart';
import '../../models/report_evidence.dart';
import '../api_routes.dart';
import '../auth_messages.dart';
import 'profile_api.dart';
import 'profile_service.dart';
import 'token_store.dart';
import 'evidence_draft_store.dart';

/// Todas las peticiones del reporte de un servicio:
/// iniciar, leer, guardar estaciones, firmar y declarar el pago.
class ReportService {
  const ReportService({
    required this.httpClient,
    required this.baseUrl,
    required this.tokenStore,
    this.evidenceDrafts,
  });

  final http.Client httpClient;
  final String baseUrl;
  final TokenStore tokenStore;
  final EvidenceDraftStore? evidenceDrafts;

  /// El servicio pasa de Programado a En progreso.
  Future<void> start(String visitId) =>
      _send(http.Request('POST', _uri(ApiRoutes.startReport(visitId))));

  Future<ReportContext> load(String visitId) async {
    final body = await _send(
      http.Request('GET', _uri(ApiRoutes.reportContext(visitId))),
    );
    return ReportContext.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// Perfil del técnico autenticado, usando el mismo cliente y renovación.
  Future<Technician> profile() async {
    final body = await _send(http.Request('GET', _uri(ApiRoutes.profile)));
    return Technician.fromApiJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// Reutiliza la consulta autenticada de firma que ya usa el perfil.
  Future<Uint8List> profileSignature() => ProfileService(
    api: ProfileApi(httpClient: httpClient, baseUrl: baseUrl),
    tokenStore: tokenStore,
  ).signature();

  /// La API reemplaza la lista completa y devuelve las aplicaciones resueltas.
  Future<List<AppliedProduct>> saveProducts(
    String visitId,
    List<Map<String, dynamic>> products,
  ) async {
    final request = http.Request('PUT', _uri(ApiRoutes.reportProducts(visitId)))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'products': products});
    final body = await _send(request);
    return (jsonDecode(body) as List)
        .map((p) => AppliedProduct.fromJson(p as Map<String, dynamic>))
        .toList();
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

  /// El servidor usa la firma del perfil cuando no se envía una nueva.
  /// Cierra el reporte con las dos firmas. Devuelve el estado de pago:
  /// «pendiente» si falta preguntar si pagó, «pagado» si el servicio era de $0.
  Future<String> complete({
    required String visitId,
    required String receivedBy,
    required String amount,
    required String recommendations,
    required String notes,
    required Uint8List signature,
    Uint8List? technicianSignature,
    List<EvidencePhoto> photos = const [],
    String? clientKey,
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
      'client_key': ?clientKey,
    });
    request.files.addAll([
      _png('signature', signature),
      if (technicianSignature != null)
        _png('technician_signature', technicianSignature),
      for (final photo in photos)
        http.MultipartFile.fromBytes(
          'photos',
          photo.bytes,
          filename: photo.filename,
          contentType: MediaType.parse(photo.mimeType),
        ),
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
