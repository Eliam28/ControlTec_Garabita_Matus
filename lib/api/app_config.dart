import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    this.mockAuth = false,
    this.apiBaseUrl = 'https://controltec-tksj.onrender.com',
  });

  const AppConfig.fromEnvironment()
    : mockAuth = const bool.fromEnvironment(
        'USE_MOCK_AUTH',
        defaultValue: false,
      ),
      apiBaseUrl = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://controltec-tksj.onrender.com',
      );

  final bool mockAuth;
  final String apiBaseUrl;

  // Development credentials must never enable authentication in a release app.
  bool get useMockAuth => mockAuth && !kReleaseMode;
}
