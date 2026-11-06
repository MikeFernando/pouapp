import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/auth/data/models/user_model.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  const tUserModel = UserModel(
    id: 'dev-user-ana',
    name: 'Ana Souza',
    email: 'ana.souza@pouapp.dev',
  );

  test('should be a User', () {
    expect(tUserModel, isA<User>());
  });

  group('fromJson', () {
    test('should return a valid model from the fixture', () {
      final jsonMap = json.decode(fixture('user.json')) as Map<String, dynamic>;

      final result = UserModel.fromJson(jsonMap);

      expect(result, tUserModel);
    });

    test('should ignore a password field when it is present', () {
      final jsonMap = json.decode(fixture('user.json')) as Map<String, dynamic>
        ..['password'] = 'senha-dev';

      final result = UserModel.fromJson(jsonMap);

      expect(result.toJson().containsKey('password'), isFalse);
      expect(result, tUserModel);
    });
  });

  group('toJson', () {
    test('should return a map with id, name and email only', () {
      final result = tUserModel.toJson();

      expect(result, {
        'id': 'dev-user-ana',
        'name': 'Ana Souza',
        'email': 'ana.souza@pouapp.dev',
      });
    });
  });
}
