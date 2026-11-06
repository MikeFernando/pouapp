import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/exceptions.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:pouapp/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:pouapp/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:pouapp/features/auth/data/models/user_model.dart';
import 'package:pouapp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pouapp/features/auth/domain/failures/auth_failures.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockAuthLocalDataSource mockLocalDataSource;

  const tEmail = 'ana.souza@pouapp.dev';
  const tPassword = 'senha-dev';
  const tUserModel = UserModel(
    id: 'dev-user-ana',
    name: 'Ana Souza',
    email: tEmail,
  );

  setUpAll(() {
    registerFallbackValue(tUserModel);
  });

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockLocalDataSource = MockAuthLocalDataSource();
    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
    );
  });

  group('login', () {
    test('should return the remote user and cache the session', () async {
      // arrange
      when(() => mockRemoteDataSource.login(email: tEmail, password: tPassword))
          .thenAnswer((_) async => tUserModel);
      when(() => mockLocalDataSource.cacheUser(tUserModel))
          .thenAnswer((_) async {});

      // act
      final result = await repository.login(email: tEmail, password: tPassword);

      // assert
      expect(result, const Right(tUserModel));
      verify(
        () => mockRemoteDataSource.login(email: tEmail, password: tPassword),
      ).called(1);
      verify(() => mockLocalDataSource.cacheUser(tUserModel)).called(1);
    });

    test(
      'should return InvalidCredentialsFailure and skip the cache',
      () async {
        // arrange
        when(
          () => mockRemoteDataSource.login(email: tEmail, password: tPassword),
        ).thenThrow(InvalidCredentialsException());

        // act
        final result = await repository.login(
          email: tEmail,
          password: tPassword,
        );

        // assert
        expect(result, const Left(InvalidCredentialsFailure()));
        verifyZeroInteractions(mockLocalDataSource);
      },
    );

    test(
      'should return ServerFailure when simulated auth is disabled',
      () async {
        // arrange
        when(
          () => mockRemoteDataSource.login(email: tEmail, password: tPassword),
        ).thenThrow(SimulatedAuthDisabledException());

        // act
        final result = await repository.login(
          email: tEmail,
          password: tPassword,
        );

        // assert
        expect(result, const Left(ServerFailure()));
        verifyZeroInteractions(mockLocalDataSource);
      },
    );

    test(
      'should return ServerFailure when the remote data source fails',
      () async {
        // arrange
        when(
          () => mockRemoteDataSource.login(email: tEmail, password: tPassword),
        ).thenThrow(ServerException());

        // act
        final result = await repository.login(
          email: tEmail,
          password: tPassword,
        );

        // assert
        expect(result, const Left(ServerFailure()));
        verifyZeroInteractions(mockLocalDataSource);
      },
    );

    test(
      'should return CacheFailure when the session cannot be stored',
      () async {
        // arrange
        when(
          () => mockRemoteDataSource.login(email: tEmail, password: tPassword),
        ).thenAnswer((_) async => tUserModel);
        when(() => mockLocalDataSource.cacheUser(tUserModel))
            .thenThrow(CacheException());

        // act
        final result = await repository.login(
          email: tEmail,
          password: tPassword,
        );

        // assert
        expect(result, const Left(CacheFailure()));
      },
    );
  });

  group('getCurrentUser', () {
    test('should return the cached user', () async {
      // arrange
      when(() => mockLocalDataSource.getCachedUser())
          .thenAnswer((_) async => tUserModel);

      // act
      final result = await repository.getCurrentUser();

      // assert
      expect(result, const Right(tUserModel));
      verifyZeroInteractions(mockRemoteDataSource);
    });

    test('should return null when there is no cached session', () async {
      // arrange
      when(() => mockLocalDataSource.getCachedUser())
          .thenAnswer((_) async => null);

      // act
      final result = await repository.getCurrentUser();

      // assert
      expect(result, const Right(null));
      verifyZeroInteractions(mockRemoteDataSource);
    });

    test('should return CacheFailure when the cache cannot be read', () async {
      // arrange
      when(() => mockLocalDataSource.getCachedUser())
          .thenThrow(CacheException());

      // act
      final result = await repository.getCurrentUser();

      // assert
      expect(result, const Left(CacheFailure()));
      verifyZeroInteractions(mockRemoteDataSource);
    });
  });

  group('logout', () {
    test('should clear the local session and return unit', () async {
      // arrange
      when(() => mockRemoteDataSource.logout()).thenAnswer((_) async {});
      when(() => mockLocalDataSource.clear()).thenAnswer((_) async {});

      // act
      final result = await repository.logout();

      // assert
      expect(result, const Right(unit));
      verify(() => mockRemoteDataSource.logout()).called(1);
      verify(() => mockLocalDataSource.clear()).called(1);
    });

    test('should return ServerFailure and keep the session when remote logout fails', () async {
      // arrange
      when(() => mockRemoteDataSource.logout()).thenThrow(ServerException());

      // act
      final result = await repository.logout();

      // assert
      expect(result, const Left(ServerFailure()));
      verifyNever(() => mockLocalDataSource.clear());
    });

    test(
      'should return CacheFailure when the session cannot be removed',
      () async {
        // arrange
        when(() => mockRemoteDataSource.logout()).thenAnswer((_) async {});
        when(() => mockLocalDataSource.clear()).thenThrow(CacheException());

        // act
        final result = await repository.logout();

        // assert
        expect(result, const Left(CacheFailure()));
      },
    );
  });
}
