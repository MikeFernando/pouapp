import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/assistant/data/voice_repository_impl.dart';
import 'package:pouapp/features/workspace/data/delivery_store.dart';
import 'package:pouapp/features/assistant/domain/entities/voice_command.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/data/datasources/customer_local_data_source.dart';
import 'package:pouapp/features/customers/data/datasources/customer_note_local_data_source.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';
import 'package:pouapp/features/customers/data/repositories/customer_note_repository_impl.dart';
import 'package:pouapp/features/workspace/data/receivable_store.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  late Directory customerDir;
  late CustomerLocalDataSourceImpl customers;
  late CatalogLocalDataSourceImpl catalogData;
  late VoiceRepositoryImpl voice;
  late ReceivableStore receivables;

  setUp(() {
    customerDir = Directory.systemTemp.createTempSync('pouapp-voice');
    customers = CustomerLocalDataSourceImpl(
      databasePath: '${customerDir.path}/customers.db',
      seedDemo: false,
    );
    var noteIds = 0;
    var ticks = 0;
    catalogData = CatalogLocalDataSourceImpl(
      databasePath: inMemoryDatabasePath,
      seedDemo: false,
      clock: () => DateTime(2026, 11, 4, 9, 0, ticks++),
      newId: () => 'catalog-voice',
    );
    receivables = ReceivableStore(
      openDatabase: catalogData.database,
      clock: () => DateTime(2026, 11, 4, 9),
      newId: () => 'money-voice',
    );
    var voiceTicks = 0;
    var movementIds = 0;
    voice = VoiceRepositoryImpl(
      customers: customers,
      catalog: CatalogRepositoryImpl(localDataSource: catalogData),
      notes: CustomerNoteRepositoryImpl(
        localDataSource: CustomerNoteLocalDataSourceImpl(
          openDatabase: catalogData.database,
          clock: () => DateTime(2026, 11, 4, 9),
          newId: () => 'note-voice-${noteIds++}',
        ),
      ),
      receivables: receivables,
      deliveries: DeliveryStore(
        openDatabase: catalogData.database,
        clock: () => DateTime(2026, 11, 4, 9),
        newId: () => 'move-${movementIds++}',
      ),
      openCatalog: catalogData.database,
      clock: () => DateTime(2026, 11, 4, 9, 0, voiceTicks++),
    );
  });

  tearDown(() async {
    await customers.close();
    await catalogData.close();
    customerDir.deleteSync(recursive: true);
  });

  Future<Database> catalogDb() => catalogData.database();

  Future<void> person({
    required String id,
    required String name,
    required String neighborhood,
  }) async {
    final db = await customers.database();
    await db.insert('customers', {
      'id': id,
      'type': 'individual',
      'name': name,
      'status': 'active',
      'external_source': 'local',
      'search_name': name.toLowerCase(),
      'search_trade_name': '',
      'search_phones': '',
      'search_document': '',
      'created_at': '2026-11-04T09:00:00.000',
      'updated_at': '2026-11-04T09:00:00.000',
    });
    await db.insert('customer_addresses', {
      'id': 'address-$id',
      'customer_id': id,
      'label': 'Casa',
      'street': 'Rua 1',
      'number': '10',
      'neighborhood': neighborhood,
      'city': 'Apiaí',
      'state': 'PR',
      'is_primary': 1,
    });
  }

  Future<void> product({
    required String id,
    required String name,
    CatalogUnit unit = CatalogUnit.kilogram,
    int price = 450,
  }) async {
    await (await catalogDb()).insert('products', {
      'id': id,
      'name': name,
      'unit': unit.name,
      'active': 1,
      'sale_price_cents': price,
      'sort_index': 0,
      'created_at': '2026-11-04T09:00:00.000',
      'updated_at': '2026-11-04T09:00:00.000',
    });
  }

  var requests = 0;

  Future<VoiceOutcome> say(
    String text, {
    String? executionId,
    VoiceCommand? pending,
    String? choice,
    String? contextCustomerId,
    String? contextLabel,
    bool contextFresh = false,
    DateTime? today,
  }) {
    return voice
        .submit(
          transcript: text,
          executionId: executionId ?? 'request-${requests++}',
          pending: pending,
          choiceId: choice,
          today: today ?? DateTime(2026, 11, 4),
          contextCustomerId: contextCustomerId,
          contextLabel: contextLabel,
          contextFresh: contextFresh,
        )
        .then(
          (result) => result.fold((failure) => throw failure, (value) => value),
        );
  }

  test('Adriele JP is the customer in Jardim Paraíso', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    await person(id: 'other', name: 'Adriele Lima', neighborhood: 'Centro');
    await product(id: 'abacaxi', name: 'Abacaxi');

    final outcome = await say('Adicione um quilo de abacaxi para Adriele JP.');

    expect(outcome.kind, VoiceOutcomeKind.completed);
    expect(outcome.message, contains('Adriele Souza'));
    expect(outcome.message, contains('ainda não é uma venda'));
    final db = await catalogDb();
    final lines = await db.query('customer_note_lines');
    expect(lines, hasLength(1));
    expect(lines.single['quantity'], 1000);
    expect(lines.single['unit_price_cents'], 450);
    expect(lines.single['product_id'], 'abacaxi');
    expect(await db.query('receivables'), isEmpty);
    expect(await db.query('movements'), isEmpty);
    expect(await db.query('door_sales'), isEmpty);
  });

  test(
    'two Marias need a choice and the draft is not part of the debt',
    () async {
      await person(id: 'souza', name: 'Maria Souza', neighborhood: 'Centro');
      await person(id: 'lima', name: 'Maria Lima', neighborhood: 'Vila Nova');
      await receivables.openDebt(
        id: 'debt-souza',
        customerId: 'souza',
        amountCents: 15000,
        dueOn: '2026-10-01',
      );
      final asked = await say('Quanto a Maria me deve?');
      expect(asked.kind, VoiceOutcomeKind.clarify);
      expect(asked.choices, hasLength(2));

      final account = await say(
        'Quanto a Maria me deve?',
        pending: asked.command,
        choice: 'customer:souza',
      );
      expect(account.account!.name, 'Maria Souza');
      expect(account.account!.balanceCents, 15000);
      expect(account.account!.overdueCents, 15000);
      expect(account.account!.notes.single.legacyWithoutItems, isTrue);

      await product(id: 'abacaxi', name: 'Abacaxi');
      await say('Adicione um quilo de abacaxi para Maria Souza.');
      final again = await say(
        'Quanto a Maria me deve?',
        pending: asked.command,
        choice: 'customer:souza',
      );
      expect(again.account!.balanceCents, 15000);
      expect(await (await catalogDb()).query('receivables'), hasLength(1));
    },
  );

  test('MT is unknown until an abbreviation is saved', () async {
    await person(id: 'souza', name: 'Maria Souza', neighborhood: 'Centro');
    await person(id: 'lima', name: 'Maria Lima', neighborhood: 'Monte Tabor');
    final unknown = await say('Quanto a Maria MT me deve?');
    expect(unknown.kind, VoiceOutcomeKind.clarify);
    expect(unknown.choices, isEmpty);
    expect(unknown.message, contains('abreviação'));

    final saved = await voice.saveAlias(
      kind: VoiceAliasKind.neighborhood,
      alias: 'MT',
      target: 'Monte Tabor',
    );
    expect(saved.isRight(), isTrue);
    final found = await say('Quanto a Maria MT me deve?');
    expect(found.account!.customerId, 'lima');
  });

  test('a missing customer or product asks and writes nothing', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    await product(id: 'abacaxi', name: 'Abacaxi');
    final missingCustomer = await say(
      'Adicione um quilo de abacaxi para Zilda.',
    );
    final missingProduct = await say(
      'Adicione um quilo de uva para Adriele JP.',
    );
    expect(missingCustomer.message, contains('cliente'));
    expect(missingProduct.message, contains('produto'));
    expect(await (await catalogDb()).query('customer_notes'), isEmpty);
  });

  test('a kilogram is refused when the product is sold by unit', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    await product(id: 'banana', name: 'Banana nanica', unit: CatalogUnit.dozen);
    final outcome = await say('Adicione um quilo de banana para Adriele JP.');
    expect(outcome.kind, VoiceOutcomeKind.clarify);
    expect(outcome.message, contains('dúzia'));
    expect(await (await catalogDb()).query('customer_notes'), isEmpty);
  });

  test('the same execution is saved once and a new one adds again', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    await product(id: 'abacaxi', name: 'Abacaxi', price: 450);

    const phrase = 'Adicione um quilo de abacaxi para Adriele JP.';
    final first = await say(phrase, executionId: 'exec-1');
    final again = await say(phrase, executionId: 'exec-1');
    expect(first.kind, VoiceOutcomeKind.completed);
    expect(again.kind, VoiceOutcomeKind.repeated);
    final db = await catalogDb();
    expect((await db.query('customer_note_lines')).single['quantity'], 1000);

    final second = await say(phrase, executionId: 'exec-2');
    expect(second.kind, VoiceOutcomeKind.completed);
    expect((await db.query('customer_note_lines')).single['quantity'], 2000);

    final undone = await voice.undo(second.executionId!);
    expect(
      undone.fold((failure) => throw failure, (value) => value).kind,
      VoiceOutcomeKind.undone,
    );
    expect((await db.query('customer_note_lines')).single['quantity'], 1000);
  });

  test('undo restores the quantity a line already had', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    await product(id: 'abacaxi', name: 'Abacaxi', price: 9900);
    final notes = CustomerNoteLocalDataSourceImpl(
      openDatabase: catalogData.database,
      clock: () => DateTime(2026, 11, 4, 9),
      newId: () => 'manual-note',
    );
    final draft = await notes.activeDraft('adriele');
    await notes.saveLines(
      noteId: draft.id,
      lines: const [
        NoteLineDraft(
          id: 'abacaxi-line',
          productId: 'abacaxi',
          name: 'Abacaxi',
          unit: CatalogUnit.kilogram,
          quantity: 500,
          unitPriceCents: 3000,
        ),
      ],
    );

    final added = await say(
      'Adicione um quilo de abacaxi para Adriele JP.',
      executionId: 'exec-add',
    );
    final db = await catalogDb();
    final grown = (await db.query('customer_note_lines')).single;
    expect(grown['quantity'], 1500);
    expect(grown['unit_price_cents'], 3000);

    final undone = await voice.undo(added.executionId!);
    expect(
      undone.fold((failure) => throw failure, (value) => value).kind,
      VoiceOutcomeKind.undone,
    );
    final restored = (await db.query('customer_note_lines')).single;
    expect(restored['quantity'], 500);
    expect(restored['unit_price_cents'], 3000);
  });

  test('a customer reply keeps the product and the quantity', () async {
    await person(
      id: 'souza',
      name: 'Maria Souza',
      neighborhood: 'Jardim Paraíso',
    );
    await person(id: 'lima', name: 'Maria Lima', neighborhood: 'Centro');
    await product(id: 'abacaxi', name: 'Abacaxi', price: 450);

    final asked = await say(
      'Adicione um quilo de abacaxi para Maria.',
      executionId: 'exec-ask',
    );
    expect(asked.kind, VoiceOutcomeKind.clarify);
    expect(asked.command!.gap, VoiceGap.customer);
    expect(asked.command!.productQuery, 'abacaxi');
    expect(asked.command!.quantity, 1);
    expect(asked.command!.unit, VoiceUnit.kilogram);
    expect(await (await catalogDb()).query('customer_notes'), isEmpty);

    final done = await say(
      'Maria do Jardim Paraíso',
      executionId: 'exec-ask',
      pending: asked.command,
    );
    expect(done.kind, VoiceOutcomeKind.completed);
    expect(done.message, contains('Maria Souza'));
    final line = (await (await catalogDb()).query('customer_note_lines'))
        .single;
    expect(line['product_id'], 'abacaxi');
    expect(line['quantity'], 1000);
    expect(line['unit_price_cents'], 450);
  });

  test('undo does not delete a line that was edited later', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    await product(id: 'abacaxi', name: 'Abacaxi');
    final added = await say('Adicione um quilo de abacaxi para Adriele JP.');
    final db = await catalogDb();
    await db.update('customer_note_lines', {'quantity': 2000});
    final outcome = await voice.undo(added.executionId!);
    expect(
      outcome.fold((failure) => throw failure, (value) => value).message,
      contains('editado'),
    );
    expect((await db.query('customer_note_lines')).single['quantity'], 2000);
  });

  test(
    'the account shows notes, items, payments and credit apart from the draft',
    () async {
      await person(id: 'souza', name: 'Maria Souza', neighborhood: 'Centro');
      await receivables.openDebt(
        id: 'debt-souza',
        customerId: 'souza',
        amountCents: 15000,
        dueOn: '2026-10-01',
        description: 'Saldo inicial',
      );
      final db = await catalogDb();
      await db.insert('door_sales', {
        'id': 'note-sale',
        'note_id': 'note-sale',
        'customer_id': 'souza',
        'total_cents': 4000,
        'occurred_on': '2026-11-01',
        'recorded_at': '2026-11-01T09:00:00.000',
      });
      await db.insert('door_sale_lines', {
        'id': 'line-sale',
        'sale_id': 'note-sale',
        'position': 0,
        'product_id': 'abacaxi',
        'name': 'Abacaxi',
        'unit': 'kilogram',
        'quantity': 1000,
        'unit_price_cents': 4000,
      });
      await db.insert('receivables', {
        'id': 'sale-note-sale',
        'customer_id': 'souza',
        'kind': 'sale',
        'description': 'Entrega de Abacaxi',
        'amount_cents': 4000,
        'due_on': '2026-12-01',
        'occurred_on': '2026-11-01',
        'recorded_at': '2026-11-01T09:00:00.000',
      });
      await receivables.confirmReceipt(
        id: 'receipt-1',
        customerId: 'souza',
        amountCents: 5000,
        paidOn: '2026-11-02',
        method: PaymentMethod.cash,
        receivableIds: const ['debt-souza'],
      );
      await db.insert('customer_receipts', {
        'id': 'receipt-credit',
        'customer_id': 'souza',
        'amount_cents': 800,
        'credit_cents': 800,
        'paid_on': '2026-11-03',
        'method': 'pix',
        'recorded_at': '2026-11-03T09:00:00.000',
      });
      await product(id: 'alho', name: 'Alho');
      await say('Adicione um quilo de alho para Maria Souza.');

      final outcome = await say('Quanto a Maria Souza me deve?');
      final account = outcome.account!;
      expect(account.balanceCents, 14000);
      expect(account.overdueCents, 10000);
      expect(account.creditCents, 800);
      expect(account.neighborhood, 'Centro');
      expect(
        account.notes.map((note) => note.legacyWithoutItems),
        containsAll([true, false]),
      );
      expect(
        account.notes.expand((note) => note.lines),
        contains('Abacaxi · 1 quilo'),
      );
      expect(
        account.payments.map((item) => item.label),
        containsAll(['Dinheiro', 'Pix']),
      );
      expect(outcome.message, contains('Maria Souza'));
      expect(outcome.message, contains('R\$ 140,00'));
    },
  );

  test('an unsupported command does not create a draft', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    final outcome = await say('Confirmar a entrega da Adriele');
    expect(outcome.kind, VoiceOutcomeKind.unsupported);
    expect(await (await catalogDb()).query('customer_notes'), isEmpty);
  });

  test(
    'a negotiated unit price keeps the catalog and opens another line',
    () async {
      await person(
        id: 'adriele',
        name: 'Adriele Souza',
        neighborhood: 'Centro',
      );
      await product(
        id: 'melancia',
        name: 'Melancia',
        unit: CatalogUnit.piece,
        price: 2500,
      );
      await say('Adicione uma unidade de melancia para Adriele.');

      final noted = await say(
        'Cliente Adriele, melancia quinze reais.',
        executionId: 'exec-price',
      );
      expect(noted.kind, VoiceOutcomeKind.completed);
      expect(noted.openNote, isTrue);
      expect(
        noted.spoken,
        'Anotei uma melancia por quinze reais para Adriele.',
      );
      final again = await say(
        'Cliente Adriele, melancia quinze reais.',
        executionId: 'exec-price',
      );
      expect(again.kind, VoiceOutcomeKind.repeated);

      final second = await say(
        'Cliente Adriele, melancia quinze reais.',
        executionId: 'exec-price-2',
      );
      expect(second.kind, VoiceOutcomeKind.completed);
      await voice.undo('exec-price-2');

      final db = await catalogDb();
      final lines = await db.query(
        'customer_note_lines',
        orderBy: 'unit_price_cents DESC',
      );
      expect(lines, hasLength(2));
      expect(lines.first['quantity'], 1);
      expect(lines.first['unit_price_cents'], 2500);
      expect(lines.first['reference_price_cents'], 2500);
      expect(lines.last['quantity'], 1);
      expect(lines.last['unit_price_cents'], 1500);
      expect(lines.last['reference_price_cents'], 2500);
      final total = lines.fold<int>(
        0,
        (sum, row) =>
            sum + (row['quantity'] as int) * (row['unit_price_cents'] as int),
      );
      expect(total, 4000);
      final catalog = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: ['melancia'],
      );
      expect(catalog.single['sale_price_cents'], 2500);
    },
  );

  test(
    'a kilogram price asks the quantity and the basis before writing',
    () async {
      await person(
        id: 'adriele',
        name: 'Adriele Souza',
        neighborhood: 'Centro',
      );
      await product(id: 'alho', name: 'Alho', price: 3000);
      final asked = await say('Cliente Adriele, alho quinze reais.');
      expect(asked.kind, VoiceOutcomeKind.clarify);
      expect(asked.message, contains('quilo'));
      expect(asked.message, contains('total'));
      expect(asked.choices.map((choice) => choice.id), [
        'price:unit',
        'price:total',
      ]);
      expect(await (await catalogDb()).query('customer_note_lines'), isEmpty);

      final quantity = await say('por quilo', pending: asked.command);
      expect(quantity.kind, VoiceOutcomeKind.clarify);
      expect(quantity.message, contains('Quantos quilos'));
      expect(await (await catalogDb()).query('customer_note_lines'), isEmpty);

      final noted = await say('dois quilos', pending: quantity.command);
      expect(noted.kind, VoiceOutcomeKind.completed);
      final line = (await (await catalogDb()).query('customer_note_lines'))
          .single;
      expect(line['quantity'], 2000);
      expect(line['unit_price_cents'], 1500);
      expect(line['reference_price_cents'], 3000);
      final catalog = await (await catalogDb()).query('products');
      expect(catalog.single['sale_price_cents'], 3000);
    },
  );

  test('two customers with the same name are not chosen silently', () async {
    await person(id: 'souza', name: 'Adriele Souza', neighborhood: 'Centro');
    await person(id: 'lima', name: 'Adriele Lima', neighborhood: 'Vila Nova');
    await product(
      id: 'melancia',
      name: 'Melancia',
      unit: CatalogUnit.piece,
      price: 2500,
    );
    final asked = await say('Cliente Adriele, melancia quinze reais.');
    expect(asked.kind, VoiceOutcomeKind.clarify);
    expect(asked.choices, hasLength(2));
    expect(asked.command?.priceCents, 1500);
    expect(asked.command?.productQuery, 'melancia');
    expect(await (await catalogDb()).query('customer_note_lines'), isEmpty);
  });

  test('changing a price edits one draft line and can be undone', () async {
    await person(id: 'adriele', name: 'Adriele Souza', neighborhood: 'Centro');
    await product(
      id: 'melancia',
      name: 'Melancia',
      unit: CatalogUnit.piece,
      price: 2500,
    );
    await say('Adicione uma unidade de melancia para Adriele.');
    await say('Cliente Adriele, melancia dez reais.');
    final asked = await say(
      'Mude a melancia para quinze reais',
      contextCustomerId: 'adriele',
      contextLabel: 'Adriele Souza',
      contextFresh: true,
    );
    expect(asked.kind, VoiceOutcomeKind.clarify);
    expect(asked.choices, hasLength(2));
    final kept = await (await catalogDb()).query('customer_note_lines');
    expect(
      kept.map((row) => row['unit_price_cents']),
      containsAll([2500, 1000]),
    );

    final target = asked.choices.firstWhere(
      (choice) => choice.label.contains('25,00'),
    );
    final changed = await say(
      'a de vinte e cinco',
      pending: asked.command,
      choice: target.id,
      executionId: 'exec-reprice',
    );
    expect(changed.kind, VoiceOutcomeKind.completed);
    expect(changed.spoken, contains('quinze reais'));
    var lines = await (await catalogDb()).query(
      'customer_note_lines',
      orderBy: 'unit_price_cents DESC',
    );
    expect(lines.first['unit_price_cents'], 1500);
    expect(lines.first['reference_price_cents'], 2500);
    expect(lines.last['unit_price_cents'], 1000);

    await voice.undo('exec-reprice');
    lines = await (await catalogDb()).query(
      'customer_note_lines',
      orderBy: 'unit_price_cents DESC',
    );
    expect(lines.map((row) => row['unit_price_cents']), [2500, 1000]);
    final catalog = await (await catalogDb()).query('products');
    expect(catalog.single['sale_price_cents'], 2500);
  });

  test(
    'a delivered note is left alone and the new purchase uses a draft',
    () async {
      await person(
        id: 'adriele',
        name: 'Adriele Souza',
        neighborhood: 'Centro',
      );
      await product(
        id: 'melancia',
        name: 'Melancia',
        unit: CatalogUnit.piece,
        price: 2500,
      );
      await say('Adicione uma unidade de melancia para Adriele.');
      final db = await catalogDb();
      await db.update('customer_notes', {'status': 'delivered'});

      final blocked = await say(
        'Mude a melancia para quinze reais',
        contextCustomerId: 'adriele',
        contextLabel: 'Adriele Souza',
        contextFresh: true,
      );
      expect(blocked.message, contains('entregue'));
      expect((await db.query('customer_notes')).map((row) => row['status']), [
        'delivered',
      ]);

      final noted = await say('Cliente Adriele, melancia quinze reais.');
      expect(noted.kind, VoiceOutcomeKind.completed);
      final notes = await db.query('customer_notes');
      expect(
        notes.map((row) => row['status']),
        containsAll(['delivered', 'draft']),
      );
      final delivered = await db.rawQuery('''
      SELECT l.unit_price_cents
      FROM customer_note_lines l
      JOIN customer_notes n ON n.id = l.note_id
      WHERE n.status = 'delivered'
      ''');
      expect(delivered.single['unit_price_cents'], 2500);
      final draft = await db.rawQuery('''
      SELECT l.unit_price_cents, l.reference_price_cents
      FROM customer_note_lines l
      JOIN customer_notes n ON n.id = l.note_id
      WHERE n.status = 'draft'
      ''');
      expect(draft.single['unit_price_cents'], 1500);
      expect(draft.single['reference_price_cents'], 2500);
    },
  );

  test('the open customer note receives the spoken item', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'batata', name: 'Batata');
    final noted = await say(
      'Adicione um quilo de batata nesse cliente',
      contextCustomerId: 'ricardo',
      contextLabel: 'Ricardo Alves',
      contextFresh: true,
    );
    expect(noted.kind, VoiceOutcomeKind.completed);
    expect(noted.subjectId, 'ricardo');
    expect(noted.message, isNot(contains('Para qual cliente')));
    final line = (await (await catalogDb()).query('customer_note_lines'))
        .single;
    expect(line['product_id'], 'batata');
    expect(line['quantity'], 1000);
  });

  test('a follow-up keeps the customer of the open visit', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    await product(id: 'alho', name: 'Alho');
    final first = await say(
      'Adicione um quilo de alho para Adriele JP.',
      executionId: 'exec-visit',
    );
    expect(first.subjectId, 'adriele');

    final second = await say(
      'Adicione dois quilos de alho',
      executionId: 'exec-follow',
      contextCustomerId: 'adriele',
      contextLabel: 'Adriele Souza · Jardim Paraíso',
      contextFresh: true,
    );
    expect(second.kind, VoiceOutcomeKind.completed);
    expect(second.subjectId, 'adriele');
    final lines = await (await catalogDb()).query('customer_note_lines');
    expect(lines.single['quantity'], 3000);
  });

  test('a stale visit asks before applying ela', () async {
    await person(
      id: 'adriele',
      name: 'Adriele Souza',
      neighborhood: 'Jardim Paraíso',
    );
    final asked = await say(
      'Quanto ela me deve?',
      contextCustomerId: 'adriele',
      contextLabel: 'Adriele Souza · Jardim Paraíso',
    );
    expect(asked.kind, VoiceOutcomeKind.clarify);
    expect(asked.message, 'Continuo com Adriele Souza · Jardim Paraíso?');
    expect(asked.choices.single.id, 'customer:adriele');
    expect(await (await catalogDb()).query('receivables'), isEmpty);
  });

  test('Ricardo receives alho and batata from one spoken command', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho', price: 2000);
    await product(id: 'batata', name: 'Batata', price: 400);
    final noted = await say(
      'E adicione um quilo de alho e um quilo de batata',
      executionId: 'exec-ricardo',
      contextCustomerId: 'ricardo',
      contextLabel: 'Ricardo Alves',
      contextFresh: true,
    );
    expect(noted.kind, VoiceOutcomeKind.completed);
    expect(noted.spoken, isEmpty);
    expect(noted.message, contains('Adicionados: Alho 1 kg e Batata 1 kg'));
    expect(noted.subjectId, 'ricardo');
    expect(noted.note?.totalCents, 2400);
    final db = await catalogDb();
    final lines = await db.query('customer_note_lines', orderBy: 'name');
    expect(lines.map((row) => row['product_id']), ['alho', 'batata']);
    expect(lines.map((row) => row['quantity']), [1000, 1000]);

    final repeated = await say(
      'E adicione um quilo de alho e um quilo de batata',
      executionId: 'exec-ricardo',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(repeated.kind, VoiceOutcomeKind.repeated);
    expect(await db.query('customer_note_lines'), hasLength(2));

    final again = await say(
      'E adicione um quilo de alho e um quilo de batata',
      executionId: 'exec-ricardo-2',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(again.kind, VoiceOutcomeKind.completed);
    final doubled = await db.query('customer_note_lines', orderBy: 'name');
    expect(doubled.map((row) => row['quantity']), [2000, 2000]);

    final undone = await voice.undo('exec-ricardo-2');
    final undoOutcome = undone.fold(
      (failure) => throw failure,
      (value) => value,
    );
    expect(
      undoOutcome.message,
      'Desfiz o acréscimo desta solicitação. O restante da nota continua.',
    );
    expect(undoOutcome.kind, VoiceOutcomeKind.undone);
    final restored = await db.query('customer_note_lines', orderBy: 'name');
    expect(restored.map((row) => row['quantity']), [1000, 1000]);
  });

  test('an unclear second item is kept and nothing is saved yet', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho');
    await product(id: 'batata', name: 'Batata');
    final asked = await say(
      'Um quilo de alho e duas batatas',
      contextCustomerId: 'ricardo',
      contextLabel: 'Ricardo Alves',
      contextFresh: true,
    );
    expect(asked.kind, VoiceOutcomeKind.clarify);
    expect(asked.message, 'Batata: duas unidades ou dois quilos?');
    expect(await (await catalogDb()).query('customer_note_lines'), isEmpty);
    expect(asked.command?.items.first.productId, 'alho');

    final noted = await say(
      'dois quilos',
      pending: asked.command,
      executionId: 'exec-both',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(noted.kind, VoiceOutcomeKind.completed);
    expect(noted.message, contains('Alho 1 kg e Batata 2 kg'));
    final lines = await (await catalogDb()).query(
      'customer_note_lines',
      orderBy: 'name',
    );
    expect(lines.map((row) => row['quantity']), [1000, 2000]);
    final effects = await (await catalogDb()).query('voice_commands');
    expect(effects, hasLength(2));
    expect(
      effects.map((row) => row['execution_id']),
      containsAll(['exec-both', 'exec-both~1']),
    );
  });

  test('para ele uses the customer already in attendance', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho');
    final noted = await say(
      'Coloca também um quilo de alho para ele',
      contextCustomerId: 'ricardo',
      contextLabel: 'Ricardo Alves',
      contextFresh: true,
    );
    expect(noted.kind, VoiceOutcomeKind.completed);
    expect(noted.subjectId, 'ricardo');
    expect(noted.message, isNot(contains('Para qual cliente')));
  });

  Future<void> stock(String productId, int quantity) async {
    await (await catalogDb()).insert('movements', {
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

  Future<int> montana(String productId) async {
    final rows = await (await catalogDb()).rawQuery(
      '''
      SELECT COALESCE(SUM(quantity), 0) AS total
      FROM movements
      WHERE product_id = ? AND location_code = 'montana'
      ''',
      [productId],
    );
    return rows.single['total'] as int? ?? 0;
  }

  test('a spoken confirm is bound to the review and writes nothing', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho', price: 2000);
    await say(
      'Adicione um quilo de alho para ele',
      contextCustomerId: 'ricardo',
      contextLabel: 'Ricardo Alves',
      contextFresh: true,
    );
    final review = await say(
      'Confirmar entrega',
      contextCustomerId: 'ricardo',
      contextLabel: 'Ricardo Alves',
      contextFresh: true,
    );
    expect(review.kind, VoiceOutcomeKind.clarify);
    expect(review.message, contains('vencimento'));
    final db = await catalogDb();
    expect((await db.query('customer_notes')).single['status'], 'draft');

    final loose = await say(
      'confirmar',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(loose.kind, VoiceOutcomeKind.blocked);
    expect(await db.query('door_sales'), isEmpty);

    final dated = await say(
      'Ela paga dia quinze de novembro.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(dated.message, contains('15 de novembro de 2026'));
    final ready = await say(
      'Confirmar entrega',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(ready.command?.reviewToken, isNotNull);

    await product(id: 'batata', name: 'Batata', price: 400);
    await say(
      'Adicione um quilo de batata para ele',
      executionId: 'exec-after-review',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    final stale = await say(
      'confirmar',
      pending: ready.command,
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(stale.message, contains('A revisão mudou'));
    expect((await db.query('customer_notes')).single['status'], 'draft');
    expect(await db.query('door_sales'), isEmpty);
  });

  test('fiado on the fifteenth turns 150 plus 30 into 180', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho', price: 3000);
    await stock('alho', 5000);
    await receivables.openDebt(
      id: 'debt-ricardo',
      customerId: 'ricardo',
      amountCents: 15000,
      dueOn: '2026-10-01',
    );
    final added = await say(
      'Adicione um quilo de alho por trinta reais.',
      contextCustomerId: 'ricardo',
      contextLabel: 'Ricardo Alves',
      contextFresh: true,
    );
    expect(added.kind, VoiceOutcomeKind.completed);
    final due = await say(
      'Ela paga dia quinze de novembro.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(due.message, contains('15 de novembro de 2026'));
    final review = await say(
      'Confirmar entrega.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(review.message, contains('Ricardo Alves'));
    expect(review.message, contains('R\$ 30,00'));
    expect(review.message, contains('15 de novembro de 2026'));
    expect(review.message, contains('fiada'));
    expect(review.message, contains('R\$ 150,00'));
    expect(review.message, contains('R\$ 180,00'));
    expect(review.message, contains('Montana'));
    expect(review.spoken, isEmpty);

    final confirmed = await say(
      'Confirmar',
      pending: review.command,
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(confirmed.kind, VoiceOutcomeKind.completed);
    expect(confirmed.message, contains('R\$ 30,00'));
    expect(confirmed.message, contains('R\$ 180,00'));
    expect(confirmed.subjectId, 'ricardo');
    expect(confirmed.spoken, isEmpty);
    expect(await montana('alho'), 4000);
    final account = await receivables.account('ricardo');
    expect(account.balanceCents, 18000);
    expect(
      account.receivables
          .singleWhere((item) => item.id == 'debt-ricardo')
          .dueOn,
      '2026-10-01',
    );
    final notes = await (await catalogDb()).query('customer_notes');
    expect(notes.single['status'], 'delivered');
    expect(notes.single['due_on'], '2026-11-15');

    final again = await say(
      'Confirmar',
      pending: review.command,
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(again.kind, VoiceOutcomeKind.repeated);
    expect(await montana('alho'), 4000);
    expect((await receivables.account('ricardo')).balanceCents, 18000);

    final next = await say(
      'Adicione um quilo de alho para ele',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(next.kind, VoiceOutcomeKind.completed);
    final drafts = await (await catalogDb()).query(
      'customer_notes',
      where: 'status = ?',
      whereArgs: ['draft'],
    );
    expect(drafts, hasLength(1));
  });

  test('partial cash, change and a promised pix stay apart', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho', price: 3000);
    await stock('alho', 2000);
    await receivables.openDebt(
      id: 'debt-ricardo',
      customerId: 'ricardo',
      amountCents: 15000,
      dueOn: '2026-10-01',
    );
    await say(
      'Adicione um quilo de alho por trinta reais.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    final promised = await say(
      'Vou mandar o Pix.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(promised.message, contains('não entrou'));
    expect(await (await catalogDb()).query('customer_receipts'), isEmpty);

    final partial = await say(
      'Recebi vinte reais em dinheiro.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(partial.message, contains('R\$ 20,00'));
    await say(
      'Ela paga dia quinze de novembro.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    final review = await say(
      'Confirmar entrega',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(review.message, contains('R\$ 20,00'));
    expect(review.message, contains('R\$ 10,00'));
    expect(review.message, contains('não entra neste pagamento'));
    expect(review.message, contains('R\$ 160,00'));
    final confirmed = await say(
      'Confirmar',
      pending: review.command,
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(confirmed.kind, VoiceOutcomeKind.completed);
    expect((await receivables.account('ricardo')).balanceCents, 16000);
    expect(
      (await (await catalogDb()).query('customer_receipts'))
          .single['amount_cents'],
      2000,
    );
  });

  test('cash handed over shows the change and leaves the old debt', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho', price: 3000);
    await stock('alho', 1000);
    await receivables.openDebt(
      id: 'debt-ricardo',
      customerId: 'ricardo',
      amountCents: 15000,
      dueOn: '2026-10-01',
    );
    await say(
      'Adicione um quilo de alho por trinta reais.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    final paid = await say(
      'Recebi trinta reais em dinheiro e ela me deu cinquenta reais.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(paid.message, contains('Troco'));
    expect(paid.message, contains('R\$ 20,00'));
    final review = await say(
      'Confirmar entrega',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(review.message, contains('Troco'));
    final confirmed = await say(
      'Confirmar',
      pending: review.command,
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(confirmed.kind, VoiceOutcomeKind.completed);
    expect((await receivables.account('ricardo')).balanceCents, 15000);
    expect(await montana('alho'), 0);
    final receipt = (await (await catalogDb()).query('customer_receipts'))
        .single;
    expect(receipt['change_cents'], 2000);
    expect(receipt['tendered_cents'], 5000);
  });

  test('a past month is not applied and cancel keeps the draft', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho');
    await say(
      'Adicione um quilo de alho para ele',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    final asked = await say(
      'Mude o vencimento para vinte de novembro.',
      today: DateTime(2026, 12, 1),
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(asked.kind, VoiceOutcomeKind.clarify);
    expect(asked.message, contains('já passou'));
    expect(
      (await (await catalogDb()).query('customer_notes')).single['due_on'],
      isNull,
    );
    final accepted = await say(
      'sim',
      pending: asked.command,
      today: DateTime(2026, 12, 1),
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(accepted.message, contains('20 de novembro de 2027'));

    final review = await say(
      'Confirmar entrega',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    final cancelled = await say(
      'Cancelar',
      pending: review.command,
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(cancelled.message, 'Cancelado.');
    expect(await (await catalogDb()).query('door_sales'), isEmpty);
    expect(
      (await (await catalogDb()).query('customer_notes')).single['status'],
      'draft',
    );
  });

  test('short stock blocks the delivery and the draft can continue', () async {
    await person(id: 'ricardo', name: 'Ricardo Alves', neighborhood: 'Centro');
    await product(id: 'alho', name: 'Alho', price: 3000);
    await say(
      'Adicione um quilo de alho por trinta reais.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    await say(
      'Ela paga dia quinze de novembro.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    final review = await say(
      'Confirmar entrega',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(review.message, contains('há 0 kg'));
    final failed = await say(
      'Confirmar',
      pending: review.command,
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(failed.kind, VoiceOutcomeKind.blocked);
    expect(failed.message, contains('Montana'));
    expect(await (await catalogDb()).query('door_sales'), isEmpty);
    expect(await (await catalogDb()).query('receivables'), isEmpty);
    expect(
      (await (await catalogDb()).query('customer_notes')).single['status'],
      'draft',
    );
    final later = await say(
      'Para daqui a trinta dias.',
      contextCustomerId: 'ricardo',
      contextFresh: true,
    );
    expect(later.kind, VoiceOutcomeKind.completed);
    expect(later.message, contains('4 de dezembro de 2026'));
  });
}
