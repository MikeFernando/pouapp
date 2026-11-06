import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';
import 'package:pouapp/features/auth/domain/failures/auth_failures.dart';
import 'package:pouapp/features/auth/domain/repositories/auth_repository.dart';
import 'package:pouapp/features/auth/domain/usecases/login.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late Login usecase;
  late MockAuthRepository mockAuthRepository;

  const tEmail = 'ana.souza@pouapp.dev';
  const tPassword = 'senha-dev';
  const tUser = User(id: 'dev-user-ana', name: 'Ana Souza', email: tEmail);

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = Login(mockAuthRepository);
  });

  test('should not expose the password in its textual representation', () {
    const params = Params(email: tEmail, password: tPassword);

    expect(params.toString(), isNot(contains(tPassword)));
  });

  test('should return the user when the repository login succeeds', () async {
    // arrange
    when(() => mockAuthRepository.login(email: tEmail, password: tPassword))
        .thenAnswer((_) async => const Right(tUser));

    // act
    final result = await usecase(
      const Params(email: tEmail, password: tPassword),
    );

    // assert
    expect(result, const Right<Failure, User>(tUser));
    verify(() => mockAuthRepository.login(email: tEmail, password: tPassword))
        .called(1);
    verifyNoMoreInteractions(mockAuthRepository);
  });

  test(
    'should return a failure when the repository rejects the login',
    () async {
      // arrange
      when(() => mockAuthRepository.login(email: tEmail, password: 'errada'))
          .thenAnswer((_) async => const Left(InvalidCredentialsFailure()));

      // act
      final result = await usecase(
        const Params(email: tEmail, password: 'errada'),
      );

      // assert
      expect(result, const Left<Failure, User>(InvalidCredentialsFailure()));
      verify(() => mockAuthRepository.login(email: tEmail, password: 'errada'))
          .called(1);
      verifyNoMoreInteractions(mockAuthRepository);
    },
  );
}
