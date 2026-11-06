import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/core/usecases/usecase.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';
import 'package:pouapp/features/auth/domain/repositories/auth_repository.dart';
import 'package:pouapp/features/auth/domain/usecases/get_current_user.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late GetCurrentUser usecase;
  late MockAuthRepository mockAuthRepository;

  const tUser = User(
    id: 'dev-user-ana',
    name: 'Ana Souza',
    email: 'ana.souza@pouapp.dev',
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = GetCurrentUser(mockAuthRepository);
  });

  test('should return the authenticated user from the repository', () async {
    // arrange
    when(() => mockAuthRepository.getCurrentUser())
        .thenAnswer((_) async => const Right(tUser));

    // act
    final result = await usecase(const NoParams());

    // assert
    expect(result, const Right<Failure, User?>(tUser));
    verify(() => mockAuthRepository.getCurrentUser()).called(1);
    verifyNoMoreInteractions(mockAuthRepository);
  });

  test('should return null when there is no session', () async {
    // arrange
    when(() => mockAuthRepository.getCurrentUser())
        .thenAnswer((_) async => const Right(null));

    // act
    final result = await usecase(const NoParams());

    // assert
    expect(result, const Right<Failure, User?>(null));
    verify(() => mockAuthRepository.getCurrentUser()).called(1);
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
