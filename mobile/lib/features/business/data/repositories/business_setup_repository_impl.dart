import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/business_setup.dart';
import '../../domain/repositories/business_setup_repository.dart';
import '../datasources/business_setup_local_data_source.dart';
import '../datasources/business_setup_remote_data_source.dart';

class BusinessSetupRepositoryImpl implements BusinessSetupRepository {
  BusinessSetupRepositoryImpl({
    required this.localDataSource,
    this.remoteDataSource,
  });

  final BusinessSetupLocalDataSource localDataSource;
  final BusinessSetupRemoteDataSource? remoteDataSource;

  @override
  Future<Either<Failure, BusinessSetup>> read(String userId) async {
    final remote = remoteDataSource;
    if (remote == null) {
      return _readLocalOrLegacy(userId);
    }

    try {
      final setup = await remote.fetch(userId);
      await localDataSource.save(setup);
      return Right(setup);
    } on NetworkException {
      final cached = await localDataSource.read(userId);
      if (cached != null) return Right(cached);
      return const Left(NetworkFailure());
    } on ServerException {
      return const Left(ServerFailure());
    } on StateError {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, BusinessSetup>> save({
    required String userId,
    required BusinessKind kind,
  }) async {
    final remote = remoteDataSource;
    try {
      final BusinessSetup setup;
      if (remote == null) {
        setup = BusinessSetup.configured(userId: userId, kind: kind);
      } else {
        setup = await remote.save(userId: userId, kind: kind);
      }
      if (!setup.isConfigured) return const Left(ServerFailure());
      await localDataSource.save(setup);
      final stored = await localDataSource.read(userId);
      if (stored == null || !stored.isConfigured || stored.kind != kind) {
        return const Left(CacheFailure());
      }
      return Right(stored);
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException {
      return const Left(ServerFailure());
    } on StateError {
      return const Left(CacheFailure());
    }
  }

  Future<Either<Failure, BusinessSetup>> _readLocalOrLegacy(
    String userId,
  ) async {
    try {
      final cached = await localDataSource.read(userId);
      if (cached != null) return Right(cached);
      final legacy = BusinessSetup.legacy(userId);
      await localDataSource.save(legacy);
      return Right(legacy);
    } on StateError {
      return const Left(CacheFailure());
    }
  }
}
