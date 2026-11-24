import 'report_product.dart';

/// Lo que responde GET /reports/visits/{id}/context: todo lo que necesita
/// el reporte (cliente, estaciones, plagas y lo que ya se capturó).
class ReportContext {
  const ReportContext({
    required this.visitId,
    required this.customerName,
    required this.locationName,
    required this.startTime,
    required this.receivedByName,
    required this.chargedAmount,
    required this.recommendations,
    required this.generalNotes,
    required this.stations,
    required this.pests,
    this.products = const [],
    this.productOptions = const [],
  });

  final String visitId;
  final String customerName;
  final String locationName;
  final String startTime;
  final String receivedByName;
  final String chargedAmount;
  final String recommendations;
  final String generalNotes;
  final List<ReportStation> stations;
  final List<Option> pests;
  final List<AppliedProduct> products;
  final List<CatalogProduct> productOptions;

  int get doneStations => stations.where((s) => s.isDone).length;

  factory ReportContext.fromJson(Map<String, dynamic> json) {
    final charged = json['charged_amount'] as String? ?? '';
    return ReportContext(
      visitId: json['visit_id'] as String,
      customerName: json['customer_name'] as String,
      locationName: json['location_name'] as String,
      startTime: (json['scheduled_time_start'] as String).substring(0, 5),
      receivedByName: json['received_by_name'] as String? ?? '',
      // Si todavía no se cobró nada, se propone el precio del servicio.
      chargedAmount: double.tryParse(charged) == 0 || charged.isEmpty
          ? json['service_price'] as String? ?? ''
          : charged,
      recommendations: json['recommendations'] as String? ?? '',
      generalNotes: json['general_notes'] as String? ?? '',
      products: (json['products'] as List? ?? [])
          .map((p) => AppliedProduct.fromJson(p as Map<String, dynamic>))
          .toList(),
      productOptions: (json['product_options'] as List? ?? [])
          .map((p) => CatalogProduct.fromJson(p as Map<String, dynamic>))
          .toList(),
      stations: (json['stations'] as List)
          .map((s) => ReportStation.fromJson(s as Map<String, dynamic>))
          .toList(),
      pests: (json['pests'] as List)
          .map(
            (p) => Option(
              id: (p as Map<String, dynamic>)['id'] as String,
              label: p['name'] as String,
            ),
          )
          .toList(),
    );
  }
}

/// Una estación del cliente y, si ya se revisó, lo que se capturó.
class ReportStation {
  const ReportStation({
    required this.id,
    required this.code,
    required this.typeName,
    required this.findings,
    this.findingId,
    this.condition,
    this.pestIds = const [],
    this.notes,
  });

  final String id;
  final String code;
  final String typeName;

  /// Los hallazgos posibles; dependen del tipo de estación.
  final List<Option> findings;

  // Lo capturado. Si no hay hallazgo, la estación está pendiente.
  final String? findingId;
  final String? condition;
  final List<String> pestIds;
  final String? notes;

  bool get isDone => findingId != null;

  factory ReportStation.fromJson(Map<String, dynamic> json) {
    final inspection = json['inspection'] as Map<String, dynamic>?;
    return ReportStation(
      id: json['id'] as String,
      code: json['internal_code'] as String,
      typeName: json['station_type_name'] as String,
      findings: (json['findings'] as List)
          .map(
            (f) => Option(
              id: (f as Map<String, dynamic>)['id'] as String,
              label: f['label'] as String,
              severity: f['severity'] as int,
            ),
          )
          .toList(),
      findingId: inspection?['finding_id'] as String?,
      condition: inspection?['station_condition'] as String?,
      pestIds: List<String>.from(inspection?['pest_ids'] as List? ?? []),
      notes: inspection?['notes'] as String?,
    );
  }
}

/// Una opción de una lista: hallazgo, plaga o estado de la estación.
/// [severity] va de 0 (bien) a 3 (grave) y decide el color del punto.
class Option {
  const Option({required this.id, required this.label, this.severity = 0});

  final String id;
  final String label;
  final int severity;
}

/// Cómo quedó el dispositivo. La lista es fija en la API.
const stationConditions = [
  Option(id: 'util', label: 'Útil'),
  Option(id: 'sucia', label: 'Sucia', severity: 1),
  Option(id: 'mojada', label: 'Mojada', severity: 1),
  Option(id: 'bloqueada', label: 'Bloqueada', severity: 1),
  Option(id: 'desanclada', label: 'Desanclada', severity: 1),
  Option(id: 'sin_charola', label: 'Sin charola', severity: 1),
  Option(id: 'rota', label: 'Rota', severity: 3),
  Option(id: 'repuesta', label: 'Repuesta'),
  Option(id: 'perdida', label: 'Perdida', severity: 3),
];

/// Con qué pagó (o va a pagar) el cliente.
const paymentMethods = [
  Option(id: 'efectivo', label: 'Efectivo'),
  Option(id: 'tarjeta', label: 'Tarjeta'),
  Option(id: 'transferencia', label: 'Transferencia'),
  Option(id: 'deposito', label: 'Depósito'),
  Option(id: 'cheque', label: 'Cheque'),
];
