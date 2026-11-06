import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/data/datasources/customer_local_data_source.dart';
import 'package:pouapp/features/customers/data/datasources/customer_note_local_data_source.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_local_data_source.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_simulated_data_source.dart';
import 'package:pouapp/features/workspace/data/models/street_ledger_codec.dart';
import 'package:pouapp/features/workspace/data/operation_store.dart';
import 'package:pouapp/features/workspace/data/repositories/workspace_repository_impl.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:pouapp/features/workspace/domain/rules/company_indicators.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test(
    'imports a filled street ledger once, then records on the new source',
    () async {
      final directory = Directory.systemTemp.createTempSync('pouapp-operation');
      final customers = CustomerLocalDataSourceImpl(
        databasePath: '${directory.path}/customers.db',
        seedDemo: false,
        newId: () => 'customer-ana',
      );
      final catalog = CatalogLocalDataSourceImpl(
        databasePath: '${directory.path}/catalog.db',
        seedDemo: false,
        newId: () => 'product-alface',
      );
      addTearDown(() async {
        await customers.close();
        await catalog.close();
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });

      final ana = await customers.createCustomer(
        const CustomerInput(type: CustomerType.individual, name: 'Ana'),
      );
      final notes = CustomerNoteLocalDataSourceImpl(
        openDatabase: customers.database,
        clock: () => DateTime.utc(2026, 8, 1),
        newId: () => 'note-ana',
      );
      final draft = await notes.activeDraft(ana.id);
      await notes.saveLines(
        noteId: draft.id,
        lines: const [
          NoteLineDraft(
            id: 'line-ana',
            productId: 'product-banana',
            name: 'Banana nanica',
            unit: CatalogUnit.kilogram,
            quantity: 1500,
            unitPriceCents: 1000,
          ),
        ],
      );
      await notes.setDueOn(noteId: draft.id, dueOn: DateTime.utc(2026, 8, 15));
      await catalog.createProduct(
        const ProductDraft(
          name: 'Alface crespa',
          unit: CatalogUnit.piece,
          salePriceCents: 350,
          openingLocation: StockLocationCode.warehouse,
          openingQuantity: 5,
        ),
      );

      const ledger = StreetLedger(
        day: '2026-08-01',
        nextNumber: 2000,
        visits: [
          RouteVisit(
            id: 'visit-real',
            customerId: 'customer-ana',
            customerName: 'Ana',
            address: 'Rua A, 1',
            reasons: [VisitReason.sale],
            status: VisitStatus.pending,
            position: 0,
            day: '2026-08-01',
          ),
        ],
        orders: [
          SaleOrder(
            id: 'order-real',
            code: '200',
            customerId: 'customer-ana',
            customerName: 'Ana',
            lines: [
              SaleLine(
                productName: 'Alface crespa',
                quantity: 2,
                unit: SaleUnit.bunch,
                unitPriceCents: 350,
              ),
            ],
            recorded: true,
            delivered: false,
            revisions: [
              SaleRevision(
                lines: [
                  SaleLine(
                    productName: 'Alface crespa',
                    quantity: 1,
                    unit: SaleUnit.bunch,
                    unitPriceCents: 350,
                  ),
                ],
              ),
            ],
          ),
          SaleOrder(
            id: 'order-empty',
            code: '201',
            customerId: 'customer-ana',
            customerName: 'Ana',
            lines: [],
            recorded: true,
            delivered: false,
          ),
          SaleOrder(
            id: 'order-seed',
            code: '1042',
            customerId: 'customer-ana',
            customerName: 'Ana',
            lines: [
              SaleLine(
                productName: 'Banana nanica',
                quantity: 10,
                unit: SaleUnit.kilogram,
                unitPriceCents: 1864,
              ),
            ],
            recorded: true,
            delivered: false,
            fromSeed: true,
          ),
        ],
        payments: [
          CustomerPayment(
            id: 'pay-loose',
            customerId: 'customer-ana',
            amountCents: 5000,
            paidOn: '2026-08-02',
            method: PaymentMethod.pix,
          ),
          CustomerPayment(
            id: 'pay-seed',
            customerId: 'customer-ana',
            amountCents: 7200,
            paidOn: '2026-08-02',
            method: PaymentMethod.cash,
            fromSeed: true,
            shares: [PaymentShare(orderId: 'order-seed', amountCents: 7200)],
          ),
        ],
        agreements: [
          PaymentAgreement(
            id: 'agree-ana',
            customerId: 'customer-ana',
            agreedOn: '2026-08-20',
          ),
        ],
      );
      final origin = encodeStreetLedger(ledger);
      SharedPreferences.setMockInitialValues({
        streetLedgerKey: origin,
        'freight_ledger': 'frete-intacto',
      });
      final preferences = await SharedPreferences.getInstance();
      final local = WorkspaceLocalDataSourceImpl(
        sharedPreferences: preferences,
      );

      OperationStore buildStore() {
        return OperationStore(
          openDatabase: catalog.database,
          readStreetOrigin: local.readStreetLedger,
          openCustomerDatabase: customers.database,
          clock: () => DateTime.utc(2026, 11, 3, 15, 4, 5),
        );
      }

      final failing = buildStore();
      failing.beforeCommit = () =>
          throw const OperationImportException('parada');
      await expectLater(
        failing.ensureActive(),
        throwsA(isA<OperationImportException>()),
      );
      final database = await catalog.database();
      expect(await failing.isActive(), isFalse);
      expect(await _count(database, 'street_orders'), 0);
      expect(await _count(database, 'customer_notes'), 0);
      expect(await _count(database, 'operation_import'), 0);
      expect(preferences.getString(streetLedgerKey), origin);
      expect(await _count(await customers.database(), 'customer_notes'), 1);

      final store = buildStore();
      await store.ensureActive();
      await store.ensureActive();
      expect(await store.isActive(), isTrue);
      expect(await _count(database, 'street_orders'), 3);
      expect(await _count(database, 'street_order_lines'), 3);
      expect(await _count(database, 'street_payments'), 2);
      expect(await _count(database, 'street_payment_shares'), 1);
      expect(await _count(database, 'operation_import'), 1);
      expect(preferences.getString(streetLedgerKey), origin);
      expect(preferences.getString('freight_ledger'), 'frete-intacto');

      final imported = await store.readLedger();
      final real = imported.orders.singleWhere(
        (order) => order.id == 'order-real',
      );
      expect(real.occurredOn, isNull);
      expect(real.recordedAt, isNull);
      expect(real.legacy, isTrue);
      expect(real.lines.single.productName, 'Alface crespa');
      expect(real.revisions.single.lines.single.quantity, 1);
      expect(
        imported.orders.singleWhere((order) => order.id == 'order-empty').lines,
        isEmpty,
      );
      expect(
        imported.orders
            .singleWhere((order) => order.id == 'order-seed')
            .fromSeed,
        isTrue,
      );
      final loose = imported.payments.singleWhere(
        (payment) => payment.id == 'pay-loose',
      );
      expect(loose.shares, isEmpty);
      expect(loose.paidOn, '2026-08-02');
      expect(loose.legacy, isTrue);
      expect(imported.visits.single.day, '2026-08-01');
      expect(imported.agreements.single.agreedOn, '2026-08-20');
      final lines = await database.query(
        'street_order_lines',
        where: 'order_id = ?',
        whereArgs: const ['order-real'],
      );
      expect(lines.every((line) => line['product_id'] == null), isTrue);

      final indicators = CompanyIndicators.fromLedger(imported);
      expect(indicators.soldCents, 700);
      expect(indicators.receivedCents, 5000);
      expect(CompanyIndicators.soldScope, 'Todos os registros');

      final catalogNotes = await database.query('customer_notes');
      expect(catalogNotes.single['id'], draft.id);
      expect(catalogNotes.single['status'], 'draft');
      expect(catalogNotes.single['due_on'], '2026-08-15');
      final catalogLines = await database.query('customer_note_lines');
      expect(catalogLines.single['id'], 'line-ana');
      expect(catalogLines.single['quantity'], 1500);
      expect(catalogLines.single['unit_price_cents'], 1000);
      expect(imported.orders.every((order) => order.id != draft.id), isTrue);

      expect(await _count(database, 'movements'), 1);
      expect((await database.query('movements')).single['quantity'], 5);

      await catalog.close();
      final reopenedCatalog = CatalogLocalDataSourceImpl(
        databasePath: '${directory.path}/catalog.db',
        seedDemo: false,
      );
      addTearDown(reopenedCatalog.close);
      final reopened = OperationStore(
        openDatabase: reopenedCatalog.database,
        readStreetOrigin: local.readStreetLedger,
        openCustomerDatabase: customers.database,
      );
      await reopened.ensureActive();
      expect((await reopened.readLedger()).orders, hasLength(3));
      expect(preferences.getString(streetLedgerKey), origin);

      final repository = WorkspaceRepositoryImpl(
        localDataSource: local,
        simulatedDataSource: WorkspaceSimulatedDataSource(),
        operationStore: reopened,
        clock: () => DateTime.utc(2026, 11, 3, 15, 4, 5),
      );
      final saved = await repository.applyStreetChange(
        const SaveSale(
          visitId: 'visit-real',
          customerId: 'customer-ana',
          customerName: 'Ana',
          lines: [
            SaleLine(
              productName: 'Couve',
              quantity: 1,
              unit: SaleUnit.piece,
              unitPriceCents: 100,
            ),
          ],
        ),
      );
      saved.fold((_) => fail('expected to save'), (operation) {
        expect(operation.summary.soldCents, 800);
      });
      final active = await reopened.readLedger();
      final created = active.orders.singleWhere(
        (order) => order.code == '2000',
      );
      expect(created.occurredOn, '2026-11-03');
      expect(created.recordedAt, '2026-11-03T15:04:05.000Z');
      expect(created.legacy, isFalse);
      final kept = active.orders.singleWhere(
        (order) => order.id == 'order-real',
      );
      expect(kept.occurredOn, isNull);
      expect(kept.legacy, isTrue);
      expect(preferences.getString(streetLedgerKey), origin);
      final reopenedDatabase = await reopenedCatalog.database();
      expect(await _count(reopenedDatabase, 'movements'), 1);
      expect(await _count(reopenedDatabase, 'street_orders'), 4);

      await expectLater(
        reopenedDatabase.transaction((txn) async {
          await txn.insert('street_orders', {
            'id': 'order-rollback',
            'code': '9',
            'customer_id': 'customer-ana',
            'customer_name': 'Ana',
            'recorded': 1,
            'delivered': 0,
            'from_seed': 0,
            'legacy': 0,
          });
          await txn.insert('customer_notes', {
            'id': 'note-rollback',
            'customer_id': 'customer-other',
            'status': 'draft',
            'created_at': '2026-11-03T00:00:00.000Z',
            'updated_at': '2026-11-03T00:00:00.000Z',
          });
          await txn.insert('movements', {
            'id': 'move-rollback',
            'product_id': 'product-alface',
            'location_code': 'warehouse',
            'quantity': 1,
            'kind': 'opening',
            'occurred_on': '2026-11-03',
            'recorded_at': '2026-11-03T00:00:00.000Z',
            'idempotency_key': 'rollback-test',
          });
          throw StateError('rollback');
        }),
        throwsA(isA<StateError>()),
      );
      expect(await _count(reopenedDatabase, 'street_orders'), 4);
      expect(await _count(reopenedDatabase, 'customer_notes'), 1);
      expect(await _count(reopenedDatabase, 'movements'), 1);
      expect(
        await reopenedDatabase.query(
          'customer_notes',
          where: 'id = ?',
          whereArgs: const ['note-ana'],
        ),
        isNotEmpty,
      );
    },
  );
}

Future<int> _count(Database database, String table) async {
  return Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM $table'),
      ) ??
      0;
}
