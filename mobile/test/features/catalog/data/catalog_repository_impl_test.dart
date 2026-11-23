import 'dart:io';

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

    final inactive = await repository.setActive(
      id: stock.product.id,
      active: false,
    );
    final hidden = inactive.getOrElse(() => throw StateError('inactive'));
    expect(hidden.product.active, isFalse);
    expect(hidden.low, isFalse);

    final removed = await repository.deleteProduct(stock.product.id);
    expect(removed.isRight(), isTrue);
    final missing = await repository.getProduct(stock.product.id);
    expect(missing, const Left(ProductNotFoundFailure()));
  });

  test('keeps a deleted demo product out of the next opening', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}pouapp-delete-product.db';
    final file = File(path);
    if (file.existsSync()) file.deleteSync();

    CatalogLocalDataSourceImpl open() {
      return CatalogLocalDataSourceImpl(
        databasePath: path,
        seedDemo: true,
        clock: () => DateTime(2026, 11, 6, 12),
        newId: () => 'id-delete',
      );
    }

    final first = open();
    final removed = await CatalogRepositoryImpl(localDataSource: first)
        .deleteProduct('product-alho-500');
    expect(removed.isRight(), isTrue);
    await first.close();

    final second = open();
    final repo = CatalogRepositoryImpl(localDataSource: second);
    expect(
      await repo.getProduct('product-alho-500'),
      const Left(ProductNotFoundFailure()),
    );
    expect((await repo.getProduct('product-cebola')).isRight(), isTrue);
    await second.close();
    if (file.existsSync()) file.deleteSync();
  });

  test('cleaning replaces the hortifruti demo catalog once', () async {
    final file = File(
      '${Directory.systemTemp.path}/pou-cleaning-catalog-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    if (file.existsSync()) file.deleteSync();
    final source = CatalogLocalDataSourceImpl(
      databasePath: file.path,
      seedDemo: true,
      clock: () => DateTime(2026, 11, 15, 12),
      newId: () => 'id-cleaning',
    );
    final repo = CatalogRepositoryImpl(localDataSource: source);
    final before = (await repo.load()).getOrElse(
      () => throw StateError('load'),
    );
    expect(
      before.products.any((row) => row.product.name == 'Banana nanica'),
      isTrue,
    );

    expect((await repo.useCleaningCatalog()).isRight(), isTrue);
    final after = (await repo.load()).getOrElse(
      () => throw StateError('after'),
    );
    final names = after.products.map((row) => row.product.name).toList();
    expect(names, isNot(contains('Banana nanica')));
    expect(names, contains('Desengordurante'));
    expect(names.where((name) => name == 'Desengordurante'), hasLength(1));

    await repo.useCleaningCatalog();
    final again = (await repo.load()).getOrElse(
      () => throw StateError('again'),
    );
    expect(
      again.products.where((row) => row.product.name == 'Desengordurante'),
      hasLength(1),
    );
    await source.close();

    final reopened = CatalogLocalDataSourceImpl(
      databasePath: file.path,
      seedDemo: true,
      clock: () => DateTime(2026, 11, 15, 13),
      newId: () => 'id-reopen',
    );
    final stored = await CatalogRepositoryImpl(localDataSource: reopened)
        .load();
    final kept = stored.getOrElse(() => throw StateError('kept'));
    expect(
      kept.products.any((row) => row.product.name == 'Banana nanica'),
      isFalse,
    );
    expect(
      kept.products.any((row) => row.product.name == 'Desinfetante lavanda'),
      isTrue,
    );
    await reopened.close();
    if (file.existsSync()) file.deleteSync();
  });

  test('meals replaces cleaning and produce, and a hand-added product stays', () async {
    final file = File(
      '${Directory.systemTemp.path}/pou-meals-catalog-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    if (file.existsSync()) file.deleteSync();
    final source = CatalogLocalDataSourceImpl(
      databasePath: file.path,
      seedDemo: true,
      clock: () => DateTime(2026, 11, 15, 12),
      newId: () => 'id-meals',
    );
    final repo = CatalogRepositoryImpl(localDataSource: source);
    expect((await repo.useCleaningCatalog()).isRight(), isTrue);
    final added = await repo.createProduct(
      const ProductDraft(
        name: 'Marmita da casa',
        unit: CatalogUnit.piece,
        salePriceCents: 1800,
        openingLocation: StockLocationCode.warehouse,
        openingQuantity: 4,
        category: 'Tradicionais',
      ),
    );
    expect(added.isRight(), isTrue);

    expect((await repo.useMealsCatalog()).isRight(), isTrue);
    final meals = (await repo.load()).getOrElse(() => throw StateError('meals'));
    final names = meals.products.map((row) => row.product.name).toList();
    expect(names, contains('Feijoada'));
    expect(names, contains('Bife acebolado'));
    expect(names, contains('Marmita vegetariana'));
    expect(names, contains('Frango grelhado'));
    expect(names, contains('Marmita da casa'));
    expect(names, isNot(contains('Desengordurante')));
    expect(names, isNot(contains('Banana nanica')));
    expect(names.where((name) => name == 'Feijoada'), hasLength(1));
    expect(
      meals.products
          .firstWhere((row) => row.product.name == 'Bife acebolado')
          .product
          .salePriceCents,
      2500,
    );

    await repo.useMealsCatalog();
    final again = (await repo.load()).getOrElse(() => throw StateError('again'));
    expect(
      again.products.where((row) => row.product.name == 'Feijoada'),
      hasLength(1),
    );
    await source.close();

    final reopened = CatalogLocalDataSourceImpl(
      databasePath: file.path,
      seedDemo: true,
      clock: () => DateTime(2026, 11, 15, 13),
      newId: () => 'id-meals-reopen',
    );
    final kept = await CatalogRepositoryImpl(localDataSource: reopened).load();
    final stored = kept.getOrElse(() => throw StateError('kept'));
    expect(
      stored.products.any((row) => row.product.name == 'Feijoada'),
      isTrue,
    );
    expect(
      stored.products.any((row) => row.product.name == 'Banana nanica'),
      isFalse,
    );

    final restored = CatalogRepositoryImpl(localDataSource: reopened);
    expect((await restored.useProduceCatalog()).isRight(), isTrue);
    final produce = (await restored.load()).getOrElse(
      () => throw StateError('produce'),
    );
    expect(
      produce.products.any((row) => row.product.name == 'Banana nanica'),
      isTrue,
    );
    expect(
      produce.products.any((row) => row.product.name == 'Feijoada'),
      isFalse,
    );
    expect(
      produce.products.any((row) => row.product.name == 'Marmita da casa'),
      isTrue,
    );
    await reopened.close();
    if (file.existsSync()) file.deleteSync();
  });

  test('rejects a count that is not a whole number before it is stored', () {
    expect(parseBaseQuantity(CatalogUnit.piece, '1,5'), isNull);
    expect(parseBaseQuantity(CatalogUnit.box, '2'), 2);
  });
}
