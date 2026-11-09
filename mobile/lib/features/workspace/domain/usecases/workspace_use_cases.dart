import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/company_operation.dart';
import '../entities/street_ledger.dart';
import '../repositories/workspace_repository.dart';

class GetCompanyOperation implements UseCase<CompanyOperation, NoParams> {
  GetCompanyOperation(this.repository);

  final WorkspaceRepository repository;

  @override
  Future<Either<Failure, CompanyOperation>> call(NoParams params) {
    return repository.getOperation();
  }
}

class ApplyStreetChange implements UseCase<CompanyOperation, StreetChange> {
  ApplyStreetChange(this.repository);

  final WorkspaceRepository repository;

  @override
  Future<Either<Failure, CompanyOperation>> call(StreetChange params) {
    return repository.applyStreetChange(params);
  }
}
