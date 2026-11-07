import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';
import 'package:pouapp/features/auth/domain/failures/auth_failures.dart';
import 'package:pouapp/features/auth/domain/repositories/auth_repository.dart';
import 'package:pouapp/features/auth/domain/usecases/register_account.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late RegisterAccount usecase;
  late MockAuthRepository mockAuthRepository;

  const tName = 'Carla Lima';
  const tEmail = 'carla@pouapp.dev';
  const tPassword = 'senha-nova';
  const tUser = User(id: 'user-carla-pouapp-dev', name: tName, email: tEmail);

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = RegisterAccount(mockAuthRepository);
  });

  test('should not expose the password in its textual representation', () {
    const params = RegisterParams(
      name: tName,
      email: tEmail,
      password: tPassword,
    );

    expect(params.toString(), isNot(contains(tPassword)));
  });

  test(
    'should return the user when the repository register succeeds',
    () async {
      when(
        () => mockAuthRepository.register(
          name: tName,
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      final result = await usecase(
        const RegisterParams(name: tName, email: tEmail, password: tPassword),
      );

      expect(result, const Right<Failure, User>(tUser));
      verify(
        () => mockAuthRepository.register(
          name: tName,
          email: tEmail,
          password: tPassword,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockAuthRepository);
    },
  );

  test('should return a failure when the email is already in use', () async {
    when(
      () => mockAuthRepository.register(
        name: tName,
        email: tEmail,
        password: tPassword,
      ),
    ).thenAnswer((_) async => const Left(EmailAlreadyRegisteredFailure()));

    final result = await usecase(
      const RegisterParams(name: tName, email: tEmail, password: tPassword),
    );

    expect(result, const Left<Failure, User>(EmailAlreadyRegisteredFailure()));
  });
}
