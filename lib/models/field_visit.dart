/// Un servicio agendado del técnico, tal como llega de GET /scheduling/my-day.
class FieldVisit {
  const FieldVisit({
    required this.id,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.customerName,
    required this.serviceName,
    required this.address,
    this.notes,
    this.paymentStatus = 'pendiente',
  });

  final String id;
  final String status;
  final String startTime;
  final String endTime;
  final String customerName;
  final String serviceName;
  final String address;
  final String? notes;

  /// pendiente, pagado o sin_pagar. Se declara después de firmar.
  final String paymentStatus;

  factory FieldVisit.fromJson(Map<String, dynamic> json) => FieldVisit(
    id: json['id'] as String,
    status: json['status'] as String,
    // La API manda "09:00:00"; nos quedamos con "09:00".
    startTime: (json['scheduled_time_start'] as String).substring(0, 5),
    endTime: (json['scheduled_time_end'] as String).substring(0, 5),
    customerName: json['customer_name'] as String? ?? 'Sin cliente',
    serviceName: json['service_name'] as String? ?? 'Sin servicio',
    address: json['location_address'] as String? ?? 'Sin dirección',
    notes: json['notes'] as String?,
    paymentStatus: json['payment_status'] as String? ?? 'pendiente',
  );

  /// Texto que se muestra para cada estado de la API.
  String get statusLabel => switch (status) {
    'programado' => 'Programado',
    'en_progreso' => 'En progreso',
    'completado' => 'Completado',
    'cancelado' => 'Cancelado',
    _ => status,
  };
}
