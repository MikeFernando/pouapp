import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/freight_ledger.dart';
import '../repositories/freight_repository.dart';

class GetFreightLedger implements UseCase<FreightLedger, NoParams> {
  GetFreightLedger(this.repository);

  final FreightRepository repository;

  @override
  Future<Either<Failure, FreightLedger>> call(NoParams params) {
    return repository.getLedger();
  }
}

class ApplyFreightChange implements UseCase<FreightLedger, FreightChange> {
  ApplyFreightChange(this.repository);

  final FreightRepository repository;

  @override
  Future<Either<Failure, FreightLedger>> call(FreightChange params) {
    return repository.apply(params);
  }
}
