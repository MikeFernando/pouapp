import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/core/usecases/usecase.dart';
import 'package:pouapp/features/auth/domain/repositories/auth_repository.dart';
import 'package:pouapp/features/auth/domain/usecases/logout.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late Logout usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = Logout(mockAuthRepository);
  });

  test('should return unit when the repository logout succeeds', () async {
    // arrange
    when(() => mockAuthRepository.logout())
        .thenAnswer((_) async => const Right(unit));

    // act
    final result = await usecase(const NoParams());

    // assert
    expect(result, const Right<Failure, Unit>(unit));
    verify(() => mockAuthRepository.logout()).called(1);
    verifyNoMoreInteractions(mockAuthRepository);
  });

  test('should return a failure when the repository logout fails', () async {
    // arrange
    when(() => mockAuthRepository.logout())
        .thenAnswer((_) async => const Left(CacheFailure()));

    // act
    final result = await usecase(const NoParams());

    // assert
    expect(result, const Left<Failure, Unit>(CacheFailure()));
    verify(() => mockAuthRepository.logout()).called(1);
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
