import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';

void main() {
  const tUser = User(
    id: 'dev-user-ana',
    name: 'Ana Souza',
    email: 'ana.souza@pouapp.dev',
  );

  test('should compare users by id, name and email', () {
    expect(
      tUser,
      const User(
        id: 'dev-user-ana',
        name: 'Ana Souza',
        email: 'ana.souza@pouapp.dev',
      ),
    );
    expect(
      tUser,
      isNot(
        const User(
          id: 'dev-user-bruno',
          name: 'Ana Souza',
          email: 'ana.souza@pouapp.dev',
        ),
      ),
    );
  });
}
