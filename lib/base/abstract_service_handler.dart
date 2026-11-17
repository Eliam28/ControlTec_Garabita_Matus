import 'dart:async';

import 'package:http/http.dart' as http;

import 'custom_exception.dart';
import 'handler.dart';

abstract class AbstractServiceHandler<I, O> implements Handler<I, O> {
  const AbstractServiceHandler({
    this.failureMessage = 'No se pudo completar la operación',
    this.connectionMessage = 'No se pudo conectar con el servidor',
  });

  final String failureMessage;
  final String connectionMessage;

  @override
  Future<O> execute(I input) => runSafely(() => doExecute(input));

  Future<O> doExecute(I input);

  /// Also shared by related operations such as refresh and logout.
  Future<T> runSafely<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on CustomException {
      rethrow;
    } on TimeoutException {
      throw CustomException(message: connectionMessage, code: 'connection');
    } on http.ClientException {
      throw CustomException(message: connectionMessage, code: 'connection');
    } catch (_) {
      throw CustomException(message: failureMessage, code: 'unexpected');
    }
  }
}
