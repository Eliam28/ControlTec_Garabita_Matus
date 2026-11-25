import 'dart:typed_data';

import '../../base/abstract_service_handler.dart';
import '../../base/custom_exception.dart';
import '../../models/auth_tokens.dart';
import '../../models/signature_image.dart';
import '../../models/technician.dart';
import '../auth_messages.dart';
import 'profile_api.dart';
import 'token_store.dart';

class ProfileService
    extends AbstractServiceHandler<SignatureImage, Technician> {
  const ProfileService({required this.api, required this.tokenStore})
    : super(
        failureMessage: ProfileApi.saveError,
        connectionMessage: AuthMessages.connection,
      );

  final ProfileApi api;
  final TokenStore tokenStore;

  Future<AuthTokens> _tokens() async =>
      await tokenStore.read() ??
      (throw const CustomException(
        message: AuthMessages.expiredSession,
        status: 401,
      ));

  @override
  Future<Technician> doExecute(SignatureImage input) async =>
      api.upload(input, await _tokens());

  Future<Uint8List> signature() =>
      runSafely(() async => api.execute(await _tokens()));
}
