import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/catalog.dart';
import '../entities/stock_operation.dart';

abstract class CatalogRepository {
  Future<Either<Failure, CatalogSnapshot>> load();

  /// Replaces the hortifruti demo catalog with household cleaners.
  Future<Either<Failure, Unit>> useCleaningCatalog();

  /// Replaces the seeded catalog with packed lunches.
  Future<Either<Failure, Unit>> useMealsCatalog();

  /// Replaces the seeded catalog with pizzas.
  Future<Either<Failure, Unit>> usePizzasCatalog();

  /// Replaces the seeded catalog with Brazilian snacks.
  Future<Either<Failure, Unit>> useSnacksCatalog();

  /// Replaces the seeded catalog with pot cakes.
  Future<Either<Failure, Unit>> useCakesCatalog();

  /// Restores produce after another seeded catalog was installed.
  Future<Either<Failure, Unit>> useProduceCatalog();

  Future<Either<Failure, ProductStock>> getProduct(String id);

  Future<Either<Failure, ProductStock>> createProduct(ProductDraft draft);

  /// Stores a weighing on this phone. Balances stay as they are.
  Future<Either<Failure, Unit>> recordWeighing({
    required String productId,
    required int packGrams,
    required int packageCount,
    required int warehouseGrams,
  });

  Future<Either<Failure, ProductStock>> recordOpening({
    required String productId,
    required StockLocationCode location,
    required int quantity,
  });

  Future<Either<Failure, ProductStock>> setActive({
    required String id,
    required bool active,
  });

  Future<Either<Failure, ProductStock>> setSalePrice({
    required String id,
    required int salePriceCents,
  });

  /// Removes the product and its stock from this phone.
  Future<Either<Failure, Unit>> deleteProduct(String id);

  Future<Either<Failure, StockDraft>> ensureStockDraft(StockOperationKind kind);

  Future<Either<Failure, StockOperationRecord>> confirmStockOperation({
    required String id,
    required StockOperationKind kind,
    StockLocationCode? location,
    String? reason,
    required List<StockDraftLine> lines,
  });

  /// Moves only the difference between [desired] and what is already on the
  /// Montana. A repeated [id] does not move stock again.
  Future<Either<Failure, StockOperationRecord>> adjustMontanaLoad({
    required String id,
    required List<StockDraftLine> desired,
  });

  Future<Either<Failure, StockOperationRecord>> stockOperation(String id);

  Future<Either<Failure, List<StockMovement>>> productMovements(
    String productId,
  );
}
