import 'package:controltec_app/base/custom_exception.dart';
import 'package:controltec_app/api/services/login_service.dart';
import 'package:controltec_app/api/services/mock_login_api.dart';
import 'package:controltec_app/api/app_config.dart';
import 'package:controltec_app/api/app_dependencies.dart';
import 'package:controltec_app/api/auth_messages.dart';
import 'package:controltec_app/screens/validators/auth_validator.dart';
import 'package:controltec_app/screens/controllers/login_controller.dart';
import 'package:controltec_app/models/user_credentials_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pending_login_api.dart';

const validCredentials = UserCredentialsDto(
  email: 'tecnico@controltec.com',
  password: 'Tecnico123',
);

void main() {
  group('Validation order', () {
    for (final fields in [
      ('', ''),
      ('', 'secret'),
      ('tecnico@controltec.com', ''),
      ('bad-email', ''),
      (' ', '   '),
    ]) {
      test('Empty fields ${fields.$1}/${fields.$2}', () {
        expect(
          AuthValidator.validate(
            UserCredentialsDto(email: fields.$1, password: fields.$2),
          ),
          AuthMessages.emptyFields,
        );
      });
    }
    for (final email in [
      'tecnico',
      'tecnico@',
      '@empresa.com',
      'tecnico@empresa',
      'a@@empresa.com',
      'a@empresa..com',
      'a b@empresa.com',
      '.a@empresa.com',
      'a@-empresa.com',
    ]) {
      test('Reject malformed email $email', () {
        expect(
          AuthValidator.validate(
            UserCredentialsDto(email: email, password: 'secret'),
          ),
          AuthMessages.invalidEmail,
        );
      });
    }
    test('Accept an email with a domain and subdomain', () {
      expect(
        AuthValidator.validate(
          const UserCredentialsDto(
            email: 'tecnico+campo@mx.controltec.com',
            password: 'secret',
          ),
        ),
        isNull,
      );
    });
  });

  group('Mock authentication', () {
    late LoginService service;
    setUp(
      () => service = LoginService.mock(
        loginApi: const MockLoginApi(delay: Duration.zero),
      ),
    );
    tearDown(() => service.dispose());

    test(
      'Only the supplied credentials authenticate; no tokens are fabricated',
      () async {
        for (final credentials in [
          const UserCredentialsDto(
            email: 'otro@controltec.com',
            password: 'Tecnico123',
          ),
          const UserCredentialsDto(
            email: 'tecnico@controltec.com',
            password: 'incorrecta',
          ),
          const UserCredentialsDto(
            email: 'tecnico@controltec.com',
            password: ' Tecnico123 ',
          ),
        ]) {
          await expectLater(
            service.execute(credentials),
            throwsA(
              isA<CustomException>().having(
                (e) => e.message,
                'message',
                AuthMessages.invalidCredentials,
              ),
            ),
          );
        }
        final session = await service.execute(validCredentials);
        expect(session.isMock, isTrue);
        expect(session.tokens, isNull);
        expect(await service.me(), session.technician);
        expect(await service.refresh(), session);
        await service.logout();
        await expectLater(service.me(), throwsA(isA<CustomException>()));
      },
    );

    test('Configuration selects mock or REST without changing the UI', () {
      final mock = AppDependencies.fromConfig(const AppConfig(mockAuth: true));
      final api = AppDependencies.fromConfig(const AppConfig(mockAuth: false));
      expect(mock.loginService.loginApi, isA<MockLoginApi>());
      expect(mock.loginService.isMock, isTrue);
      expect(api.loginService.loginApi, isNot(isA<MockLoginApi>()));
      expect(api.loginService.isMock, isFalse);
      mock.dispose();
      api.dispose();
    });
  });

  group('Login controller', () {
    test(
      'Validates before calling the service and preserves password whitespace',
      () async {
        final service = LoginService.mock(
          loginApi: const MockLoginApi(delay: Duration.zero),
        );
        final controller = LoginController(service);
        addTearDown(controller.dispose);
        addTearDown(service.dispose);
        expect(await controller.login('bad', ''), isFalse);
        expect(controller.errorMessage, AuthMessages.emptyFields);
        expect(await controller.login('bad', 'secret'), isFalse);
        expect(controller.errorMessage, AuthMessages.invalidEmail);
        expect(
          await controller.login(validCredentials.email, ' Tecnico123 '),
          isFalse,
        );
        expect(controller.errorMessage, AuthMessages.invalidCredentials);
        expect(
          await controller.login(
            ' ${validCredentials.email} ',
            validCredentials.password,
          ),
          isTrue,
        );
        expect(controller.errorMessage, isNull);
        expect(controller.session?.isMock, isTrue);
        expect(controller.isLoading, isFalse);
      },
    );

    test('Blocks duplicate requests while a login is pending', () async {
      final api = PendingLoginApi();
      final service = LoginService.mock(loginApi: api);
      final controller = LoginController(service);
      addTearDown(controller.dispose);
      final first = controller.login(
        validCredentials.email,
        validCredentials.password,
      );
      expect(controller.isLoading, isTrue);
      expect(
        await controller.login(
          validCredentials.email,
          validCredentials.password,
        ),
        isFalse,
      );
      expect(api.calls, 1);
      api.result.complete(mockResponse);
      expect(await first, isTrue);
      expect(controller.isLoading, isFalse);
    });

    test(
      'A late response after disposal does not notify or establish a session',
      () async {
        final api = PendingLoginApi();
        final service = LoginService.mock(loginApi: api);
        final controller = LoginController(service);
        final result = controller.login(
          validCredentials.email,
          validCredentials.password,
        );
        controller.dispose();
        api.result.complete(mockResponse);
        expect(await result, isFalse);
        expect(controller.session, isNull);
      },
    );

    test(
      'Unexpected failures reset loading and expose a safe message',
      () async {
        final api = PendingLoginApi();
        final service = LoginService.mock(loginApi: api);
        final controller = LoginController(service);
        addTearDown(controller.dispose);
        final result = controller.login(
          validCredentials.email,
          validCredentials.password,
        );
        api.result.completeError(Exception('Internal details'));
        expect(await result, isFalse);
        expect(controller.errorMessage, AuthMessages.unavailable);
        expect(controller.isLoading, isFalse);
      },
    );
  });
}
