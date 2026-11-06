import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/company_operation.dart';
import '../entities/street_ledger.dart';
import '../entities/workspace_mode.dart';

abstract class WorkspaceRepository {
  Future<Either<Failure, WorkspaceMode>> getMode();

  Future<Either<Failure, Unit>> saveMode(WorkspaceMode mode);

  /// The same company record used by Rua and by Gestão.
  Future<Either<Failure, CompanyOperation>> getOperation();

  /// Updates the street ledger and returns the shared company record.
  Future<Either<Failure, CompanyOperation>> applyStreetChange(
    StreetChange change,
  );
}
