/// Wire payload supplied by the confirmed API contract (JSON, form or bytes).
class AuthRequestBody {
  const AuthRequestBody({required this.body, required this.contentType});

  final Object body;
  final String contentType;
}
