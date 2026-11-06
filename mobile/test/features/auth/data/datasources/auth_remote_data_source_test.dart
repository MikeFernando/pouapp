import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:pouapp/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:pouapp/features/auth/data/models/user_model.dart';
import 'package:pouapp/features/auth/data/simulated_auth_policy.dart';

void main() {
  const tEmail = 'ana.souza@pouapp.dev';
  const tPassword = 'senha-dev';
  const tUserModel = UserModel(
    id: 'dev-user-ana',
    name: 'Ana Souza',
    email: tEmail,
  );

  SimulatedAuthRemoteDataSource dataSource({
    bool? enabled,
    Duration delay = Duration.zero,
  }) {
    return SimulatedAuthRemoteDataSource(delay: delay, enabled: enabled);
  }

  group('login', () {
    test(
      'should return the development user for the simulated credentials',
      () async {
        final result = await dataSource().login(
          email: '  Ana.Souza@pouapp.dev  ',
          password: tPassword,
        );

        expect(result, tUserModel);
      },
    );

    test('should reject an unknown email', () {
      expect(
        dataSource().login(email: 'outra@pouapp.dev', password: tPassword),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test('should reject a wrong password', () {
      expect(
        dataSource().login(email: tEmail, password: 'outra-senha'),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test('should wait for the configured latency before answering', () async {
      final source = dataSource(delay: const Duration(milliseconds: 30));
      var completed = false;

      final future = source.login(email: tEmail, password: tPassword).then((_) {
        completed = true;
      });
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);
      await future;
      expect(completed, isTrue);
    });

    test(
      'should reject the development credentials when simulation is disabled',
      () {
        expect(
          dataSource(enabled: false).login(email: tEmail, password: tPassword),
          throwsA(isA<SimulatedAuthDisabledException>()),
        );
      },
    );

    test(
      'should follow the compile-time development policy by default',
      () async {
        final source = SimulatedAuthRemoteDataSource(delay: Duration.zero);

        if (simulatedAuthEnabled) {
          expect(
            await source.login(email: tEmail, password: tPassword),
            tUserModel,
          );
        } else {
          expect(
            source.login(email: tEmail, password: tPassword),
            throwsA(isA<SimulatedAuthDisabledException>()),
          );
        }
      },
    );
  });

  group('logout', () {
    test('should complete without returning a credential', () async {
      await expectLater(dataSource().logout(), completes);
    });
  });
}
