import 'package:flutter/foundation.dart';

import '../../api/services/login_service.dart';
import '../../api/auth_messages.dart';
import '../../base/custom_exception.dart';
import '../../models/user_credentials_dto.dart';
import '../../models/auth_response_dto.dart';
import '../validators/auth_validator.dart';

class LoginController extends ChangeNotifier {
  LoginController(this._loginService);

  final LoginService _loginService;
  bool _isLoading = false;
  bool _disposed = false;
  String? _errorMessage;
  AuthResponseDto? _session;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthResponseDto? get session => _session;

  Future<bool> login(String email, String password) async {
    if (_isLoading || _disposed) return false;
    final credentials = UserCredentialsDto(
      email: email.trim(),
      password: password,
    );
    _errorMessage = AuthValidator.validate(credentials);
    if (_errorMessage != null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final session = await _loginService.execute(credentials);
      if (_disposed) return false;
      _session = session;
      return true;
    } on CustomException catch (error) {
      _errorMessage = error.message;
      return false;
    } on Exception {
      _errorMessage = AuthMessages.unavailable;
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
