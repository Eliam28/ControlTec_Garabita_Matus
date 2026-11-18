import '../../base/abstract_api_handler.dart';
import '../../models/auth_tokens.dart';
import '../api_routes.dart';
import '../auth_messages.dart';
import 'my_day_service.dart';

/// Hace la petición GET /scheduling/my-day con el token de la sesión.
class MyDayApi extends AbstractApiHandler<AuthTokens, String> {
  const MyDayApi({required super.httpClient, required super.baseUrl})
    : super(
        failureMessage: MyDayService.loadError,
        unauthorizedMessage: AuthMessages.expiredSession,
      );

  @override
  Future<String> doExecute(AuthTokens input) => webClientGet(
    ApiRoutes.myDay,
    headers: {'Authorization': 'Bearer ${input.accessToken}'},
  );
}
