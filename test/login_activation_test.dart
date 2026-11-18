import 'package:controltec_app/api/app_config.dart';
import 'package:controltec_app/api/app_dependencies.dart';
import 'package:controltec_app/api/services/auth_api_contract.dart';
import 'package:controltec_app/api/services/login_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Default app configuration activates FastAPI with the existing shared client', () {
    const config = AppConfig.fromEnvironment();
    expect(config.useMockAuth, isFalse);
    expect(config.apiBaseUrl, 'https://controltec-tksj.onrender.com');
    expect(const AppConfig().useMockAuth, isFalse);
    final dependencies = AppDependencies.fromConfig(config);
    addTearDown(dependencies.dispose);
    expect(dependencies.loginService.isMock, isFalse);
    expect(dependencies.loginService.contract, isA<FastApiAuthContract>());
    final api = dependencies.loginService.loginApi as LoginApi;
    expect(
      api.httpClient,
      same(dependencies.loginService.sessionApi!.httpClient),
    );
  });
}
