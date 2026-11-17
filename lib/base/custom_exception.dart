/// An error safe to present to the user. Never include raw server responses.
class CustomException implements Exception {
  const CustomException({required this.message, this.code, this.status});

  final String message;
  final String? code;
  final int? status;

  @override
  String toString() => 'CustomException: $message';
}
