import 'package:flutter/foundation.dart';

import '../../api/services/login_service.dart';
import '../../api/auth_messages.dart';
import '../../base/custom_exception.dart';
import '../../models/user_credentials_dto.dart';
import '../../models/auth_response_dto.dart';
import '../../models/technician.dart';
import '../validators/auth_validator.dart';

class LoginController extends ChangeNotifier {
  LoginController(this._loginService) {
    _loginService.onSessionInvalidated = _sessionInvalidated;
    _loginService.onSessionUpdated = _sessionUpdated;
  }

  final LoginService _loginService;
  bool _isLoading = false;
  bool _disposed = false;
  String? _errorMessage;
  AuthResponseDto? _session;
  bool _isCheckingSession = false;
  bool _isSigningOut = false;
  String? _recoveryError;
  int _operation = 0;
  Future<void>? _logoutOperation;
  Future<void>? _activeValidation;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthResponseDto? get session => _session;
  bool get isCheckingSession => _isCheckingSession;
  bool get isSigningOut => _isSigningOut;
  String? get recoveryError => _recoveryError;

  Future<void> initialize() async {
    if (_disposed || _isCheckingSession || _isSigningOut) return;
    final operation = ++_operation;
    _isCheckingSession = true;
    _recoveryError = null;
    notifyListeners();
    try {
      final restored = await _loginService.restoreSession();
      if (_disposed || operation != _operation) return;
      _session = restored;
    } catch (_) {
      if (!_disposed && operation == _operation) {
        _recoveryError = 'No se pudo verificar tu sesión. Revisa tu conexión e intenta nuevamente';
      }
    } finally {
      if (!_disposed && operation == _operation) {
        _isCheckingSession = false;
        notifyListeners();
      }
    }
  }

  Future<void> validateActiveSession() => _activeValidation ??=
      _validateActiveSession().whenComplete(() => _activeValidation = null);

  Future<void> _validateActiveSession() async {
    if (_disposed ||
        _session == null ||
        _isSigningOut ||
        _isCheckingSession ||
        _isLoading) {
      return;
    }
    final operation = _operation;
    try {
      final restored = await _loginService.restoreSession();
      if (_disposed || operation != _operation) return;
      if (restored == null) {
        _sessionInvalidated();
      } else {
        _sessionUpdated(restored);
      }
    } catch (_) {
      // A temporary outage does not invalidate an already authenticated session.
    }
  }

  void _sessionInvalidated() {
    if (_disposed) return;
    _operation++;
    _session = null;
    _isCheckingSession = false;
    _recoveryError = null;
    notifyListeners();
  }

  void _sessionUpdated(AuthResponseDto response) {
    if (_disposed || _session == null || _isSigningOut) return;
    _session = response;
    notifyListeners();
  }

  void updateTechnician(Technician technician) {
    final current = _session;
    if (_disposed || current == null || _isSigningOut) return;
    if (identical(current.technician, technician)) return;
    _session = AuthResponseDto.api(
      technician: technician,
      tokens: current.tokens,
      expiresIn: current.expiresIn,
      refreshExpiresIn: current.refreshExpiresIn,
    );
    notifyListeners();
  }

  Future<void> logout() => _logoutOperation ??= _logout().whenComplete(
    () => _logoutOperation = null,
  );

  Future<void> _logout() async {
    _isSigningOut = true;
    _operation++;
    notifyListeners();
    try {
      await _loginService.logout();
    } catch (_) {
      /* The service always removes the local session in finally. */
    } finally {
      if (!_disposed) {
        _session = null;
        _isSigningOut = false;
        notifyListeners();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    if (_isLoading || _disposed || _isSigningOut || _isCheckingSession) {
      return false;
    }
    final operation = ++_operation;
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
      if (_disposed || operation != _operation) return false;
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
    _operation++;
    if (_loginService.onSessionInvalidated == _sessionInvalidated) {
      _loginService.onSessionInvalidated = null;
    }
    if (_loginService.onSessionUpdated == _sessionUpdated) {
      _loginService.onSessionUpdated = null;
    }
    super.dispose();
  }
}
