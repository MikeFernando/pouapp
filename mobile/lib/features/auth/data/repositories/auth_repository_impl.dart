import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../exceptions/auth_exceptions.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

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
      final user = await localDataSource.getCachedUser();
      return Right(user);
    } on CacheException {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      await remoteDataSource.logout();
    } on ServerException {
      return const Left(ServerFailure());
    } on SimulatedAuthDisabledException {
      return const Left(ServerFailure());
    }

    try {
      await localDataSource.clear();
    } on CacheException {
      return const Left(CacheFailure());
    }

    return const Right(unit);
  }
}
