import '../../base/custom_exception.dart';
import '../../base/handler.dart';
import '../../models/user_credentials_dto.dart';
import '../auth_messages.dart';

/// Disabled compatibility entry required by the unchanged shared container.
class MockLoginApi implements Handler<UserCredentialsDto, String> {
  const MockLoginApi();

  @override
  Future<String> execute(UserCredentialsDto input) async =>
      throw const CustomException(
        message: AuthMessages.pendingApi,
        code: 'configuration',
      );
}
