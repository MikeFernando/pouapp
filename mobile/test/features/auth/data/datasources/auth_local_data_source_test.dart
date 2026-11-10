import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/error/exceptions.dart';
import 'package:pouapp/features/auth/data/datasources/auth_local_data_source.dart';
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
  late AuthLocalDataSourceImpl dataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    dataSource = AuthLocalDataSourceImpl(sharedPreferences: sharedPreferences);
  });

  group('cacheUser', () {
    test('should persist the user without the password', () async {
      await dataSource.cacheUser(tUserModel);

      final stored = sharedPreferences.getString(cachedAuthUserKey);
      expect(stored, isNotNull);
      expect(stored, isNot(contains('senha')));
      expect(stored, contains(tUserModel.email));
    });
  });

  group('getCachedUser', () {
    test('should return the cached user', () async {
      SharedPreferences.setMockInitialValues({
        cachedAuthUserKey: fixture('user.json'),
      });
      sharedPreferences = await SharedPreferences.getInstance();
      dataSource = AuthLocalDataSourceImpl(sharedPreferences: sharedPreferences);

      final result = await dataSource.getCachedUser();

      expect(result, tUserModel);
    });

    test('should return null when there is no session', () async {
      final result = await dataSource.getCachedUser();

      expect(result, isNull);
    });

    test(
      'should throw CacheException when the stored session is corrupt',
      () async {
        SharedPreferences.setMockInitialValues({cachedAuthUserKey: '{'});
        final preferences = await SharedPreferences.getInstance();

        final source = AuthLocalDataSourceImpl(sharedPreferences: preferences);

        expect(source.getCachedUser(), throwsA(isA<CacheException>()));
      },
    );
  });

  group('clear', () {
    test('should remove the stored session', () async {
      await dataSource.cacheUser(tUserModel);

      await dataSource.clear();

      expect(sharedPreferences.getString(cachedAuthUserKey), isNull);
    });
  });
}
