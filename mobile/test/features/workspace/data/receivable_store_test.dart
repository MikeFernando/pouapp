import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/data/operational_schema.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/workspace/data/receivable_store.dart';
import 'package:pouapp/features/workspace/domain/entities/receivable.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  late CatalogLocalDataSourceImpl dataSource;
  late ReceivableStore store;

  setUp(() {
    dataSource = CatalogLocalDataSourceImpl(
      databasePath: inMemoryDatabasePath,
      seedDemo: false,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'catalog-id',
    );
    store = ReceivableStore(
      openDatabase: dataSource.database,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'receipt-id',
    );
  });

  tearDown(() async {
    await dataSource.close();
  });

  Future<int> count(String table) async {
    final db = await dataSource.database();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $table'),
        ) ??
        0;
  }

  test('cash of 50 on a debt of 150 leaves 100 and is not a sale', () async {
    await store.openDebt(
      id: 'debt-ana',
      customerId: 'ana',
      amountCents: 15000,
      dueOn: '2026-11-20',
    );
    final receipt = await store.confirmReceipt(
      id: 'pay-ana',
      customerId: 'ana',
      amountCents: 5000,
      paidOn: '2026-11-03',
      method: PaymentMethod.cash,
      receivableIds: const ['debt-ana'],
    );

    final account = await store.account('ana');
    expect(receipt.method, PaymentMethod.cash);
    expect(receipt.alreadyRecorded, isFalse);
    expect(account.balanceCents, 10000);
    expect(account.openReceivables.single.openCents, 10000);
    expect(await store.netReceivedCents(), 5000);
    expect(await store.companyOpenCents(), 10000);
    expect(await count('street_orders'), 0);
    expect(await count('street_payments'), 0);
  });

  test('tendered 100 on a debt of 80 records 80 and change of 20', () async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 8000);
    final receipt = await store.confirmReceipt(
      id: 'pay-ana',
      customerId: 'ana',
      amountCents: 8000,
      tenderedCents: 10000,
      paidOn: '2026-11-03',
      method: PaymentMethod.cash,
      receivableIds: const ['debt-ana'],
    );

    final account = await store.account('ana');
    expect(receipt.amountCents, 8000);
    expect(receipt.changeCents, 2000);
    expect(receipt.creditCents, 0);
    expect(account.balanceCents, 0);
    expect(await store.netReceivedCents(), 8000);
    expect((await store.paymentsForIndicators()).single.amountCents, 8000);
  });

  test('a manual partial pix reduces only the chosen debt', () async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    final receipt = await store.confirmReceipt(
      id: 'pay-pix',
      customerId: 'ana',
      amountCents: 4000,
      paidOn: '2026-11-03',
      method: PaymentMethod.pix,
      receivableIds: const ['debt-ana'],
    );

    expect(receipt.method, PaymentMethod.pix);
    expect((await store.account('ana')).balanceCents, 11000);
    expect(
      (await store.paymentsForIndicators()).single.method,
      PaymentMethod.pix,
    );
  });

  test('repeating the same receipt does not allocate twice', () async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    await store.confirmReceipt(
      id: 'pay-ana',
      customerId: 'ana',
      amountCents: 5000,
      paidOn: '2026-11-03',
      method: PaymentMethod.cash,
      receivableIds: const ['debt-ana'],
    );
    final again = await store.confirmReceipt(
      id: 'pay-ana',
      customerId: 'ana',
      amountCents: 5000,
      paidOn: '2026-11-03',
      method: PaymentMethod.cash,
      receivableIds: const ['debt-ana'],
    );

    expect(again.alreadyRecorded, isTrue);
    expect((await store.account('ana')).balanceCents, 10000);
    expect(await store.netReceivedCents(), 5000);
    expect(await count('receipt_allocations'), 1);
  });

  test('opening the same debt again does not move its due date', () async {
    await store.openDebt(
      id: 'debt-ana',
      customerId: 'ana',
      amountCents: 15000,
      dueOn: '2026-11-10',
    );
    await store.openDebt(
      id: 'debt-ana',
      customerId: 'ana',
      amountCents: 9000,
      dueOn: '2026-12-01',
    );

    final debt = (await store.account('ana')).receivables.single;
    expect(debt.amountCents, 15000);
    expect(debt.dueOn, '2026-11-10');
  });

  test('excess becomes credit only when that choice is explicit', () async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 8000);
    expect(
      () => store.confirmReceipt(
        id: 'pay-refused',
        customerId: 'ana',
        amountCents: 10000,
        paidOn: '2026-11-03',
        method: PaymentMethod.pix,
        receivableIds: const ['debt-ana'],
      ),
      throwsA(isA<ReceivableException>()),
    );

    final receipt = await store.confirmReceipt(
      id: 'pay-credit',
      customerId: 'ana',
      amountCents: 10000,
      paidOn: '2026-11-03',
      method: PaymentMethod.pix,
      allowCredit: true,
      receivableIds: const ['debt-ana'],
    );

    expect(receipt.creditCents, 2000);
    expect((await store.account('ana')).balanceCents, -2000);
    expect(await store.companyOpenCents(), 0);
  });

  test('reversal keeps the method and reopens the debt', () async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    await store.confirmReceipt(
      id: 'pay-ana',
      customerId: 'ana',
      amountCents: 5000,
      paidOn: '2026-11-03',
      method: PaymentMethod.pix,
      receivableIds: const ['debt-ana'],
    );
    final reversal = await store.reverseReceipt(
      reversalId: 'rev-1',
      receiptId: 'pay-ana',
    );
    final again = await store.reverseReceipt(
      reversalId: 'rev-2',
      receiptId: 'pay-ana',
    );

    final account = await store.account('ana');
    expect(reversal.method, PaymentMethod.pix);
    expect(reversal.amountCents, 5000);
    expect(again.alreadyRecorded, isTrue);
    expect(account.receipts.single.reversed, isTrue);
    expect(account.receipts.single.method, PaymentMethod.pix);
    expect(account.balanceCents, 15000);
    expect(await store.netReceivedCents(), 0);
    expect(await store.paymentsForIndicators(), isEmpty);
    expect(await count('customer_receipts'), 1);
  });

  test('a prepared charge does not change debt or received', () async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 10000);
    final prepared = await store.prepareCharge(
      id: 'charge-ana',
      customerId: 'ana',
      amountCents: 10000,
      description: 'do saldo em aberto',
      message: 'Olá, Ana',
      phone: '5511988887777',
    );
    final same = await store.prepareCharge(
      id: 'charge-ana',
      customerId: 'ana',
      amountCents: 10000,
      description: 'do saldo em aberto',
      message: 'Olá, Ana',
      phone: '5511988887777',
    );

    expect(prepared.status, ChargeStatus.prepared);
    expect(same.id, prepared.id);
    expect((await store.account('ana')).balanceCents, 10000);
    expect(await store.netReceivedCents(), 0);
    expect(await count('charge_preparations'), 1);
    expect(await count('customer_receipts'), 0);

    final opened = await store.markWhatsAppOpened(prepared.id);
    expect(opened.status, ChargeStatus.whatsappOpened);
    expect((await store.account('ana')).balanceCents, 10000);
    expect(await store.netReceivedCents(), 0);
  });

  test('one customer payment does not change another customer', () async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    await store.openDebt(
      id: 'debt-bia',
      customerId: 'bia',
      amountCents: 8000,
      dueOn: '2026-12-01',
    );
    await store.confirmReceipt(
      id: 'pay-ana',
      customerId: 'ana',
      amountCents: 5000,
      paidOn: '2026-11-03',
      method: PaymentMethod.cash,
      receivableIds: const ['debt-ana'],
    );
    await store.prepareCharge(
      id: 'charge-ana',
      customerId: 'ana',
      amountCents: 10000,
      description: 'do saldo em aberto',
      message: 'Olá, Ana',
      phone: '5511988887777',
    );

    final ana = await store.account('ana');
    final bia = await store.account('bia');
    expect(ana.balanceCents, 10000);
    expect(bia.balanceCents, 8000);
    expect(bia.receipts, isEmpty);
    expect(bia.charges, isEmpty);
    expect(await store.companyOpenCents(), 18000);
  });

  test('a failure inside the receipt transaction keeps the debt', () async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    store.beforeCommit = () async {
      throw StateError('falha');
    };

    await expectLater(
      store.confirmReceipt(
        id: 'pay-ana',
        customerId: 'ana',
        amountCents: 5000,
        paidOn: '2026-11-03',
        method: PaymentMethod.cash,
        receivableIds: const ['debt-ana'],
      ),
      throwsA(isA<StateError>()),
    );

    expect((await store.account('ana')).balanceCents, 15000);
    expect(await count('customer_receipts'), 0);
  });

  test('version 4 keeps the opening movement and the draft note', () async {
    final directory = Directory.systemTemp.createTempSync('pouapp-receivable');
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
      'customer_id': 'ana',
      'status': 'draft',
      'due_on': '2026-08-15',
      'created_at': '2026-08-01T00:00:00.000',
      'updated_at': '2026-08-01T00:00:00.000',
    });
    await legacy.close();

    final upgraded = CatalogLocalDataSourceImpl(
      databasePath: path,
      seedDemo: false,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'upgrade-id',
    );
    addTearDown(upgraded.close);
    final migrated = ReceivableStore(
      openDatabase: upgraded.database,
      clock: () => DateTime(2026, 11, 3, 12),
    );
    await migrated.openDebt(
      id: 'debt-ana',
      customerId: 'ana',
      amountCents: 15000,
    );
    final db = await upgraded.database();
    final version = Sqflite.firstIntValue(
      await db.rawQuery('PRAGMA user_version'),
    );
    final opening = await db.query(
      'movements',
      where: 'id = ?',
      whereArgs: ['opening-alho'],
    );
    final notes = await db.query(
      'customer_notes',
      where: 'id = ?',
      whereArgs: ['note-antiga'],
    );

    expect(version, catalogDatabaseVersion);
    expect(opening.single['quantity'], 100000);
    expect(notes, hasLength(1));
    expect((await migrated.account('ana')).balanceCents, 15000);
  });
}
