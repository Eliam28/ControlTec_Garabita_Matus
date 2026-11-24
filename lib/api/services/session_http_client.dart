import 'package:http/http.dart' as http;

import '../../base/custom_exception.dart';
import '../auth_messages.dart';
import 'login_service.dart';
import 'token_store.dart';

/// Refreshes one rejected Bearer request without changing feature API/services.
class SessionHttpClient extends http.BaseClient {
  SessionHttpClient({
    required this.inner,
    required this.baseUrl,
    required this.tokenStore,
    required this.authentication,
    this.ownsInner = true,
  });

  final http.Client inner;
  final String baseUrl;
  final TokenStore tokenStore;
  final LoginService Function() authentication;
  final bool ownsInner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final base = Uri.parse(baseUrl);
    final isApi =
        request.url.origin == base.origin &&
        request.url.path.startsWith(
          '${base.path.replaceFirst(RegExp(r'/+$'), '')}/',
        );
    final authPath = request.url.path.contains('/auth/mobile/');
    if (!isApi || authPath) return inner.send(request);

    final service = authentication();
    final revision = service.sessionRevision;
    final bytes = await request.finalize().toBytes();
    final tokens = await tokenStore.read();
    if (tokens == null) {
      if (revision == service.sessionRevision) {
        await service.invalidateSession();
      }
      throw const CustomException(
        message: AuthMessages.expiredSession,
        status: 401,
      );
    }
    Future<http.StreamedResponse> transmit(String accessToken) {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..bodyBytes = bytes
        ..followRedirects = false;
      return inner.send(copy);
    }

    var response = await transmit(tokens.accessToken);
    if (revision != service.sessionRevision) {
      await response.stream.drain<void>();
      throw const CustomException(
        message: AuthMessages.expiredSession,
        code: 'stale_session',
      );
    }
    if (response.statusCode != 401) return response;
    await response.stream.drain<void>();
    final current = await tokenStore.read();
    if (current == null) {
      if (revision == service.sessionRevision) {
        await service.invalidateSession();
      }
      throw const CustomException(
        message: AuthMessages.expiredSession,
        status: 401,
      );
    }
    if (current.accessToken == tokens.accessToken) await service.refresh();
    if (revision != service.sessionRevision) {
      throw const CustomException(
        message: AuthMessages.expiredSession,
        code: 'stale_session',
      );
    }
    final renewed = await tokenStore.read();
    if (renewed == null) {
      if (revision == service.sessionRevision) {
        await service.invalidateSession();
      }
      throw const CustomException(
        message: AuthMessages.expiredSession,
        status: 401,
      );
    }
    response = await transmit(renewed.accessToken);
    if (response.statusCode == 401 && revision == service.sessionRevision) {
      await service.invalidateSession();
    }
    return response;
  }

  @override
  void close() {
    if (ownsInner) inner.close();
  }
}
