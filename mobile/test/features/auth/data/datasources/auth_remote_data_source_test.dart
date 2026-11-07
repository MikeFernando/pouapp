import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:pouapp/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:pouapp/features/auth/data/models/user_model.dart';
import 'package:pouapp/features/auth/data/simulated_auth_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const tEmail = 'mike@gmail.com';
  const tPassword = 'mike@123';
  const tUserModel = UserModel(
    id: 'dev-user-mike',
    name: 'Mike',
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
          email: '  Mike@gmail.com  ',
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

  group('register', () {
    const tName = 'Carla Lima';
    const tNewEmail = 'carla@pouapp.dev';
    const tNewPassword = 'senha-nova';
    const tNewUser = UserModel(
      id: 'user-carla-pouapp-dev',
      name: tName,
      email: tNewEmail,
    );

    test('should create an account that can sign in later', () async {
      final source = dataSource();

      final created = await source.register(
        name: '  Carla Lima  ',
        email: '  Carla@pouapp.dev  ',
        password: tNewPassword,
      );

      expect(created, tNewUser);
      expect(
        await source.login(email: tNewEmail, password: tNewPassword),
        tNewUser,
      );
    });

    test('should keep the account after a new data source reads it', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = SimulatedAuthRemoteDataSource(
        delay: Duration.zero,
        enabled: true,
        sharedPreferences: preferences,
      );

      await first.register(
        name: tName,
        email: tNewEmail,
        password: tNewPassword,
      );

      final second = SimulatedAuthRemoteDataSource(
        delay: Duration.zero,
        enabled: true,
        sharedPreferences: preferences,
      );
      expect(
        await second.login(email: tNewEmail, password: tNewPassword),
        tNewUser,
      );
      expect(
        preferences.getString(simulatedAccountsKey),
        contains(tNewPassword),
      );
    });

    test('should reject an email that already exists', () {
      expect(
        dataSource().register(
          name: tName,
          email: tEmail,
          password: tNewPassword,
        ),
        throwsA(isA<EmailAlreadyRegisteredException>()),
      );
    });

    test('should reject a second registration of the same email', () async {
      final source = dataSource();
      await source.register(
        name: tName,
        email: tNewEmail,
        password: tNewPassword,
      );

      expect(
        source.register(
          name: 'Outra',
          email: tNewEmail,
          password: 'outra-senha',
        ),
        throwsA(isA<EmailAlreadyRegisteredException>()),
      );
    });

    test('should refuse to register when simulation is disabled', () {
      expect(
        dataSource(enabled: false)
            .register(name: tName, email: tNewEmail, password: tNewPassword),
        throwsA(isA<SimulatedAuthDisabledException>()),
      );
    });
  });
}
