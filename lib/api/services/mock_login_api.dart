import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../base/custom_exception.dart';
import '../../base/handler.dart';
import '../../models/auth_response_dto.dart';
import '../../models/technician.dart';
import '../../models/user_credentials_dto.dart';
import '../auth_messages.dart';

/// Development only; no client, network requests or fabricated tokens.
class MockLoginApi implements Handler<UserCredentialsDto, String> {
  const MockLoginApi({this.delay = const Duration(milliseconds: 500)});

  final Duration delay;

  @override
  Future<String> execute(UserCredentialsDto input) async {
    if (kReleaseMode) {
      throw const CustomException(message: AuthMessages.pendingApi);
    }
    await Future<void>.delayed(delay);
    if (input.email != 'tecnico@controltec.com' ||
        input.password != 'Tecnico123') {
      throw const CustomException(message: AuthMessages.invalidCredentials);
    }
    return jsonEncode(
      const AuthResponseDto.mock(
        Technician(
          name: 'Técnico de prueba',
          role: 'técnico',
          hasSignature: false,
        ),
      ).toJson(),
    );
  }
}
