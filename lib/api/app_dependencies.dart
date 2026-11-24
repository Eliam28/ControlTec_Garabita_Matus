import 'package:http/http.dart' as http;

import 'services/auth_api_contract.dart';
import 'services/auth_session_api.dart';
import 'services/login_api.dart';
import 'services/login_service.dart';
import 'services/mock_login_api.dart';
import 'services/mock_my_day_api.dart';
import 'services/my_day_api.dart';
import 'services/my_day_service.dart';
import 'services/token_store.dart';
import 'services/day_snapshot_api.dart';
import 'services/session_http_client.dart';
import 'services/profile_api.dart';
import 'services/profile_service.dart';
import 'app_config.dart';

/// Owns the single HTTP client used by every API. Mock mode creates none.
class AppDependencies {
  AppDependencies._(
    this.loginService,
    this.myDayService,
    this._httpClient,
    this.daySnapshot,
    this.profileService, [
    this._ownsLogin = true,
  ]);

  factory AppDependencies.fromConfig(
    AppConfig config, {
    http.Client? client,
    TokenStore? tokenStore,
  }) {
    if (config.useMockAuth) {
      return AppDependencies._(
        LoginService.mock(loginApi: const MockLoginApi()),
        const MyDayService.mock(mockApi: MockMyDayApi()),
        null,
        null,
        null,
      );
    }
    final store = tokenStore ?? const SecureTokenStore();
    late final LoginService loginService;
    final httpClient = SessionHttpClient(
      inner: client ?? http.Client(),
      baseUrl: config.apiBaseUrl,
      tokenStore: store,
      authentication: () => loginService,
    );
    const contract = FastApiAuthContract();
    loginService = LoginService.api(
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
      tokenStore: store,
    );
    // Reads the tokens the login stored; it never writes or refreshes them.
    final daySnapshot = DaySnapshotApi(
      MyDayApi(httpClient: httpClient, baseUrl: config.apiBaseUrl),
    );
    final myDayService = MyDayService.api(api: daySnapshot, tokenStore: store);
    final profileService = ProfileService(
      api: ProfileApi(httpClient: httpClient, baseUrl: config.apiBaseUrl),
      tokenStore: store,
    );
    return AppDependencies._(
      loginService,
      myDayService,
      httpClient,
      daySnapshot,
      profileService,
    );
  }

  factory AppDependencies.fromLoginService(LoginService service) {
    final api = service.loginApi!;
    final store = service.tokenStore!;
    final client = SessionHttpClient(
      inner: api.httpClient,
      baseUrl: api.baseUrl,
      tokenStore: store,
      authentication: () => service,
      ownsInner: false,
    );
    final snapshot = DaySnapshotApi(
      MyDayApi(httpClient: client, baseUrl: api.baseUrl),
    );
    return AppDependencies._(
      service,
      MyDayService.api(api: snapshot, tokenStore: store),
      client,
      snapshot,
      ProfileService(
        api: ProfileApi(httpClient: client, baseUrl: api.baseUrl),
        tokenStore: store,
      ),
      false,
    );
  }

  final LoginService loginService;
  final MyDayService myDayService;
  final http.Client? _httpClient;
  final DaySnapshotApi? daySnapshot;
  final ProfileService? profileService;
  final bool _ownsLogin;

  void clearSessionData() => daySnapshot?.clear();

  void dispose() {
    if (_ownsLogin) loginService.dispose();
    daySnapshot?.dispose();
    _httpClient?.close();
  }
}
