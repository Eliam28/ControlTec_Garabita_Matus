import 'package:controltec_app/base/custom_exception.dart';
import 'package:controltec_app/api/services/mock_login_api.dart';
import 'package:controltec_app/api/app_config.dart';
import 'package:controltec_app/api/app_dependencies.dart';
import 'package:controltec_app/api/auth_messages.dart';
import 'package:controltec_app/screens/validators/auth_validator.dart';
import 'package:controltec_app/screens/controllers/login_controller.dart';
import 'package:controltec_app/models/user_credentials_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/login_test_support.dart';

const validCredentials = UserCredentialsDto(
  email: 'test@example.com',
  password: 'http-test-password',
);

void main() {
  group('Validation order', () {
    for (final fields in [
      ('', ''),
      ('', 'secret'),
      ('test@example.com', ''),
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

  group('Disabled legacy authentication', () {
    test(
      'The shared legacy configuration cannot establish a session',
      () async {
        final dependencies = AppDependencies.fromConfig(
          const AppConfig(mockAuth: true),
        );
        addTearDown(dependencies.dispose);
        await expectLater(
          dependencies.loginService.execute(validCredentials),
          throwsA(
            isA<CustomException>().having(
              (error) => error.code,
              'code',
              'configuration',
            ),
          ),
        );
      },
    );

    test('The compatibility API cannot return a simulated response', () async {
      await expectLater(
        const MockLoginApi().execute(validCredentials),
        throwsA(
          isA<CustomException>().having(
            (error) => error.code,
            'code',
            'configuration',
          ),
        ),
      );
    });
  });

  group('Login controller', () {
    test(
      'Validates before calling the service and preserves password whitespace',
      () async {
        int requests = 0;
        final service = createTestLoginService(
          handler: (_) async => ++requests == 1
              ? jsonResponse({'detail': 'Invalid credentials'}, 401)
              : jsonResponse(sessionJson()),
        );
        final controller = LoginController(service);
        addTearDown(controller.dispose);
        addTearDown(service.dispose);
        expect(await controller.login('bad', ''), isFalse);
        expect(controller.errorMessage, AuthMessages.emptyFields);
        expect(await controller.login('bad', 'secret'), isFalse);
        expect(controller.errorMessage, AuthMessages.invalidEmail);
        expect(
          await controller.login(
            validCredentials.email,
            ' http-test-password ',
          ),
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
        expect(controller.session?.tokens.accessToken, 'test-only-access');
        expect(controller.isLoading, isFalse);
      },
    );

    test('Blocks duplicate requests while a login is pending', () async {
      final api = PendingLoginResponse();
      final service = createTestLoginService(handler: api.handle);
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
      await api.started.future;
      expect(api.calls, 1);
      api.result.complete(jsonResponse(sessionJson()));
      expect(await first, isTrue);
      expect(controller.isLoading, isFalse);
    });

    test(
      'A late response after disposal does not notify or establish a session',
      () async {
        final api = PendingLoginResponse();
        final service = createTestLoginService(handler: api.handle);
        final controller = LoginController(service);
        final result = controller.login(
          validCredentials.email,
          validCredentials.password,
        );
        controller.dispose();
        api.result.complete(jsonResponse(sessionJson()));
        expect(await result, isFalse);
        expect(controller.session, isNull);
      },
    );

    test(
      'Unexpected failures reset loading and expose a safe message',
      () async {
        final api = PendingLoginResponse();
        final service = createTestLoginService(handler: api.handle);
        final controller = LoginController(service);
        addTearDown(controller.dispose);
        final result = controller.login(
          validCredentials.email,
          validCredentials.password,
        );
        await api.started.future;
        api.result.completeError(Exception('Internal details'));
        expect(await result, isFalse);
        expect(controller.errorMessage, AuthMessages.unavailable);
        expect(controller.isLoading, isFalse);
      },
    );
  });
}
