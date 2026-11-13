import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/data/datasources/customer_local_data_source.dart';
import 'package:pouapp/features/customers/data/datasources/customer_note_local_data_source.dart';
import 'package:pouapp/features/customers/data/repositories/customer_note_repository_impl.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';
import 'package:pouapp/features/customers/domain/repositories/customer_note_repository.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late CustomerLocalDataSourceImpl customers;
  late CustomerNoteRepository notes;
  var noteSequence = 0;
  var ticks = 0;

  setUp(() {
    noteSequence = 0;
    ticks = 0;
    directory = Directory.systemTemp.createTempSync('pouapp-note');
    customers = CustomerLocalDataSourceImpl(
      databasePath: '${directory.path}/customers.db',
      seedDemo: false,
      clock: () => DateTime.utc(2026, 6, 1),
      newId: () => 'customer-${noteSequence++}',
    );
    notes = CustomerNoteRepositoryImpl(
      localDataSource: CustomerNoteLocalDataSourceImpl(
        openDatabase: customers.database,
        clock: () => DateTime.utc(2026, 6, 2, 0, 0, ticks++),
        newId: () => 'note-${noteSequence++}',
      ),
    );
  });

  tearDown(() async {
    await customers.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('keeps one draft per customer across a reopened database', () async {
    final ana = await customers.createCustomer(
      const CustomerInput(type: CustomerType.individual, name: 'Ana'),
    );
    final bia = await customers.createCustomer(
      const CustomerInput(type: CustomerType.individual, name: 'Bia'),
    );

    final anaDraft = _take(await notes.activeDraft(ana.id));
    final biaDraft = _take(await notes.activeDraft(bia.id));
    expect(anaDraft.lines, isEmpty);
    expect(biaDraft.lines, isEmpty);
    expect(anaDraft.id, isNot(biaDraft.id));
    expect(anaDraft.totalCents, 0);

    final saved = _take(
      await notes.saveLines(
        noteId: anaDraft.id,
        lines: const [
          NoteLineDraft(
            productId: 'product-banana',
            name: 'Banana nanica',
            unit: CatalogUnit.kilogram,
            quantity: 1500,
            unitPriceCents: 1000,
          ),
          NoteLineDraft(
            productId: 'product-tomate',
            name: 'Tomate italiano',
            unit: CatalogUnit.box,
            quantity: 2,
            unitPriceCents: 400,
          ),
          NoteLineDraft(
            productId: 'product-alface',
            name: 'Alface crespa',
            unit: CatalogUnit.piece,
            quantity: 3,
            unitPriceCents: 200,
          ),
        ],
      ),
    );
    expect(saved.id, anaDraft.id);
    expect(saved.createdAt, anaDraft.createdAt);
    expect(saved.updatedAt.isAfter(saved.createdAt), isTrue);
    expect(saved.totalCents, 2900);
    expect(saved.lines[1].unit, CatalogUnit.box);
    expect(saved.lines[1].quantity, 2);
    expect(saved.lines.first.unitPriceCents, 1000);

    final dated = _take(
      await notes.setDueOn(noteId: anaDraft.id, dueOn: DateTime(2026, 11, 15)),
    );
    expect(dated.id, anaDraft.id);
    expect(dated.dueOn, DateTime(2026, 11, 15));

    final paid = _take(
      await notes.setPaymentMethod(
        noteId: anaDraft.id,
        paymentMethod: PaymentMethod.cash,
      ),
    );
    expect(paid.paymentMethod, PaymentMethod.cash);

    final rejected = await notes.saveLines(
      noteId: anaDraft.id,
      lines: const [
        NoteLineDraft(
          name: 'Alface crespa',
          unit: CatalogUnit.piece,
          quantity: 0,
          unitPriceCents: 200,
        ),
      ],
    );
    expect(rejected.isLeft(), isTrue);

    await customers.close();
    customers = CustomerLocalDataSourceImpl(
      databasePath: '${directory.path}/customers.db',
      seedDemo: false,
    );
    notes = CustomerNoteRepositoryImpl(
      localDataSource: CustomerNoteLocalDataSourceImpl(
        openDatabase: customers.database,
      ),
    );

    final reopened = _take(await notes.activeDraft(ana.id));
    expect(reopened.id, anaDraft.id);
    expect(reopened.lines, hasLength(3));
    expect(reopened.lines.first.productId, 'product-banana');
    expect(reopened.lines.first.name, 'Banana nanica');
    expect(reopened.lines.first.quantity, 1500);
    expect(reopened.lines.first.unitPriceCents, 1000);
    expect(reopened.lines[1].unit, CatalogUnit.box);
    expect(reopened.dueOn, DateTime(2026, 11, 15));
    expect(reopened.paymentMethod, PaymentMethod.cash);
    expect(reopened.totalCents, 2900);

    final edited = _take(
      await notes.saveLines(
        noteId: reopened.id,
        lines: [
          NoteLineDraft(
            id: reopened.lines.first.id,
            productId: reopened.lines.first.productId,
            name: reopened.lines.first.name,
            unit: CatalogUnit.kilogram,
            quantity: 1000,
            unitPriceCents: 500,
          ),
          NoteLineDraft.fromLine(reopened.lines[1]),
          NoteLineDraft.fromLine(reopened.lines[2]),
        ],
      ),
    );
    expect(edited.id, anaDraft.id);
    expect(edited.lines, hasLength(3));
    expect(edited.lines.first.unitPriceCents, 500);
    expect(edited.totalCents, 1900);

    final other = _take(await notes.activeDraft(bia.id));
    expect(other.id, biaDraft.id);
    expect(other.lines, isEmpty);
    expect(other.totalCents, 0);

    final db = await customers.database();
    final people = await db.query('customers', columns: ['id']);
    expect(people, hasLength(2));
    final statuses = await db.query('customer_notes', columns: ['status']);
    expect(statuses.map((row) => row['status']), everyElement('draft'));
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = [
      for (final row in tables)
        if (!(row['name'] as String).startsWith('sqlite_') &&
            row['name'] != 'android_metadata')
          row['name'] as String,
    ]..sort();
    expect(names, [
      'app_meta',
      'customer_addresses',
      'customer_contacts',
      'customer_note_lines',
      'customer_notes',
      'customers',
      'pending_sync',
    ]);
  });

  test('keeps a single open draft per customer after duplicates', () async {
    final ana = await customers.createCustomer(
      const CustomerInput(type: CustomerType.individual, name: 'Ana'),
    );
    final first = _take(await notes.activeDraft(ana.id));
    expect(_take(await notes.activeDraft(ana.id)).id, first.id);

    final saved = _take(
      await notes.saveLines(
        noteId: first.id,
        lines: const [
          NoteLineDraft(
            name: 'Banana nanica',
            unit: CatalogUnit.kilogram,
            quantity: 1000,
            unitPriceCents: 2870,
          ),
        ],
      ),
    );
    expect(saved.totalCents, 2870);
    _take(await notes.setDueOn(noteId: first.id, dueOn: DateTime(2026, 11, 11)));

    final db = await customers.database();
    await db.execute('DROP INDEX IF EXISTS idx_customer_notes_one_draft');
    await db.insert('customer_notes', {
      'id': 'orphan-draft',
      'customer_id': ana.id,
      'status': 'draft',
      'due_on': '2026-11-10',
      'created_at': '2026-06-01T00:00:00.000Z',
      'updated_at': '2026-06-01T00:00:00.000Z',
    });
    await db.insert('customer_note_lines', {
      'id': 'orphan-line',
      'note_id': 'orphan-draft',
      'position': 0,
      'name': 'Banana nanica',
      'unit': 'kilogram',
      'quantity': 1000,
      'unit_price_cents': 2870,
      'reference_price_cents': 2870,
    });

    final listed = (await notes.draftNotesWithDue()).fold(
      (failure) => throw StateError('$failure'),
      (value) => value,
    );
    expect(listed, hasLength(1));
    expect(listed.single.id, first.id);
    expect(listed.single.totalCents, 2870);
    expect(listed.single.dueOn, DateTime(2026, 11, 11));

    final drafts = await db.query(
      'customer_notes',
      where: 'customer_id = ? AND status = ?',
      whereArgs: [ana.id, 'draft'],
    );
    expect(drafts, hasLength(1));
    expect(drafts.single['id'], first.id);
  });

  test('empty open draft is not treated as a cleared home due', () async {
    final maria = await customers.createCustomer(
      const CustomerInput(type: CustomerType.individual, name: 'Maria'),
    );
    _take(await notes.openNote(maria.id));

    final cleared = (await notes.clearedDraftCustomerIds()).fold(
      (failure) => throw StateError('$failure'),
      (value) => value,
    );
    expect(cleared.contains(maria.id), isFalse);
  });

  test('soft-deletes a draft and lists it under deleted notes', () async {
    final ana = await customers.createCustomer(
      const CustomerInput(type: CustomerType.individual, name: 'Ana'),
    );
    final draft = _take(await notes.activeDraft(ana.id));
    _take(
      await notes.saveLines(
        noteId: draft.id,
        lines: const [
          NoteLineDraft(
            productId: 'product-banana',
            name: 'Banana',
            unit: CatalogUnit.kilogram,
            quantity: 1000,
            unitPriceCents: 500,
          ),
        ],
      ),
    );

    final next = _take(await notes.deleteNote(draft.id));
    expect(next.id, isNot(draft.id));
    expect(next.status, NoteStatus.draft);
    expect(next.lines, isEmpty);

    final deleted = (await notes.deletedNotes(ana.id)).fold(
      (failure) => throw StateError('$failure'),
      (value) => value,
    );
    expect(deleted, hasLength(1));
    expect(deleted.single.id, draft.id);
    expect(deleted.single.status, NoteStatus.deleted);
    expect(deleted.single.lines, hasLength(1));
    expect(deleted.single.totalCents, 500);

    final open = _take(await notes.openNote(ana.id));
    expect(open.id, next.id);
    expect(open.lines, isEmpty);
  });

  test(
    'upgrades version 1 without dropping customers or inventing lines',
    () async {
      await customers.close();
      final path = '${directory.path}/legacy.db';
      final legacy = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) => createCustomerTables(db),
      );
      await legacy.insert('customers', {
        'id': 'cust-old',
        'type': 'individual',
        'name': 'Cliente antiga',
        'status': 'active',
        'external_source': 'local',
        'search_name': 'cliente antiga',
        'search_trade_name': '',
        'search_phones': '',
        'search_document': '',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      await legacy.close();

      customers = CustomerLocalDataSourceImpl(
        databasePath: path,
        seedDemo: false,
      );
      notes = CustomerNoteRepositoryImpl(
        localDataSource: CustomerNoteLocalDataSourceImpl(
          openDatabase: customers.database,
          newId: () => 'draft-old',
        ),
      );

      final person = await customers.getCustomerById('cust-old');
      expect(person.name, 'Cliente antiga');
      final draft = _take(await notes.activeDraft('cust-old'));
      expect(draft.id, 'draft-old');
      expect(draft.lines, isEmpty);
      expect(draft.status, NoteStatus.draft);

      final db = await customers.database();
      final version = await db.rawQuery('PRAGMA user_version');
      expect(version.single.values.single, customerDatabaseVersion);
      final again = _take(await notes.activeDraft('cust-old'));
      expect(again.id, draft.id);
      expect(again.lines, isEmpty);
    },
  );
}

CustomerNote _take(Either<Failure, CustomerNote> result) {
  return result.fold(
    (Failure failure) => throw StateError('$failure'),
    (CustomerNote note) => note,
  );
}
