import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/company_operation.dart';
import '../entities/street_ledger.dart';

abstract class WorkspaceRepository {
  /// The company record read by Entregas and by the customer account.
  Future<Either<Failure, CompanyOperation>> getOperation();

  /// Updates the street ledger and returns the shared company record.
  Future<Either<Failure, CompanyOperation>> applyStreetChange(
    StreetChange change,
  );
}
