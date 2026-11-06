import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/freight_ledger.dart';

abstract class FreightRepository {
  Future<Either<Failure, FreightLedger>> getLedger();

  Future<Either<Failure, FreightLedger>> apply(FreightChange change);
}
