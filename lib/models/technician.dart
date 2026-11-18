/// Domain model; the API field names will be mapped by AuthApiContract.
class Technician {
  const Technician({
    required this.name,
    required this.role,
    required this.hasSignature,
    this.id,
    this.email,
    this.avatarUrl,
    this.active = true,
    this.capabilities = const [],
  });

  final String name;
  final String role;
  final bool hasSignature;
  final String? id;
  final String? email;
  final String? avatarUrl;
  final bool active;
  final List<String> capabilities;

  /// SessionUserRead from the mobile login/me responses in OpenAPI.
  factory Technician.fromApiJson(Map<String, dynamic> json) {
    final role = json['role'] as String;
    if (!const ['owner', 'admin', 'technician', 'customer'].contains(role)) {
      throw const FormatException('Invalid user role');
    }
    return Technician(
      id: json['id'] as String,
      name: json['full_name'] as String,
      role: role,
      active: json['active'] as bool,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      hasSignature: json['has_signature'] as bool? ?? false,
      capabilities: List<String>.unmodifiable(
        (json['capabilities'] as List<dynamic>? ?? const []).cast<String>(),
      ),
    );
  }
}
