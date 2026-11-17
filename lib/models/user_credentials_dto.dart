class UserCredentialsDto {
  const UserCredentialsDto({required this.email, required this.password});

  final String email;
  final String password;

  /// Internal representation only; FastAPI field names remain in its contract.
  Map<String, dynamic> toJson() => {'email': email, 'password': password};

  factory UserCredentialsDto.fromJson(Map<String, dynamic> json) =>
      UserCredentialsDto(
        email: json['email'] as String,
        password: json['password'] as String,
      );
}
