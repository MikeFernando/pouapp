import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/error/exceptions.dart';
import 'package:pouapp/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:pouapp/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:pouapp/features/auth/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  const tUserModel = UserModel(
    id: 'dev-user-ana',
    name: 'Ana Souza',
    email: 'ana.souza@pouapp.dev',
  );

  late SharedPreferences sharedPreferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  AuthLocalDataSourceImpl dataSource({bool? enabled}) {
    return AuthLocalDataSourceImpl(
      sharedPreferences: sharedPreferences,
      enabled: enabled,
    );
  }

  group('cacheUser', () {
    test('should persist the user without the password', () async {
      await dataSource(enabled: true).cacheUser(tUserModel);

      final stored = sharedPreferences.getString(cachedAuthUserKey);
      expect(stored, isNotNull);
      expect(stored, isNot(contains('senha')));
      expect(stored, contains(tUserModel.email));
    });

    test(
      'should refuse to persist a session when simulation is disabled',
      () async {
        expect(
          dataSource(enabled: false).cacheUser(tUserModel),
          throwsA(isA<SimulatedAuthDisabledException>()),
        );
        expect(sharedPreferences.getString(cachedAuthUserKey), isNull);
      },
    );
  });

  group('getCachedUser', () {
    test('should return the cached user', () async {
      SharedPreferences.setMockInitialValues({
        cachedAuthUserKey: fixture('user.json'),
      });
      sharedPreferences = await SharedPreferences.getInstance();

      final result = await dataSource(enabled: true).getCachedUser();

      expect(result, tUserModel);
    });

    test('should return null when there is no session', () async {
      final result = await dataSource(enabled: true).getCachedUser();

      expect(result, isNull);
    });

    test(
      'should throw CacheException when the stored session is corrupt',
      () async {
        SharedPreferences.setMockInitialValues({cachedAuthUserKey: '{'});
        final preferences = await SharedPreferences.getInstance();

        final source = AuthLocalDataSourceImpl(
          sharedPreferences: preferences,
          enabled: true,
        );

        expect(source.getCachedUser(), throwsA(isA<CacheException>()));
      },
    );

    test(
      'should ignore a stored session when simulation is disabled',
      () async {
        SharedPreferences.setMockInitialValues({
          cachedAuthUserKey: fixture('user.json'),
        });
        sharedPreferences = await SharedPreferences.getInstance();

        final result = await dataSource(enabled: false).getCachedUser();

        expect(result, isNull);
      },
    );
  });

  group('clear', () {
    test('should remove the stored session', () async {
      await dataSource(enabled: true).cacheUser(tUserModel);

      await dataSource(enabled: true).clear();

      expect(sharedPreferences.getString(cachedAuthUserKey), isNull);
    });
  });
}
