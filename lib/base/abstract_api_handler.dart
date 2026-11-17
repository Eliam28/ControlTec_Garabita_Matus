import 'dart:convert';

import 'package:http/http.dart' as http;

import 'custom_exception.dart';
import 'handler.dart';

/// Transport only: the caller supplies the encoded body and its content type.
/// The injected client's lifecycle belongs to the composition root.
abstract class AbstractApiHandler<I, O> implements Handler<I, O> {
  const AbstractApiHandler({
    required this.httpClient,
    required this.baseUrl,
    this.timeout = const Duration(seconds: 20),
    this.failureMessage = 'Error al consultar el servidor',
    this.unauthorizedMessage = 'La sesión no está autorizada',
    this.configurationMessage = 'La URL de la API no está configurada',
  });

  final http.Client httpClient;
  final String baseUrl;
  final Duration timeout;
  final String failureMessage;
  final String unauthorizedMessage;
  final String configurationMessage;

  @override
  Future<O> execute(I input) => doExecute(input);

  Future<O> doExecute(I input);

  Future<String> webClientGet(String path, {Map<String, String>? headers}) =>
      _request('GET', path, headers: headers);

  Future<String> webClientPost(
    String path,
    Object? body, {
    Map<String, String>? headers,
  }) => _request('POST', path, body: body, headers: headers);

  Future<String> webClientPut(
    String path,
    Object? body, {
    Map<String, String>? headers,
  }) => _request('PUT', path, body: body, headers: headers);

  Future<String> webClientDelete(String path, {Map<String, String>? headers}) =>
      _request('DELETE', path, headers: headers);

  Future<String> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty ||
        !path.startsWith('/') ||
        path.startsWith('//')) {
      throw CustomException(
        message: configurationMessage,
        code: 'configuration',
      );
    }
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
    final requestHeaders = {'Accept': 'application/json', ...?headers};
    final response = await (switch (method) {
      'GET' => httpClient.get(uri, headers: requestHeaders),
      'POST' => httpClient.post(uri, headers: requestHeaders, body: body),
      'PUT' => httpClient.put(uri, headers: requestHeaders, body: body),
      'DELETE' => httpClient.delete(uri, headers: requestHeaders),
      _ => throw ArgumentError.value(method),
    }).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CustomException(
        message: response.statusCode == 401
            ? unauthorizedMessage
            : failureMessage,
        code: 'http',
        status: response.statusCode,
      );
    }
    return utf8.decode(response.bodyBytes);
  }
}
