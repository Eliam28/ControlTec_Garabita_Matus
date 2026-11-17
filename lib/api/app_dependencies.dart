import 'package:http/http.dart' as http;

import 'services/auth_api_contract.dart';
import 'services/auth_session_api.dart';
import 'services/login_api.dart';
import 'services/login_service.dart';
import 'services/mock_login_api.dart';
import 'services/token_store.dart';
import 'app_config.dart';

/// Owns the single HTTP client used by both APIs. Mock mode creates none.
class AppDependencies {
  AppDependencies._(this.loginService, this._httpClient);

  factory AppDependencies.fromConfig(AppConfig config) {
    if (config.useMockAuth) {
      return AppDependencies._(
        LoginService.mock(loginApi: const MockLoginApi()),
        null,
      );
    }
    final httpClient = http.Client();
    // TODO(api-contract): Supply the confirmed backend adapter here.
    const contract = PendingAuthApiContract();
    final loginService = LoginService.api(
      loginApi: LoginApi(
        httpClient: httpClient,
        baseUrl: config.apiBaseUrl,
        contract: contract,
      ),
      sessionApi: AuthSessionApi(
        httpClient: httpClient,
        baseUrl: config.apiBaseUrl,
        contract: contract,
      ),
      contract: contract,
      tokenStore: const SecureTokenStore(),
    );
    return AppDependencies._(loginService, httpClient);
  }

  final LoginService loginService;
  final http.Client? _httpClient;

  void dispose() {
    loginService.dispose();
    _httpClient?.close();
  }
}
