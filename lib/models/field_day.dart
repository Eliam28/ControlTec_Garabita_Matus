import 'field_visit.dart';

/// La respuesta de GET /scheduling/my-day: la fecha de hoy y sus servicios.
class FieldDay {
  const FieldDay({required this.date, required this.visits});

  final DateTime date;
  final List<FieldVisit> visits;

  factory FieldDay.fromJson(Map<String, dynamic> json) => FieldDay(
    date: DateTime.parse(json['date'] as String),
    visits: (json['visits'] as List)
        .map((visit) => FieldVisit.fromJson(visit as Map<String, dynamic>))
        .toList(),
  );
}
