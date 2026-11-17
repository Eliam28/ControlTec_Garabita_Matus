import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({this.mockAuth = !kReleaseMode, this.apiBaseUrl = ''});

  const AppConfig.fromEnvironment()
    : mockAuth = const bool.fromEnvironment(
        'USE_MOCK_AUTH',
        defaultValue: !kReleaseMode,
      ),
      apiBaseUrl = const String.fromEnvironment('API_BASE_URL');

  final bool mockAuth;
  final String apiBaseUrl;

  // Development credentials must never enable authentication in a release app.
  bool get useMockAuth => mockAuth && !kReleaseMode;
}
