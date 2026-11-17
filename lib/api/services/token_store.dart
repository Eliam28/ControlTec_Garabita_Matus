import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/auth_tokens.dart';

abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// One secure entry keeps a rotated pair together. These keys are local storage
/// details, not an assumed FastAPI JSON contract. Passwords are never stored.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'controltec.auth.tokens.v1';

  @override
  Future<AuthTokens?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return AuthTokens.fromJson(json);
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
