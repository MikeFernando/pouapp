import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/data/operational_schema.dart';
import 'package:pouapp/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/catalog/domain/entities/stock_operation.dart';
import 'package:pouapp/features/catalog/domain/failures/catalog_failures.dart';
import 'package:pouapp/features/customers/data/datasources/customer_local_data_source.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_local_data_source.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_simulated_data_source.dart';
import 'package:pouapp/features/workspace/data/operation_store.dart';
import 'package:pouapp/features/workspace/data/repositories/workspace_repository_impl.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
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

  Future<String> openKilograms(String name, int grams) async {
    final created = await repository.createProduct(
      ProductDraft(
        name: name,
        unit: CatalogUnit.kilogram,
        salePriceCents: 1864,
        openingLocation: StockLocationCode.warehouse,
        openingQuantity: grams,
      ),
    );
    return created.fold((failure) => throw StateError('$failure'), (stock) {
      return stock.product.id;
    });
  }

  Future<StockDraft> draft(StockOperationKind kind) async {
    final result = await repository.ensureStockDraft(kind);
    return result.fold(
      (failure) => throw StateError('$failure'),
      (value) => value,
    );
  }

  Future<void> confirm({
    required String id,
    required StockOperationKind kind,
    required List<StockDraftLine> lines,
    StockLocationCode? location,
    String? reason,
  }) async {
    final result = await repository.confirmStockOperation(
      id: id,
      kind: kind,
      location: location,
      reason: reason,
      lines: lines,
    );
    result.fold((failure) => throw StateError('$failure'), (_) {});
  }

  Future<Map<StockLocationCode, int>> balances(String productId) async {
    final result = await repository.getProduct(productId);
    return result.fold(
      (failure) => throw StateError('$failure'),
      (stock) => stock.balances,
    );
  }

  test('loads, returns and records a loss without repeating', () async {
    final banana = await openKilograms('Banana nanica', 100000);
    final opening = await dataSource.productMovements(banana);
    final openingId = opening.single.id;
    final load = await draft(StockOperationKind.load);
    final sameDraft = await draft(StockOperationKind.load);
    expect(sameDraft.id, load.id);

    await confirm(
      id: load.id,
      kind: StockOperationKind.load,
      lines: [StockDraftLine(productId: banana, quantity: 40000)],
    );
    var onHand = await balances(banana);
    expect(onHand[StockLocationCode.warehouse], 60000);
    expect(onHand[StockLocationCode.montana], 40000);
    expect(
      (await balances(banana)).values.fold<int>(0, (a, b) => a + b),
      100000,
    );

    final repeated = await repository.confirmStockOperation(
      id: load.id,
      kind: StockOperationKind.load,
      lines: [const StockDraftLine(productId: 'ignored', quantity: 10000)],
    );
    expect(
      repeated.fold((_) => false, (record) => record.alreadyRecorded),
      isTrue,
    );
    onHand = await balances(banana);
    expect(onHand[StockLocationCode.warehouse], 60000);
    expect(onHand[StockLocationCode.montana], 40000);

    final back = await draft(StockOperationKind.returnToWarehouse);
    expect(back.id, isNot(load.id));
    await confirm(
      id: back.id,
      kind: StockOperationKind.returnToWarehouse,
      lines: [StockDraftLine(productId: banana, quantity: 13000)],
    );
    onHand = await balances(banana);
    expect(onHand[StockLocationCode.warehouse], 73000);
    expect(onHand[StockLocationCode.montana], 27000);

    final loss = await draft(StockOperationKind.loss);
    await confirm(
      id: loss.id,
      kind: StockOperationKind.loss,
      location: StockLocationCode.montana,
      reason: 'Amassou no transporte',
      lines: [StockDraftLine(productId: banana, quantity: 2000)],
    );
    onHand = await balances(banana);
    expect(onHand[StockLocationCode.warehouse], 73000);
    expect(onHand[StockLocationCode.montana], 25000);

    final tooMuch = await repository.confirmStockOperation(
      id: (await draft(StockOperationKind.loss)).id,
      kind: StockOperationKind.loss,
      location: StockLocationCode.montana,
      reason: 'Mais do que há',
      lines: [StockDraftLine(productId: banana, quantity: 30000)],
    );
    expect(tooMuch.isLeft(), isTrue);
    onHand = await balances(banana);
    expect(onHand[StockLocationCode.montana], 25000);

    final db = await dataSource.database();
    final orders = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM street_orders'),
    );
    final payments = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM street_payments'),
    );
    expect(orders, 0);
    expect(payments, 0);
    final storedOpening = await db.query(
      'movements',
      where: 'id = ?',
      whereArgs: [openingId],
    );
    expect(storedOpening.single['quantity'], 100000);
    expect(storedOpening.single['kind'], 'opening');
    final price = await db.query(
      'products',
      columns: ['sale_price_cents'],
      where: 'id = ?',
      whereArgs: [banana],
    );
    expect(price.single['sale_price_cents'], 1864);
    final history = await dataSource.productMovements(banana);
    expect(history.map((movement) => movement.id), contains(openingId));
    final losses = history.where(
      (movement) => movement.kind == MovementKind.loss,
    );
    expect(losses, hasLength(1));
    expect(losses.single.operationId, loss.id);
    final operation = await dataSource.stockOperation(load.id);
    expect(operation.origin, StockLocationCode.warehouse);
    expect(operation.destination, StockLocationCode.montana);
    expect(operation.lines.single.quantity, 40000);
  });

  test('keeps the draft when one item of a load cannot move', () async {
    final banana = await openKilograms('Banana nanica', 100000);
    final created = await repository.createProduct(
      const ProductDraft(
        name: 'Alface crespa',
        unit: CatalogUnit.piece,
        salePriceCents: 350,
        openingLocation: StockLocationCode.warehouse,
        openingQuantity: 5,
      ),
    );
    final lettuce = created.fold((_) => throw StateError('alface'), (stock) {
      return stock.product.id;
    });
    final load = await draft(StockOperationKind.load);
    final result = await repository.confirmStockOperation(
      id: load.id,
      kind: StockOperationKind.load,
      lines: [
        StockDraftLine(productId: banana, quantity: 40000),
        StockDraftLine(productId: lettuce, quantity: 9),
      ],
    );
    expect(
      result.fold((failure) => failure, (_) => null),
      isA<StockOperationFailure>().having(
        (failure) => failure.message,
        'message',
        contains('Alface crespa'),
      ),
    );
    expect((await balances(banana))[StockLocationCode.warehouse], 100000);
    expect((await balances(banana))[StockLocationCode.montana], 0);
    expect((await balances(lettuce))[StockLocationCode.warehouse], 5);
    final kept = await draft(StockOperationKind.load);
    expect(kept.id, load.id);
    expect(kept.lines.map((line) => line.productId), [banana, lettuce]);
    final db = await dataSource.database();
    final operations = await db.query('stock_operations');
    expect(operations, isEmpty);
  });

  test(
    'adjusts only the difference and leaves an unchanged cargo alone',
    () async {
      final garlic = await openKilograms('Alho', 500000);
      final onion = await openKilograms('Cebola', 600000);
      final first = await draft(StockOperationKind.load);
      final loaded = await repository.adjustMontanaLoad(
        id: first.id,
        desired: [
          StockDraftLine(productId: garlic, quantity: 3000),
          StockDraftLine(productId: onion, quantity: 1000),
        ],
      );
      expect(loaded.isRight(), isTrue);
      expect((await balances(garlic))[StockLocationCode.montana], 3000);
      expect((await balances(garlic))[StockLocationCode.warehouse], 497000);
      expect((await balances(onion))[StockLocationCode.montana], 1000);

      final same = await draft(StockOperationKind.load);
      final unchanged = await repository.adjustMontanaLoad(
        id: same.id,
        desired: [
          StockDraftLine(productId: garlic, quantity: 3000),
          StockDraftLine(productId: onion, quantity: 1000),
        ],
      );
      expect(
        unchanged.fold((failure) => failure, (_) => null),
        isA<StockOperationFailure>().having(
          (failure) => failure.message,
          'message',
          'A carga da Montana continua igual.',
        ),
      );
      expect((await balances(garlic))[StockLocationCode.montana], 3000);
      expect((await balances(onion))[StockLocationCode.warehouse], 599000);

      final edited = await repository.adjustMontanaLoad(
        id: same.id,
        desired: [
          StockDraftLine(productId: garlic, quantity: 0),
          StockDraftLine(productId: onion, quantity: 1000),
        ],
      );
      expect(edited.isRight(), isTrue);
      expect((await balances(garlic))[StockLocationCode.montana], 0);
      expect((await balances(garlic))[StockLocationCode.warehouse], 500000);
      expect((await balances(onion))[StockLocationCode.montana], 1000);

      final repeated = await repository.adjustMontanaLoad(
        id: same.id,
        desired: [StockDraftLine(productId: onion, quantity: 0)],
      );
      expect(
        repeated.fold((failure) => failure, (record) => record.alreadyRecorded),
        isTrue,
      );
      expect((await balances(onion))[StockLocationCode.montana], 1000);
    },
  );

  test('refuses a transfer that the origin cannot cover', () async {
    final banana = await openKilograms('Banana nanica', 100000);
    final load = await draft(StockOperationKind.load);
    final result = await repository.confirmStockOperation(
      id: load.id,
      kind: StockOperationKind.load,
      lines: [StockDraftLine(productId: banana, quantity: 100001)],
    );
    expect(result.isLeft(), isTrue);
    expect((await balances(banana))[StockLocationCode.warehouse], 100000);
    expect((await balances(banana))[StockLocationCode.montana], 0);
    expect((await draft(StockOperationKind.load)).id, load.id);
  });

  test('rolls back the origin exit when the destination entry fails', () async {
    final banana = await openKilograms('Banana nanica', 100000);
    final load = await draft(StockOperationKind.load);
    dataSource.beforeDestinationEntry = () async {
      throw StateError('destino');
    };
    await expectLater(
      dataSource.confirmStockOperation(
        id: load.id,
        kind: StockOperationKind.load,
        lines: [StockDraftLine(productId: banana, quantity: 40000)],
      ),
      throwsA(isA<StateError>()),
    );
    expect((await balances(banana))[StockLocationCode.warehouse], 100000);
    expect((await balances(banana))[StockLocationCode.montana], 0);
    final db = await dataSource.database();
    expect(await db.query('stock_operations'), isEmpty);
    final movements = await db.query(
      'movements',
      where: 'product_id = ?',
      whereArgs: [banana],
    );
    expect(movements, hasLength(1));
    expect(movements.single['kind'], 'opening');
    final kept = await db.query(
      'stock_draft_lines',
      where: 'draft_id = ?',
      whereArgs: [load.id],
    );
    expect(kept, hasLength(1));
    expect(kept.single['quantity'], 40000);
  });

  test('stores kilograms as grams and boxes as whole boxes', () async {
    final banana = await openKilograms('Banana nanica', 100000);
    final boxes = await repository.createProduct(
      const ProductDraft(
        name: 'Tomate',
        unit: CatalogUnit.box,
        salePriceCents: 8000,
        openingLocation: StockLocationCode.warehouse,
        openingQuantity: 10,
      ),
    );
    final tomato = boxes.fold((_) => throw StateError('tomate'), (stock) {
      return stock.product.id;
    });
    final weight = await draft(StockOperationKind.load);
    await confirm(
      id: weight.id,
      kind: StockOperationKind.load,
      lines: [StockDraftLine(productId: banana, quantity: 1250)],
    );
    expect((await balances(banana))[StockLocationCode.warehouse], 98750);
    expect((await balances(banana))[StockLocationCode.montana], 1250);
    final crates = await draft(StockOperationKind.load);
    await confirm(
      id: crates.id,
      kind: StockOperationKind.load,
      lines: [StockDraftLine(productId: tomato, quantity: 2)],
    );
    expect((await balances(tomato))[StockLocationCode.warehouse], 8);
    expect((await balances(tomato))[StockLocationCode.montana], 2);
    final db = await dataSource.database();
    final moved = await db.query(
      'movements',
      where: 'product_id = ? AND kind = ?',
      whereArgs: [tomato, MovementKind.transferOut.name],
    );
    expect(moved.single['quantity'], -2);
  });

  test(
    'records the counted difference and keeps the previous movement',
    () async {
      final banana = await openKilograms('Banana nanica', 25000);
      final count = await draft(StockOperationKind.count);
      await confirm(
        id: count.id,
        kind: StockOperationKind.count,
        location: StockLocationCode.warehouse,
        reason: 'Contagem da tarde',
        lines: [StockDraftLine(productId: banana, quantity: 23000)],
      );
      expect((await balances(banana))[StockLocationCode.warehouse], 23000);
      final record = await dataSource.stockOperation(count.id);
      expect(record.lines.single.previousQuantity, 25000);
      expect(record.lines.single.quantity, 23000);
      expect(record.lines.single.delta, -2000);
      final db = await dataSource.database();
      final first = await db.query(
        'movements',
        where: 'operation_id = ?',
        whereArgs: [count.id],
      );
      expect(first.single['quantity'], -2000);
      final firstId = first.single['id'];

      final ignored = await repository.confirmStockOperation(
        id: count.id,
        kind: StockOperationKind.count,
        location: StockLocationCode.warehouse,
        reason: 'Outra contagem',
        lines: [StockDraftLine(productId: banana, quantity: 0)],
      );
      expect(
        ignored.fold((_) => false, (value) => value.alreadyRecorded),
        isTrue,
      );
      final unchanged = await db.query(
        'movements',
        where: 'id = ?',
        whereArgs: [firstId],
      );
      expect(unchanged.single['quantity'], -2000);
      expect(unchanged.single['reason'], 'Contagem da tarde');

      final again = await draft(StockOperationKind.count);
      expect(again.id, isNot(count.id));
      await confirm(
        id: again.id,
        kind: StockOperationKind.count,
        location: StockLocationCode.warehouse,
        reason: 'Segunda contagem',
        lines: [StockDraftLine(productId: banana, quantity: 23000)],
      );
      final history = await db.query(
        'movements',
        where: 'id = ?',
        whereArgs: [firstId],
      );
      expect(history.single['quantity'], -2000);
      expect((await balances(banana))[StockLocationCode.warehouse], 23000);
    },
  );

  test('keeps movements after the database is closed and opened', () async {
    final directory = Directory.systemTemp.createTempSync('pouapp-stock');
    final path = '${directory.path}/catalog.db';
    addTearDown(() async {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    var stored = 0;
    final first = CatalogLocalDataSourceImpl(
      databasePath: path,
      seedDemo: false,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'stored-${stored++}',
    );
    final created = await first.createProduct(
      const ProductDraft(
        name: 'Banana nanica',
        unit: CatalogUnit.kilogram,
        salePriceCents: 1000,
        openingLocation: StockLocationCode.warehouse,
        openingQuantity: 100000,
      ),
    );
    final productId = created.product.id;
    final load = await first.ensureStockDraft(StockOperationKind.load);
    await first.confirmStockOperation(
      id: load.id,
      kind: StockOperationKind.load,
      lines: [StockDraftLine(productId: productId, quantity: 40000)],
    );
    await first.close();

    final second = CatalogLocalDataSourceImpl(
      databasePath: path,
      seedDemo: false,
      newId: () => 'reopened-id',
    );
    addTearDown(second.close);
    final stock = await second.getProduct(productId);
    expect(stock.balances[StockLocationCode.warehouse], 60000);
    expect(stock.balances[StockLocationCode.montana], 40000);
    final operation = await second.stockOperation(load.id);
    expect(operation.lines.single.quantity, 40000);
    final repeated = await second.confirmStockOperation(
      id: load.id,
      kind: StockOperationKind.load,
      lines: [StockDraftLine(productId: productId, quantity: 1000)],
    );
    expect(repeated.alreadyRecorded, isTrue);
    final again = await second.getProduct(productId);
    expect(again.balances[StockLocationCode.montana], 40000);
  });

  test(
    'upgrades an existing catalog without rewriting its movements',
    () async {
      final directory = Directory.systemTemp.createTempSync('pouapp-upgrade');
      final path = '${directory.path}/catalog.db';
      addTearDown(() async {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final legacy = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT,
            sku TEXT,
            unit TEXT NOT NULL,
            active INTEGER NOT NULL,
            sale_price_cents INTEGER NOT NULL,
            sort_index INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE product_minimums (
            product_id TEXT NOT NULL,
            location_code TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            PRIMARY KEY (product_id, location_code)
          )
        ''');
          await db.execute('''
          CREATE TABLE movements (
            id TEXT PRIMARY KEY,
            product_id TEXT NOT NULL,
            location_code TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            kind TEXT NOT NULL,
            reason TEXT,
            occurred_on TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            idempotency_key TEXT NOT NULL UNIQUE
          )
        ''');
          await db.execute('''
          CREATE TABLE app_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
          await createOperationalTables(db);
        },
      );
      await legacy.insert('products', {
        'id': 'alho',
        'name': 'Alho',
        'category': null,
        'sku': null,
        'unit': CatalogUnit.kilogram.name,
        'active': 1,
        'sale_price_cents': 3000,
        'sort_index': 0,
        'created_at': '2026-08-01T00:00:00.000',
        'updated_at': '2026-08-01T00:00:00.000',
      });
      await legacy.insert('movements', {
        'id': 'opening-alho',
        'product_id': 'alho',
        'location_code': 'warehouse',
        'quantity': 100000,
        'kind': 'opening',
        'reason': 'Saldo inicial',
        'occurred_on': '2026-08-01',
        'recorded_at': '2026-08-01T00:00:00.000',
        'idempotency_key': 'opening:alho:warehouse',
      });
      await legacy.insert('customer_notes', {
        'id': 'note-antiga',
        'customer_id': 'customer-ana',
        'status': 'draft',
        'due_on': '2026-08-15',
        'created_at': '2026-08-01T00:00:00.000',
        'updated_at': '2026-08-01T00:00:00.000',
      });
      await legacy.close();

      var upgradedIds = 0;
      final upgraded = CatalogLocalDataSourceImpl(
        databasePath: path,
        seedDemo: false,
        clock: () => DateTime(2026, 11, 3, 12),
        newId: () => 'upgrade-${upgradedIds++}',
      );
      addTearDown(upgraded.close);
      final version = Sqflite.firstIntValue(
        await (await upgraded.database()).rawQuery('PRAGMA user_version'),
      );
      expect(version, catalogDatabaseVersion);
      final stock = await upgraded.getProduct('alho');
      expect(stock.balances[StockLocationCode.warehouse], 100000);
      final db = await upgraded.database();
      final notes = await db.query(
        'customer_notes',
        where: 'id = ?',
        whereArgs: ['note-antiga'],
      );
      expect(notes, hasLength(1));
      final load = await upgraded.ensureStockDraft(StockOperationKind.load);
      await upgraded.confirmStockOperation(
        id: load.id,
        kind: StockOperationKind.load,
        lines: [const StockDraftLine(productId: 'alho', quantity: 40000)],
      );
      final after = await upgraded.getProduct('alho');
      expect(after.balances[StockLocationCode.warehouse], 60000);
      expect(after.balances[StockLocationCode.montana], 40000);
      final opening = await db.query(
        'movements',
        where: 'id = ?',
        whereArgs: ['opening-alho'],
      );
      expect(opening.single['quantity'], 100000);
      expect(opening.single['idempotency_key'], 'opening:alho:warehouse');
    },
  );

  test(
    'completing a visit does not clear the montana load or create a sale',
    () async {
      final directory = Directory.systemTemp.createTempSync('pouapp-route');
      addTearDown(() async {
        await dataSource.close();
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final customers = CustomerLocalDataSourceImpl(
        databasePath: '${directory.path}/customers.db',
        seedDemo: false,
        newId: () => 'customer-route',
      );
      var routeIds = 0;
      final catalog = CatalogLocalDataSourceImpl(
        databasePath: '${directory.path}/catalog.db',
        seedDemo: false,
        clock: () => DateTime(2026, 11, 3, 12),
        newId: () => 'route-${routeIds++}',
      );
      addTearDown(customers.close);
      addTearDown(catalog.close);
      SharedPreferences.setMockInitialValues({
        'freight_ledger': 'frete-intacto',
      });
      final preferences = await SharedPreferences.getInstance();
      final local = WorkspaceLocalDataSourceImpl(
        sharedPreferences: preferences,
      );
      final store = OperationStore(
        openDatabase: catalog.database,
        readStreetOrigin: local.readStreetLedger,
        openCustomerDatabase: customers.database,
      );
      await store.ensureActive();
      final created = await catalog.createProduct(
        const ProductDraft(
          name: 'Banana nanica',
          unit: CatalogUnit.kilogram,
          salePriceCents: 1864,
          openingLocation: StockLocationCode.warehouse,
          openingQuantity: 100000,
        ),
      );
      final db = await catalog.database();
      final ordersBefore = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM street_orders'),
      );
      final load = await catalog.ensureStockDraft(StockOperationKind.load);
      await catalog.confirmStockOperation(
        id: load.id,
        kind: StockOperationKind.load,
        lines: [StockDraftLine(productId: created.product.id, quantity: 40000)],
      );
      final ordersAfterLoad = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM street_orders'),
      );
      expect(ordersAfterLoad, ordersBefore);
      final movementsBefore = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM movements'),
      );
      final workspace = WorkspaceRepositoryImpl(
        localDataSource: local,
        simulatedDataSource: WorkspaceSimulatedDataSource(),
        catalogRepository: CatalogRepositoryImpl(localDataSource: catalog),
        operationStore: store,
      );
      final completed = await workspace.applyStreetChange(
        const CompleteVisit('visit-primavera'),
      );
      expect(completed.isRight(), isTrue);
      final stock = await catalog.getProduct(created.product.id);
      expect(stock.balances[StockLocationCode.warehouse], 60000);
      expect(stock.balances[StockLocationCode.montana], 40000);
      final movementsAfter = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM movements'),
      );
      expect(movementsAfter, movementsBefore);
      final operation = await workspace.getOperation();
      final products = operation.fold(
        (_) => throw StateError('operação'),
        (value) => value.products,
      );
      final banana = products.singleWhere(
        (product) => product.id == created.product.id,
      );
      expect(banana.montana, 40);
      expect(banana.available, 100);
      expect(preferences.getString('freight_ledger'), 'frete-intacto');
    },
  );
}
