import 'package:dartz/dartz.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/license_status.dart';
import '../../domain/repositories/license_repository.dart';
import '../datasources/license_local_data_source.dart';
import '../datasources/license_remote_data_source.dart';

/// How long a cached "active" license may be trusted without a successful
/// remote check. After this, the app blocks until the API responds.
const licenseOfflineGrace = Duration(days: 7);

class LicenseRepositoryImpl implements LicenseRepository {
  LicenseRepositoryImpl({
    required this.localDataSource,
    this.remoteDataSource,
  });

  final LicenseLocalDataSource localDataSource;
  final LicenseRemoteDataSource? remoteDataSource;

  @override
  Future<Either<Failure, LicenseStatus>> check({
    bool forceRemote = false,
  }) async {
    if (!ApiConfig.useRemoteApi || remoteDataSource == null) {
      final alwaysOn = LicenseStatus(
        active: true,
        status: 'active',
        paidUntil: DateTime.now().toUtc().add(const Duration(days: 3650)),
        message: null,
        checkedAt: DateTime.now().toUtc(),
      );
      return Right(alwaysOn);
    }

    try {
      final remote = await remoteDataSource!.fetch();
      await localDataSource.save(remote);
      return Right(remote);
    } on NetworkException {
      final cached = await localDataSource.read();
      if (cached == null) return const Left(NetworkFailure());
      return Right(_resolveOffline(cached));
    } on UnauthorizedException {
      return const Left(ServerFailure());
    } on ServerException {
      if (forceRemote) return const Left(ServerFailure());
      final cached = await localDataSource.read();
      if (cached == null) return const Left(ServerFailure());
      return Right(_resolveOffline(cached));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  LicenseStatus _resolveOffline(LicenseStatus cached) {
    final age = DateTime.now().toUtc().difference(cached.checkedAt.toUtc());
    final stillTrusted =
        cached.active &&
        age <= licenseOfflineGrace &&
        (cached.paidUntil == null ||
            !cached.paidUntil!.toUtc().isBefore(DateTime.now().toUtc()));

    if (stillTrusted) {
      return cached.copyWith(fromCache: true);
    }

    return LicenseStatus(
      active: false,
      status: cached.status,
      paidUntil: cached.paidUntil,
      message:
          cached.message ??
          'Serviço suspenso. Conecte-se à internet para validar o acesso.',
      reason: cached.reason ?? LicenseBlockReason.paymentRequired,
      paidEmail: cached.paidEmail,
      checkedAt: cached.checkedAt,
      fromCache: true,
    );
  }

  @override
  Future<void> clearCache() => localDataSource.clear();
}
