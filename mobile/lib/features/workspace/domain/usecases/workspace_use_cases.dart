import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/company_operation.dart';
import '../entities/sales_board.dart';
import '../entities/stock_board.dart';
import '../entities/street_ledger.dart';
import '../entities/workspace_mode.dart';
import '../repositories/workspace_repository.dart';

class GetWorkspaceMode implements UseCase<WorkspaceMode, NoParams> {
  GetWorkspaceMode(this.repository);

  final WorkspaceRepository repository;

  @override
  Future<Either<Failure, WorkspaceMode>> call(NoParams params) {
    return repository.getMode();
  }
}

class SaveWorkspaceMode implements UseCase<Unit, WorkspaceMode> {
  SaveWorkspaceMode(this.repository);

  final WorkspaceRepository repository;

  @override
  Future<Either<Failure, Unit>> call(WorkspaceMode params) {
    return repository.saveMode(params);
  }
}

class GetCompanyOperation implements UseCase<CompanyOperation, NoParams> {
  GetCompanyOperation(this.repository);

  final WorkspaceRepository repository;

  @override
  Future<Either<Failure, CompanyOperation>> call(NoParams params) {
    return repository.getOperation();
  }
}

class GetSalesBoard implements UseCase<SalesBoard, NoParams> {
  GetSalesBoard(this.repository);

  final WorkspaceRepository repository;

  @override
  Future<Either<Failure, SalesBoard>> call(NoParams params) async {
    final result = await repository.getOperation();
    return result.map(
      (operation) => SalesBoard(
        summary: operation.summary,
        deliveries: operation.deliveries,
        sales: operation.sales,
      ),
    );
  }
}

class GetStockBoard implements UseCase<StockBoard, NoParams> {
  GetStockBoard(this.repository);

  final WorkspaceRepository repository;

  @override
  Future<Either<Failure, StockBoard>> call(NoParams params) async {
    final result = await repository.getOperation();
    return result.map(
      (operation) => StockBoard(
        summary: operation.stock,
        receipts: operation.receipts,
        products: operation.products,
      ),
    );
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
