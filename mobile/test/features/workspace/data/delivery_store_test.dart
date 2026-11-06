import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/data/operational_schema.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/data/datasources/customer_note_local_data_source.dart';
import 'package:pouapp/features/customers/data/exceptions/note_exceptions.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';
import 'package:pouapp/features/workspace/data/delivery_store.dart';
import 'package:pouapp/features/workspace/data/receivable_store.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:pouapp/features/workspace/domain/rules/receivable_rules.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  late CatalogLocalDataSourceImpl dataSource;
  late ReceivableStore receivables;
  late DeliveryStore deliveries;
  late CustomerNoteLocalDataSourceImpl notes;
  var sequence = 0;

  setUp(() {
    sequence = 0;
    dataSource = CatalogLocalDataSourceImpl(
      databasePath: inMemoryDatabasePath,
      seedDemo: false,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'catalog-${sequence++}',
    );
    receivables = ReceivableStore(
      openDatabase: dataSource.database,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'money-${sequence++}',
    );
    deliveries = DeliveryStore(
      openDatabase: dataSource.database,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'move-${sequence++}',
    );
    notes = CustomerNoteLocalDataSourceImpl(
      openDatabase: dataSource.database,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'note-${sequence++}',
    );
  });

  tearDown(() async {
    await dataSource.close();
  });

  Future<Database> db() => dataSource.database();

  Future<int> count(String table) async {
    return Sqflite.firstIntValue(
          await (await db()).rawQuery('SELECT COUNT(*) FROM $table'),
        ) ??
        0;
  }

  Future<int> montana(String productId) async {
    final rows = await (await db()).rawQuery(
      '''
      SELECT COALESCE(SUM(quantity), 0) AS total
      FROM movements
      WHERE product_id = ? AND location_code = ?
      ''',
      [productId, 'montana'],
    );
    return rows.single['total'] as int? ?? 0;
  }

  Future<void> product({
    required String id,
    required String name,
    CatalogUnit unit = CatalogUnit.kilogram,
    bool active = true,
    int price = 3000,
  }) async {
    final database = await db();
    await database.insert('products', {
      'id': id,
      'name': name,
      'category': null,
      'sku': null,
      'unit': unit.name,
      'active': active ? 1 : 0,
      'sale_price_cents': price,
      'sort_index': 0,
      'created_at': '2026-11-03T12:00:00.000',
      'updated_at': '2026-11-03T12:00:00.000',
    });
  }

  Future<void> stock(String productId, int quantity) async {
    await (await db()).insert('movements', {
      'id': 'open-$productId',
      'product_id': productId,
      'location_code': 'montana',
      'quantity': quantity,
      'kind': 'opening',
      'reason': 'Saldo inicial',
      'occurred_on': '2026-11-01',
      'recorded_at': '2026-11-01T00:00:00.000',
      'idempotency_key': 'opening:$productId:montana',
    });
  }

  Future<CustomerNote> draft({
    required String customerId,
    required List<NoteLineDraft> lines,
    DateTime? dueOn,
  }) async {
    final note = await notes.activeDraft(customerId);
    await notes.saveLines(noteId: note.id, lines: lines);
    if (dueOn != null) {
      return notes.setDueOn(noteId: note.id, dueOn: dueOn);
    }
    return notes.note(note.id);
  }

  NoteLineDraft alho({int grams = 1000, int price = 3000, String? productId}) {
    return NoteLineDraft(
      productId: productId,
      name: 'Alho',
      unit: CatalogUnit.kilogram,
      quantity: grams,
      unitPriceCents: price,
    );
  }

  test('fiado turns 150 plus 30 into 180 and removes 1 kg', () async {
    await product(id: 'alho', name: 'Alho');
    await stock('alho', 1000);
    await receivables.openDebt(
      id: 'debt-ana',
      customerId: 'ana',
      amountCents: 15000,
      dueOn: '2026-11-10',
    );
    final note = await draft(
      customerId: 'ana',
      dueOn: DateTime(2026, 12, 3),
      lines: [alho(productId: 'alho')],
    );

    final result = await deliveries.confirm(noteId: note.id);

    expect(result.alreadyRecorded, isFalse);
    expect(result.totalCents, 3000);
    expect(result.occurredOn, '2026-11-03');
    expect(await montana('alho'), 0);
    final account = await receivables.account('ana');
    expect(account.balanceCents, 18000);
    expect(
      account.receivables.singleWhere((item) => item.id == 'debt-ana').dueOn,
      '2026-11-10',
    );
    expect(await receivables.netReceivedCents(), 0);
    expect(await deliveries.soldCents(), 3000);
    expect(await count('street_orders'), 0);
    expect(await count('street_payments'), 0);
    final sync = await (await db()).query(
      'pending_sync',
      where: 'kind = ?',
      whereArgs: ['delivery'],
    );
    expect(sync.single['status'], 'local');
  });

  test('an explicit 50 leaves the debt at 130', () async {
    await product(id: 'alho', name: 'Alho');
    await stock('alho', 5000);
    await receivables.openDebt(
      id: 'debt-ana',
      customerId: 'ana',
      amountCents: 15000,
    );
    final note = await draft(
      customerId: 'ana',
      dueOn: DateTime(2026, 12, 3),
      lines: [alho(productId: 'alho')],
    );

    final result = await deliveries.confirm(
      noteId: note.id,
      payment: DeliveryPayment(
        id: 'pay-ana',
        amountCents: 5000,
        paidOn: '2026-11-03',
        method: PaymentMethod.cash,
        receivableIds: [saleReceivableId(note.id), 'debt-ana'],
      ),
    );

    expect(result.allocations.map((share) => share.amountCents), [3000, 2000]);
    expect((await receivables.account('ana')).balanceCents, 13000);
    expect(await receivables.netReceivedCents(), 5000);
    expect(await deliveries.soldCents(), 3000);
    expect(await montana('alho'), 4000);
  });

  test(
    'cash on the spot, a partial pix and change stay single effects',
    () async {
      await product(id: 'alho', name: 'Alho');
      await stock('alho', 3000);
      final cash = await draft(
        customerId: 'ana',
        dueOn: DateTime(2026, 12, 3),
        lines: [alho(productId: 'alho')],
      );
      await deliveries.confirm(
        noteId: cash.id,
        payment: DeliveryPayment(
          id: 'pay-cash',
          amountCents: 3000,
          tenderedCents: 5000,
          paidOn: '2026-11-03',
          method: PaymentMethod.cash,
          receivableIds: [saleReceivableId(cash.id)],
        ),
      );
      final pix = await draft(
        customerId: 'bia',
        dueOn: DateTime(2026, 12, 4),
        lines: [alho(productId: 'alho')],
      );
      final partial = await deliveries.confirm(
        noteId: pix.id,
        payment: DeliveryPayment(
          id: 'pay-pix',
          amountCents: 1000,
          paidOn: '2026-11-03',
          method: PaymentMethod.pix,
          receivableIds: [saleReceivableId(pix.id)],
        ),
      );

      final ana = await receivables.account('ana');
      expect(ana.balanceCents, 0);
      expect(ana.receipts.single.changeCents, 2000);
      expect(ana.receipts.single.creditCents, 0);
      expect(ana.receipts.single.method, PaymentMethod.cash);
      expect(partial.allocations.single.amountCents, 1000);
      expect((await receivables.account('bia')).balanceCents, 2000);
      expect(
        (await receivables.account('bia')).receipts.single.method,
        PaymentMethod.pix,
      );
      expect(await receivables.netReceivedCents(), 4000);
      expect(await deliveries.soldCents(), 6000);
    },
  );

  test(
    'two lines of the same product are summed before the balance check',
    () async {
      await product(id: 'alho', name: 'Alho');
      await stock('alho', 1000);
      final note = await draft(
        customerId: 'ana',
        dueOn: DateTime(2026, 12, 3),
        lines: [
          alho(grams: 600, productId: 'alho'),
          alho(grams: 600, productId: 'alho'),
        ],
      );

      await expectLater(
        deliveries.confirm(noteId: note.id),
        throwsA(
          isA<DeliveryException>().having(
            (error) => error.message,
            'message',
            contains('1,2 kg'),
          ),
        ),
      );
      expect(await montana('alho'), 1000);
      expect(await count('door_sales'), 0);
      expect(await count('receivables'), 0);
      expect((await notes.note(note.id)).status, NoteStatus.draft);
    },
  );

  test('inactive stock, a missing link and a box without conversion stop the delivery', () async {
    await product(id: 'alho', name: 'Alho', active: false);
    await stock('alho', 5000);
    final inactive = await draft(
      customerId: 'ana',
      dueOn: DateTime(2026, 12, 3),
      lines: [alho(productId: 'alho')],
    );
    await expectLater(
      deliveries.confirm(noteId: inactive.id),
      throwsA(
        isA<DeliveryException>().having(
          (error) => error.message,
          'message',
          contains('inativo'),
        ),
      ),
    );

    await (await db()).update(
      'products',
      {'active': 1},
      where: 'id = ?',
      whereArgs: ['alho'],
    );
    final loose = await draft(
      customerId: 'bia',
      dueOn: DateTime(2026, 12, 3),
      lines: [alho()],
    );
    await expectLater(
      deliveries.confirm(noteId: loose.id),
      throwsA(
        isA<DeliveryException>().having(
          (error) => error.message,
          'message',
          contains('não está ligado'),
        ),
      ),
    );

    final boxed = await draft(
      customerId: 'cia',
      dueOn: DateTime(2026, 12, 3),
      lines: [
        const NoteLineDraft(
          productId: 'alho',
          name: 'Alho',
          unit: CatalogUnit.box,
          quantity: 1,
          unitPriceCents: 3000,
        ),
      ],
    );
    await expectLater(
      deliveries.confirm(noteId: boxed.id),
      throwsA(
        isA<DeliveryException>().having(
          (error) => error.message,
          'message',
          contains('não há conversão'),
        ),
      ),
    );
    expect(await count('door_sales'), 0);
    expect(await montana('alho'), 5000);
  });

  test(
    'a failure inside the transaction leaves no sale, stock exit or debt',
    () async {
      await product(id: 'alho', name: 'Alho');
      await stock('alho', 1000);
      await receivables.openDebt(
        id: 'debt-ana',
        customerId: 'ana',
        amountCents: 15000,
      );
      final note = await draft(
        customerId: 'ana',
        dueOn: DateTime(2026, 12, 3),
        lines: [alho(productId: 'alho')],
      );
      deliveries.beforeCommit = () async {
        throw StateError('falha');
      };

      await expectLater(
        deliveries.confirm(
          noteId: note.id,
          payment: DeliveryPayment(
            id: 'pay-ana',
            amountCents: 1000,
            paidOn: '2026-11-03',
            method: PaymentMethod.pix,
            receivableIds: [saleReceivableId(note.id)],
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await montana('alho'), 1000);
      expect(await count('door_sales'), 0);
      expect(await count('customer_receipts'), 0);
      expect(await count('receivables'), 1);
      expect((await notes.note(note.id)).status, NoteStatus.draft);
      expect((await receivables.account('ana')).balanceCents, 15000);
    },
  );

  test('repeating the confirmation and reopening keep one sale', () async {
    await product(id: 'alho', name: 'Alho');
    await stock('alho', 1000);
    final note = await draft(
      customerId: 'ana',
      dueOn: DateTime(2026, 12, 3),
      lines: [alho(productId: 'alho')],
    );
    await deliveries.confirm(noteId: note.id);
    final again = await deliveries.confirm(noteId: note.id);
    final reopened = await notes.note(note.id);
    final fresh = await notes.activeDraft('ana');

    expect(again.alreadyRecorded, isTrue);
    expect(reopened.status, NoteStatus.delivered);
    expect(reopened.id, note.id);
    expect(fresh.id, isNot(note.id));
    expect(fresh.status, NoteStatus.draft);
    expect(fresh.lines, isEmpty);
    expect(await count('door_sales'), 1);
    expect(await count('movements'), 2);
    expect(await deliveries.soldCents(), 3000);
    await expectLater(
      notes.saveLines(
        noteId: note.id,
        lines: [alho(productId: 'alho')],
      ),
      throwsA(isA<NoteNotFoundException>()),
    );
  });

  test('a later catalog price does not change the delivered note', () async {
    await product(id: 'alho', name: 'Alho', price: 3000);
    await stock('alho', 1000);
    final note = await draft(
      customerId: 'ana',
      dueOn: DateTime(2026, 12, 3),
      lines: [alho(productId: 'alho', price: 3000)],
    );
    await deliveries.confirm(noteId: note.id);
    await (await db()).update(
      'products',
      {'sale_price_cents': 9999},
      where: 'id = ?',
      whereArgs: ['alho'],
    );

    final lines = await (await db()).query('door_sale_lines');
    expect(lines.single['unit_price_cents'], 3000);
    expect((await notes.note(note.id)).lines.single.unitPriceCents, 3000);
    expect(await deliveries.soldCents(), 3000);
  });

  test('credit is used only when the confirmation asks for it', () async {
    await product(id: 'alho', name: 'Alho');
    await stock('alho', 5000);
    await receivables.openDebt(
      id: 'debt-ana',
      customerId: 'ana',
      amountCents: 8000,
    );
    await receivables.confirmReceipt(
      id: 'pay-extra',
      customerId: 'ana',
      amountCents: 10000,
      paidOn: '2026-11-02',
      method: PaymentMethod.pix,
      allowCredit: true,
      receivableIds: const ['debt-ana'],
    );
    final kept = await draft(
      customerId: 'ana',
      dueOn: DateTime(2026, 12, 3),
      lines: [alho(productId: 'alho')],
    );
    await deliveries.confirm(noteId: kept.id);
    expect((await receivables.account('ana')).balanceCents, 3000);
    expect((await receivables.account('ana')).creditCents, 2000);

    final used = await draft(
      customerId: 'ana',
      dueOn: DateTime(2026, 12, 4),
      lines: [alho(productId: 'alho')],
    );
    await deliveries.confirm(
      noteId: used.id,
      payment: DeliveryPayment(
        id: 'pay-none',
        amountCents: 1000,
        paidOn: '2026-11-03',
        method: PaymentMethod.cash,
        applyCredit: true,
        receivableIds: [saleReceivableId(used.id)],
      ),
    );
    final account = await receivables.account('ana');
    expect(account.creditCents, 0);
    expect(account.balanceCents, 3000);
  });

  test(
    'a charge can use the remaining balance and a paid note stays out',
    () async {
      await product(id: 'alho', name: 'Alho');
      await stock('alho', 2000);
      final open = await draft(
        customerId: 'ana',
        dueOn: DateTime(2026, 12, 3),
        lines: [alho(productId: 'alho')],
      );
      await deliveries.confirm(
        noteId: open.id,
        payment: DeliveryPayment(
          id: 'pay-part',
          amountCents: 1000,
          paidOn: '2026-11-03',
          method: PaymentMethod.pix,
          receivableIds: [saleReceivableId(open.id)],
        ),
      );
      final paid = await draft(
        customerId: 'bia',
        dueOn: DateTime(2026, 12, 3),
        lines: [alho(productId: 'alho')],
      );
      await deliveries.confirm(
        noteId: paid.id,
        payment: DeliveryPayment(
          id: 'pay-full',
          amountCents: 3000,
          paidOn: '2026-11-03',
          method: PaymentMethod.pix,
          receivableIds: [saleReceivableId(paid.id)],
        ),
      );

      final ana = await receivables.account('ana');
      final sale = ana.openReceivables.single;
      expect(sale.openCents, 2000);
      final message = chargeMessage(
        customerName: 'Ana',
        description: chargeDescription(
          total: false,
          custom: false,
          receivableDescription: sale.description,
        ),
        amountCents: sale.openCents,
        dueOn: sale.dueOn,
        pixKey: '11988887777',
        receiverName: 'Hortifruti da Ana',
      );
      expect(message, contains('R\$ 20,00'));
      await receivables.prepareCharge(
        id: 'charge-ana',
        customerId: 'ana',
        amountCents: sale.openCents,
        description: 'restante',
        message: message,
        phone: '5511988887777',
      );
      expect(await receivables.netReceivedCents(), 4000);
      expect((await receivables.account('bia')).openReceivables, isEmpty);
      expect(await montana('alho'), 0);
    },
  );

  test('an older catalog keeps the stock, the draft and the opening debt', () async {
    final directory = Directory.systemTemp.createTempSync('pouapp-delivery');
    final path = '${directory.path}/catalog.db';
    addTearDown(() async {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final legacy = await openDatabase(
      path,
      version: 4,
      onCreate: (database, version) async {
        await database.execute('''
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
        await database.execute('''
          CREATE TABLE product_minimums (
            product_id TEXT NOT NULL,
            location_code TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            PRIMARY KEY (product_id, location_code)
          )
        ''');
        await database.execute('''
          CREATE TABLE movements (
            id TEXT PRIMARY KEY,
            product_id TEXT NOT NULL,
            location_code TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            kind TEXT NOT NULL,
            reason TEXT,
            occurred_on TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            idempotency_key TEXT NOT NULL UNIQUE,
            operation_id TEXT
          )
        ''');
        await database.execute('''
          CREATE TABLE app_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await createOperationalTables(database);
        await createStockOperationTables(database);
        await createReceivableTables(database);
      },
    );
    await legacy.insert('products', {
      'id': 'alho',
      'name': 'Alho',
      'category': null,
      'sku': null,
      'unit': 'kilogram',
      'active': 1,
      'sale_price_cents': 3000,
      'sort_index': 0,
      'created_at': '2026-08-01T00:00:00.000',
      'updated_at': '2026-08-01T00:00:00.000',
    });
    await legacy.insert('movements', {
      'id': 'opening-alho',
      'product_id': 'alho',
      'location_code': 'montana',
      'quantity': 2000,
      'kind': 'opening',
      'reason': 'Saldo inicial',
      'occurred_on': '2026-08-01',
      'recorded_at': '2026-08-01T00:00:00.000',
      'idempotency_key': 'opening:alho:montana',
    });
    await legacy.insert('customer_notes', {
      'id': 'note-antiga',
      'customer_id': 'ana',
      'status': 'draft',
      'due_on': '2026-08-15',
      'created_at': '2026-08-01T00:00:00.000',
      'updated_at': '2026-08-01T00:00:00.000',
    });
    await legacy.insert('receivables', {
      'id': 'debt-antiga',
      'customer_id': 'ana',
      'kind': 'opening',
      'description': 'Saldo inicial',
      'amount_cents': 15000,
      'due_on': '2026-08-20',
      'occurred_on': '2026-08-01',
      'recorded_at': '2026-08-01T00:00:00.000',
    });
    await legacy.close();

    final upgraded = CatalogLocalDataSourceImpl(
      databasePath: path,
      seedDemo: false,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'upgrade-id',
    );
    addTearDown(upgraded.close);
    final store = DeliveryStore(
      openDatabase: upgraded.database,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'upgrade-move',
    );
    final noteStore = CustomerNoteLocalDataSourceImpl(
      openDatabase: upgraded.database,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'upgrade-note',
    );
    final current = await noteStore.openNote('ana');
    expect(current.id, 'note-antiga');
    await noteStore.saveLines(
      noteId: current.id,
      lines: [alho(productId: 'alho')],
    );
    await store.confirm(noteId: current.id);
    final database = await upgraded.database();
    final version = Sqflite.firstIntValue(
      await database.rawQuery('PRAGMA user_version'),
    );
    final opening = await database.query(
      'movements',
      where: 'id = ?',
      whereArgs: ['opening-alho'],
    );
    final debt = await database.query(
      'receivables',
      where: 'id = ?',
      whereArgs: ['debt-antiga'],
    );

    expect(version, catalogDatabaseVersion);
    expect(opening.single['quantity'], 2000);
    expect(debt.single['due_on'], '2026-08-20');
    expect(debt.single['amount_cents'], 15000);
    final saleMoves = await database.query(
      'movements',
      where: 'kind = ?',
      whereArgs: ['sale'],
    );
    expect(saleMoves.single['quantity'], -1000);
  });
}
