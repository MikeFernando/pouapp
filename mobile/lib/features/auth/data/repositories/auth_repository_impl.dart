import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../exceptions/auth_exceptions.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    this.tokenStore,
  });

  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final AuthTokenStore? tokenStore;

  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.login(
        email: email,
        password: password,
      );
      await localDataSource.cacheUser(user);
      return Right(user);
    } on InvalidCredentialsException {
      return const Left(InvalidCredentialsFailure());
    } on NetworkException {
      return const Left(NetworkFailure());
    } on BadRequestException {
      return const Left(InvalidCredentialsFailure());
    } on SimulatedAuthDisabledException {
      return const Left(ServerFailure());
    } on ServerException {
      return const Left(ServerFailure());
    } on CacheException {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, User>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.register(
        name: name,
        email: email,
        password: password,
      );
      await localDataSource.cacheUser(user);
      return Right(user);
    } on EmailAlreadyRegisteredException {
      return const Left(EmailAlreadyRegisteredFailure());
    } on NetworkException {
      return const Left(NetworkFailure());
    } on BadRequestException {
      return const Left(ServerFailure());
    } on SimulatedAuthDisabledException {
      return const Left(ServerFailure());
    } on ServerException {
      return const Left(ServerFailure());
    } on CacheException {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final cached = await localDataSource.getCachedUser();
      if (cached == null) return const Right(null);

      // Remote API sessions require a token. Drop leftover simulated caches.
      if (tokenStore != null) {
        final access = await tokenStore!.readAccessToken();
        if (access == null || access.isEmpty) {
          await localDataSource.clear();
          return const Right(null);
        }

        try {
          final remote = await remoteDataSource.currentUser();
          await localDataSource.cacheUser(remote);
          return Right(remote);
        } on NetworkException {
          return Right(cached);
        } on ServerException {
          return Right(cached);
        } on UnauthorizedException {
          await localDataSource.clear();
          await tokenStore?.clear();
          return const Right(null);
        }
      }

      return Right(cached);
    } on CacheException {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, User>> updateName({required String name}) async {
    final trimmed = name.trim();
    try {
      if (tokenStore != null) {
        final user = await remoteDataSource.updateName(name: trimmed);
        await localDataSource.cacheUser(user);
        return Right(user);
      }

      final cached = await localDataSource.getCachedUser();
      if (cached == null) return const Left(ServerFailure());
      final updated = UserModel(
        id: cached.id,
        name: trimmed,
        email: cached.email,
      );
      await localDataSource.cacheUser(updated);
      return Right(updated);
    } on NetworkException {
      return const Left(NetworkFailure());
    } on BadRequestException {
      return const Left(ServerFailure());
    } on UnauthorizedException {
      return const Left(ServerFailure());
    } on NotFoundException {
      return const Left(ServerFailure());
    } on SimulatedAuthDisabledException {
      return const Left(ServerFailure());
    } on ServerException {
      return const Left(ServerFailure());
    } on CacheException {
      return const Left(CacheFailure());
    } on UnsupportedError {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      await remoteDataSource.logout();
    } on ServerException {
      // Still clear local session.
    } on NetworkException {
      // Still clear local session.
    } on SimulatedAuthDisabledException {
      return const Left(ServerFailure());
    }

    try {
      await localDataSource.clear();
      await tokenStore?.clear();
    } on CacheException {
      return const Left(CacheFailure());
    }

    return const Right(unit);
  }
}
