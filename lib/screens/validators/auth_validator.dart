import '../../models/user_credentials_dto.dart';
import '../../api/auth_messages.dart';

abstract final class AuthValidator {
  static final _localPart = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$");
  static final _domainLabel = RegExp(
    r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$',
  );

  static String? validate(UserCredentialsDto credentials) {
    if (credentials.email.trim().isEmpty ||
        credentials.password.trim().isEmpty) {
      return AuthMessages.emptyFields;
    }
    if (!_isValidEmail(credentials.email.trim())) {
      return AuthMessages.invalidEmail;
    }
    return null;
  }

  static bool _isValidEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || email.length > 254) return false;
    final local = parts.first;
    if (local.isEmpty ||
        local.length > 64 ||
        !_localPart.hasMatch(local) ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..')) {
      return false;
    }
    final labels = parts.last.split('.');
    return labels.length >= 2 &&
        labels.last.length >= 2 &&
        labels.every(
          (label) => label.length <= 63 && _domainLabel.hasMatch(label),
        );
  }
}
