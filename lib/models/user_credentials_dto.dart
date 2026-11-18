class UserCredentialsDto {
  const UserCredentialsDto({required this.email, required this.password});

  final String email;
  final String password;

  /// Required fields of LoginRequest; passwords are sent without trimming.
  Map<String, dynamic> toJson() => {'email': email, 'password': password};

  factory UserCredentialsDto.fromJson(Map<String, dynamic> json) =>
      UserCredentialsDto(
        email: json['email'] as String,
        password: json['password'] as String,
      );
}
