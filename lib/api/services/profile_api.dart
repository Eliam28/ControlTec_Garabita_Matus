import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../base/abstract_api_handler.dart';
import '../../base/custom_exception.dart';
import '../../models/auth_tokens.dart';
import '../../models/signature_image.dart';
import '../../models/technician.dart';
import '../api_routes.dart';
import '../auth_messages.dart';

class ProfileApi extends AbstractApiHandler<AuthTokens, Uint8List> {
  ProfileApi({required super.httpClient, required super.baseUrl})
    : super(
        failureMessage: previewError,
        unauthorizedMessage: AuthMessages.expiredSession,
      );

  static const saveError =
      'No fue posible guardar la firma. Intente nuevamente';
  static const previewError = 'No fue posible cargar la firma';

  Uri _uri(String path) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      throw const CustomException(
        message: AuthMessages.pendingApi,
        code: 'configuration',
      );
    }
    return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
  }

  @override
  Future<Uint8List> doExecute(AuthTokens input) async {
    final response = await httpClient
        .get(
          _uri(ApiRoutes.signatureImage),
          headers: {
            'Authorization': 'Bearer ${input.accessToken}',
            'Accept': 'image/png',
          },
        )
        .timeout(timeout);
    _check(response, previewError);
    final bytes = response.bodyBytes;
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < png.length ||
        !List.generate(
          png.length,
          (i) => bytes[i] == png[i],
        ).every((match) => match)) {
      throw const CustomException(
        message: previewError,
        code: 'invalid_response',
      );
    }
    return bytes;
  }

  Future<Technician> upload(SignatureImage image, AuthTokens tokens) async {
    if (image.bytes.isEmpty) throw const CustomException(message: saveError);
    final request = http.MultipartRequest('PUT', _uri(ApiRoutes.signature))
      ..headers['Authorization'] = 'Bearer ${tokens.accessToken}'
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(
          'signature',
          image.bytes,
          filename: image.filename,
        ),
      );
    final response = await (() async => http.Response.fromStream(
      await httpClient.send(request),
    ))().timeout(const Duration(seconds: 90));
    _check(response, saveError);
    try {
      final user = Technician.fromApiJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      if (!user.hasSignature) {
        throw const FormatException('Missing signature confirmation');
      }
      return user;
    } on FormatException {
      throw const CustomException(message: saveError, code: 'invalid_response');
    } on TypeError {
      throw const CustomException(message: saveError, code: 'invalid_response');
    }
  }

  void _check(http.Response response, String message) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CustomException(
        message: response.statusCode == 401
            ? AuthMessages.expiredSession
            : message,
        code: 'http',
        status: response.statusCode,
      );
    }
  }
}
