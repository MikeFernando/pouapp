import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/catalog/domain/failures/catalog_failures.dart';
import 'package:pouapp/features/catalog/domain/rules/stock_rules.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late CatalogLocalDataSourceImpl dataSource;
  late CatalogRepositoryImpl repository;
  var sequence = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    sequence = 0;
    dataSource = CatalogLocalDataSourceImpl(
      databasePath: inMemoryDatabasePath,
      seedDemo: false,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'id-${sequence++}',
    );
    repository = CatalogRepositoryImpl(localDataSource: dataSource);
  });

  tearDown(() async {
    await dataSource.close();
  });

  test('keeps the opening balance and separates locations', () async {
    final created = await repository.createProduct(
      const ProductDraft(
        name: 'Alho',
        unit: CatalogUnit.kilogram,
        salePriceCents: 3000,
        openingLocation: StockLocationCode.warehouse,
        openingQuantity: 1000,
        minimumQuantity: 2000,
      ),
    );
    final stock = created.getOrElse(() => throw StateError('create'));
    expect(stock.product.salePriceCents, 3000);
    expect(stock.balances[StockLocationCode.warehouse], 1000);
    expect(stock.balances[StockLocationCode.montana], 0);
    expect(stock.low, isTrue);
    expect(stock.total, 1000);

    final reopened = CatalogRepositoryImpl(localDataSource: dataSource);
    final stored = await reopened.getProduct(stock.product.id);
    final again = stored.getOrElse(() => throw StateError('read'));
    expect(again.total, 1000);
    expect(again.product.name, 'Alho');

    final duplicate = await repository.recordOpening(
      productId: stock.product.id,
      location: StockLocationCode.warehouse,
      quantity: 500,
    );
    expect(
      duplicate,
      const Left(CatalogRuleFailure(StockRuleViolation.duplicateOpening)),
    );

    final montana = await repository.recordOpening(
      productId: stock.product.id,
      location: StockLocationCode.montana,
      quantity: 500,
    );
    final split = montana.getOrElse(() => throw StateError('montana'));
    expect(split.balances[StockLocationCode.warehouse], 1000);
    expect(split.balances[StockLocationCode.montana], 500);
    expect(split.total, 1500);

    final removed = await repository.deleteProduct(stock.product.id);
    expect(
      removed,
      const Left(CatalogRuleFailure(StockRuleViolation.deleteWithHistory)),
    );

    final inactive = await repository.setActive(
      id: stock.product.id,
      active: false,
    );
    final hidden = inactive.getOrElse(() => throw StateError('inactive'));
    expect(hidden.product.active, isFalse);
    expect(hidden.low, isFalse);
  });

  test('rejects a count that is not a whole number before it is stored', () {
    expect(parseBaseQuantity(CatalogUnit.piece, '1,5'), isNull);
    expect(parseBaseQuantity(CatalogUnit.box, '2'), 2);
  });
}
