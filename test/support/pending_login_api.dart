import 'dart:async';
import 'dart:convert';

import 'package:controltec_app/base/handler.dart';
import 'package:controltec_app/models/auth_response_dto.dart';
import 'package:controltec_app/models/technician.dart';
import 'package:controltec_app/models/user_credentials_dto.dart';

final mockResponse = jsonEncode(
  const AuthResponseDto.mock(
    Technician(name: 'Test', role: 'técnico', hasSignature: false),
  ).toJson(),
);

class PendingLoginApi implements Handler<UserCredentialsDto, String> {
  final result = Completer<String>();
  int calls = 0;

  @override
  Future<String> execute(UserCredentialsDto input) {
    calls++;
    return result.future;
  }
}
