import 'dart:convert';

import '../../base/abstract_service_handler.dart';
import '../../base/custom_exception.dart';
import '../../base/handler.dart';
import '../../models/auth_tokens.dart';
import '../../models/field_day.dart';
import '../auth_messages.dart';
import 'token_store.dart';

/// Obtiene los servicios de hoy del técnico.
/// Solo **lee** los tokens que guardó el login; no los cambia.
class MyDayService extends AbstractServiceHandler<void, FieldDay> {
  /// Modo de desarrollo: datos ficticios, sin internet.
  const MyDayService.mock({required Handler<void, String> this.mockApi})
    : api = null,
      tokenStore = null,
      super(failureMessage: loadError);

  /// Modo real: llama a la API con el token de la sesión.
  const MyDayService.api({
    required Handler<AuthTokens, String> this.api,
    required TokenStore this.tokenStore,
  }) : mockApi = null,
       super(failureMessage: loadError);

  static const loadError = 'No se pudieron cargar tus servicios';

  final Handler<void, String>? mockApi;
  final Handler<AuthTokens, String>? api;
  final TokenStore? tokenStore;

  Future<FieldDay> load() => execute(null);

  @override
  Future<FieldDay> doExecute(void input) async {
    final String body;
    if (mockApi != null) {
      body = await mockApi!.execute(null);
    } else {
      final tokens = await tokenStore!.read();
      if (tokens == null) {
        throw const CustomException(message: AuthMessages.expiredSession);
      }
      body = await api!.execute(tokens);
    }
    return FieldDay.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }
}
