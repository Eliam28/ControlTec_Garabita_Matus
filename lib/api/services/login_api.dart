import 'dart:async';

import 'package:http/http.dart' as http;

import '../../base/abstract_api_handler.dart';
import '../../base/custom_exception.dart';
import '../../models/user_credentials_dto.dart';
import '../api_routes.dart';
import '../auth_messages.dart';
import 'auth_api_contract.dart';

/// Only POST /auth/mobile/login. Parsing belongs to LoginService.
class LoginApi extends AbstractApiHandler<UserCredentialsDto, String> {
  LoginApi({
    required super.httpClient,
    required super.baseUrl,
    required this.contract,
    super.timeout = const Duration(seconds: 90),
  }) : super(
         failureMessage: AuthMessages.unavailable,
         unauthorizedMessage: AuthMessages.invalidCredentials,
         configurationMessage: AuthMessages.pendingApi,
       );

  final AuthApiContract contract;

  static const validationMessage =
      'Revise los datos ingresados e intente nuevamente';
  static const timeoutMessage =
      'El servidor tardó demasiado en responder. Intente nuevamente';
  static const serverMessage =
      'El servidor no está disponible. Intente más tarde';
  static const accessDeniedMessage =
      'Esta cuenta no tiene acceso a la app de campo';

  @override
  Future<String> doExecute(UserCredentialsDto input) async {
    final payload = contract.loginBody(input);
    try {
      return await webClientPost(
        ApiRoutes.login,
        payload.body,
        headers: {'Content-Type': payload.contentType},
      );
    } on TimeoutException {
      throw const CustomException(message: timeoutMessage, code: 'timeout');
    } on http.ClientException {
      throw const CustomException(
        message: AuthMessages.connection,
        code: 'connection',
      );
    } on CustomException catch (error) {
      // FastAPI's 422 HTTPValidationError.detail can include the submitted input.
      // Use a safe message by status rather than expose passwords or raw details.
      final message = switch (error.status) {
        400 || 422 => validationMessage,
        403 => accessDeniedMessage,
        int status when status >= 500 => serverMessage,
        _ => error.message,
      };
      throw CustomException(
        message: message,
        code: switch (error.status) {
          400 || 422 => 'validation',
          403 => 'forbidden',
          int status when status >= 500 => 'server',
          _ => error.code,
        },
        status: error.status,
      );
    }
  }
}
