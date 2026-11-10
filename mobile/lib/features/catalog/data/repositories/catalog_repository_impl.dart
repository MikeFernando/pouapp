import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/stock_operation.dart';
import '../../domain/failures/catalog_failures.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_local_data_source.dart';
import '../exceptions/catalog_exceptions.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({required this.localDataSource});

  final CatalogLocalDataSource localDataSource;

  @override
  Future<Either<Failure, CatalogSnapshot>> load() {
    return _guard(localDataSource.load);
  }

  @override
  Future<Either<Failure, ProductStock>> getProduct(String id) {
    return _guard(() => localDataSource.getProduct(id));
  }

  @override
  Future<Either<Failure, ProductStock>> createProduct(ProductDraft draft) {
    return _guard(() => localDataSource.createProduct(draft));
  }

  @override
  Future<Either<Failure, Unit>> recordWeighing({
    required String productId,
    required int packGrams,
    required int packageCount,
    required int warehouseGrams,
  }) {
    return _guard(() async {
      await localDataSource.recordWeighing(
        productId: productId,
        packGrams: packGrams,
        packageCount: packageCount,
        warehouseGrams: warehouseGrams,
      );
      return unit;
    });
  }

  @override
  Future<Either<Failure, ProductStock>> recordOpening({
    required String productId,
    required StockLocationCode location,
    required int quantity,
  }) {
    return _guard(
      () => localDataSource.recordOpening(
        productId: productId,
        location: location,
        quantity: quantity,
      ),
    );
  }

  @override
  Future<Either<Failure, ProductStock>> setActive({
    required String id,
    required bool active,
  }) {
    return _guard(() => localDataSource.setActive(id: id, active: active));
  }

  @override
  Future<Either<Failure, ProductStock>> setSalePrice({
    required String id,
    required int salePriceCents,
  }) {
    return _guard(
      () => localDataSource.setSalePrice(
        id: id,
        salePriceCents: salePriceCents,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> deleteProduct(String id) {
    return _guard(() async {
      await localDataSource.deleteProduct(id);
      return unit;
    });
  }

  @override
  Future<Either<Failure, StockDraft>> ensureStockDraft(
    StockOperationKind kind,
  ) {
    return _guard(() => localDataSource.ensureStockDraft(kind));
  }

  @override
  Future<Either<Failure, StockOperationRecord>> confirmStockOperation({
    required String id,
    required StockOperationKind kind,
    StockLocationCode? location,
    String? reason,
    required List<StockDraftLine> lines,
  }) {
    return _guard(
      () => localDataSource.confirmStockOperation(
        id: id,
        kind: kind,
        location: location,
        reason: reason,
        lines: lines,
      ),
    );
  }

  @override
  Future<Either<Failure, StockOperationRecord>> adjustMontanaLoad({
    required String id,
    required List<StockDraftLine> desired,
  }) {
    return _guard(
      () => localDataSource.adjustMontanaLoad(id: id, desired: desired),
    );
  }

  @override
  Future<Either<Failure, StockOperationRecord>> stockOperation(String id) {
    return _guard(() => localDataSource.stockOperation(id));
  }

  @override
  Future<Either<Failure, List<StockMovement>>> productMovements(
    String productId,
  ) {
    return _guard(() => localDataSource.productMovements(productId));
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ProductNotFoundException {
      return const Left(ProductNotFoundFailure());
    } on CatalogRuleException catch (error) {
      return Left(CatalogRuleFailure(error.violation));
    } on StockOperationException catch (error) {
      return Left(StockOperationFailure(error.message));
    } on CacheException {
      return const Left(CacheFailure());
    } on DatabaseException {
      return const Left(CacheFailure());
    }
  }
}
