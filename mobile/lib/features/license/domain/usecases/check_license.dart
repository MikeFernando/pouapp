import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/license_status.dart';
import '../repositories/license_repository.dart';

class CheckLicense implements UseCase<LicenseStatus, CheckLicenseParams> {
  CheckLicense(this.repository);

  final LicenseRepository repository;

  @override
  Future<Either<Failure, LicenseStatus>> call(CheckLicenseParams params) {
    return repository.check(forceRemote: params.forceRemote);
  }
}

class CheckLicenseParams extends Equatable {
  const CheckLicenseParams({this.forceRemote = false});

  final bool forceRemote;

  @override
  List<Object?> get props => [forceRemote];
}
