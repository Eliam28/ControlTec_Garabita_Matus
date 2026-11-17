/// Domain model; the API field names will be mapped by AuthApiContract.
class Technician {
  const Technician({
    required this.name,
    required this.role,
    required this.hasSignature,
  });

  final String name;
  final String role;
  final bool hasSignature;

  /// Internal DTO format; real API responses are mapped by AuthApiContract.
  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'hasSignature': hasSignature,
  };

  factory Technician.fromJson(Map<String, dynamic> json) => Technician(
    name: json['name'] as String,
    role: json['role'] as String,
    hasSignature: json['hasSignature'] as bool,
  );
}
