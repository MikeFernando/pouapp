import 'package:sqflite/sqflite.dart';

const catalogDatabaseVersion = 11;

const operationSourceKey = 'operation_source';
const operationSourceSqlite = 'sqlite';

/// Tables that share the catalog database so a future sale can update a
/// draft, a stock movement, a debt and a payment in one SQLite transaction.
/// Customer ids are references. There is no foreign key to the customer file.
Future<void> createOperationalTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS customer_notes (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      status TEXT NOT NULL,
      due_on TEXT,
      payment_method TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await ensureOneDraftNotePerCustomer(db);
  await ensureNotePaymentMethod(db);
  await db.execute('''
    CREATE TABLE IF NOT EXISTS customer_note_lines (
      id TEXT PRIMARY KEY,
      note_id TEXT NOT NULL REFERENCES customer_notes(id) ON DELETE CASCADE,
      position INTEGER NOT NULL,
      product_id TEXT,
      name TEXT NOT NULL,
      unit TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price_cents INTEGER NOT NULL,
      reference_price_cents INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS street_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      day TEXT NOT NULL,
      next_number INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS street_visits (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      customer_name TEXT NOT NULL,
      address TEXT NOT NULL,
      reasons TEXT NOT NULL,
      status TEXT NOT NULL,
      position INTEGER NOT NULL,
      day TEXT NOT NULL,
      note TEXT,
      rescheduled_to TEXT,
      legacy INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS street_orders (
      id TEXT PRIMARY KEY,
      code TEXT NOT NULL,
      customer_id TEXT NOT NULL,
      customer_name TEXT NOT NULL,
      recorded INTEGER NOT NULL,
      delivered INTEGER NOT NULL,
      created_visit_id TEXT,
      delivered_during_visit_id TEXT,
      corrected_during_visit_id TEXT,
      from_seed INTEGER NOT NULL,
      note TEXT,
      legacy INTEGER NOT NULL,
      occurred_on TEXT,
      recorded_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS street_order_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id TEXT NOT NULL REFERENCES street_orders(id) ON DELETE CASCADE,
      generation INTEGER NOT NULL,
      line_index INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit TEXT NOT NULL,
      unit_price_cents INTEGER NOT NULL,
      product_id TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS street_payments (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      paid_on TEXT NOT NULL,
      method TEXT NOT NULL,
      visit_id TEXT,
      from_seed INTEGER NOT NULL,
      note TEXT,
      legacy INTEGER NOT NULL,
      recorded_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS street_payment_shares (
      payment_id TEXT NOT NULL REFERENCES street_payments(id) ON DELETE CASCADE,
      order_id TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      PRIMARY KEY (payment_id, order_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS street_agreements (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      agreed_on TEXT NOT NULL,
      visit_id TEXT,
      note TEXT,
      legacy INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS operation_import (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      origin_json TEXT NOT NULL,
      visits INTEGER NOT NULL,
      orders INTEGER NOT NULL,
      order_lines INTEGER NOT NULL,
      payments INTEGER NOT NULL,
      payment_shares INTEGER NOT NULL,
      agreements INTEGER NOT NULL,
      notes INTEGER NOT NULL,
      note_lines INTEGER NOT NULL,
      order_total_cents INTEGER NOT NULL,
      payment_total_cents INTEGER NOT NULL,
      imported_at TEXT NOT NULL
    )
  ''');
}

/// Drafts and confirmed stock operations share the catalog connection.
/// A confirmed row is append-only. Repeating its id does not move stock again.
Future<void> createStockOperationTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS stock_drafts (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      location_code TEXT,
      reason TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_draft_kind
    ON stock_drafts(kind)
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS stock_draft_lines (
      id TEXT PRIMARY KEY,
      draft_id TEXT NOT NULL REFERENCES stock_drafts(id) ON DELETE CASCADE,
      product_id TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      position INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS stock_operations (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      occurred_on TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      origin_code TEXT,
      destination_code TEXT,
      location_code TEXT,
      reason TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS stock_operation_lines (
      id TEXT PRIMARY KEY,
      operation_id TEXT NOT NULL REFERENCES stock_operations(id),
      product_id TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      previous_quantity INTEGER,
      delta INTEGER,
      position INTEGER NOT NULL
    )
  ''');
}

/// Adds the operation link expected by version 3 without rewriting movements.
Future<void> upgradeStockOperations(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(movements)');
  final hasOperation = columns.any((row) => row['name'] == 'operation_id');
  if (!hasOperation) {
    await db.execute('ALTER TABLE movements ADD COLUMN operation_id TEXT');
  }
  await createStockOperationTables(db);
}

/// Opening debts, receipts and Pix charges. A draft note is not a row here.
/// A confirmed delivery adds its own receivable inside the same transaction.
Future<void> createReceivableTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS receivables (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      description TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      due_on TEXT,
      occurred_on TEXT NOT NULL,
      recorded_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS customer_receipts (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      tendered_cents INTEGER,
      change_cents INTEGER,
      credit_cents INTEGER NOT NULL,
      paid_on TEXT NOT NULL,
      method TEXT NOT NULL,
      note TEXT,
      recorded_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS receipt_allocations (
      receipt_id TEXT NOT NULL REFERENCES customer_receipts(id),
      receivable_id TEXT NOT NULL REFERENCES receivables(id),
      amount_cents INTEGER NOT NULL,
      PRIMARY KEY (receipt_id, receivable_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS receipt_reversals (
      id TEXT PRIMARY KEY,
      receipt_id TEXT NOT NULL UNIQUE REFERENCES customer_receipts(id),
      method TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      reason TEXT,
      recorded_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS business_profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      pix_key_type TEXT,
      pix_key TEXT,
      pix_receiver_name TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS charge_preparations (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      description TEXT NOT NULL,
      message TEXT NOT NULL,
      status TEXT NOT NULL,
      phone TEXT,
      created_at TEXT NOT NULL
    )
  ''');
}

/// Confirmed door sales. The sale id is the note id, so a repeated
/// confirmation finds the same row. Pending sync is local only.
Future<void> createDeliveryTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS door_sales (
      id TEXT PRIMARY KEY,
      note_id TEXT NOT NULL UNIQUE,
      customer_id TEXT NOT NULL,
      total_cents INTEGER NOT NULL,
      occurred_on TEXT NOT NULL,
      recorded_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS door_sale_lines (
      id TEXT PRIMARY KEY,
      sale_id TEXT NOT NULL REFERENCES door_sales(id),
      position INTEGER NOT NULL,
      product_id TEXT,
      name TEXT NOT NULL,
      unit TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price_cents INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS credit_applications (
      id TEXT PRIMARY KEY,
      receipt_id TEXT NOT NULL REFERENCES customer_receipts(id),
      receivable_id TEXT NOT NULL REFERENCES receivables(id),
      amount_cents INTEGER NOT NULL,
      recorded_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pending_sync (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      status TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      payload TEXT,
      attempts INTEGER NOT NULL DEFAULT 0,
      last_attempt_at TEXT
    )
  ''');
}

/// Local weighing note. It does not move warehouse or Montana stock.
Future<void> upgradeSyncQueue(Database db) async {
  final columns = await db.rawQuery('PRAGMA table_info(pending_sync)');
  final names = {for (final row in columns) row['name'] as String};
  if (!names.contains('payload')) {
    await db.execute('ALTER TABLE pending_sync ADD COLUMN payload TEXT');
  }
  if (!names.contains('attempts')) {
    await db.execute(
      'ALTER TABLE pending_sync ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0',
    );
  }
  if (!names.contains('last_attempt_at')) {
    await db.execute(
      'ALTER TABLE pending_sync ADD COLUMN last_attempt_at TEXT',
    );
  }
  await db.execute('''
    CREATE TABLE IF NOT EXISTS weighing_records (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      pack_grams INTEGER NOT NULL,
      package_count INTEGER NOT NULL,
      warehouse_grams INTEGER NOT NULL,
      recorded_at TEXT NOT NULL
    )
  ''');
}

/// Keeps one pending row per operation. A later edit of the same id
/// returns it to the local queue. Nothing here means the server accepted it.
Future<void> enqueueSync(
  DatabaseExecutor db, {
  required String id,
  required String kind,
  required String recordedAt,
  String? payload,
}) async {
  await db.rawInsert(
    '''
    INSERT INTO pending_sync (
      id, kind, status, recorded_at, payload, attempts
    ) VALUES (?, ?, 'local', ?, ?, 0)
    ON CONFLICT(id) DO UPDATE SET
      kind = excluded.kind,
      payload = excluded.payload,
      recorded_at = excluded.recorded_at,
      status = 'local'
    ''',
    [id, kind, recordedAt, payload],
  );
}

/// Aliases and voice commands stay on the phone. Audio is not stored.
Future<void> upgradeVoiceTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS voice_aliases (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      alias TEXT NOT NULL,
      target TEXT NOT NULL,
      UNIQUE(kind, alias)
    )
  ''');
  await _createVoiceCommands(db);
  await db.insert('voice_aliases', {
    'id': 'alias-neighborhood-jp',
    'kind': 'neighborhood',
    'alias': 'jp',
    'target': 'Jardim Paraíso',
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

/// Preferred payment method chosen on the draft before delivery confirmation.
Future<void> ensureNotePaymentMethod(DatabaseExecutor db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customer_notes'",
  );
  if (tables.isEmpty) return;
  final columns = await db.rawQuery('PRAGMA table_info(customer_notes)');
  final hasPayment = columns.any((row) => row['name'] == 'payment_method');
  if (hasPayment) return;
  await db.execute(
    'ALTER TABLE customer_notes ADD COLUMN payment_method TEXT',
  );
}

/// One open draft per customer — drop older duplicates, then restore the index.
Future<void> ensureOneDraftNotePerCustomer(DatabaseExecutor db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customer_notes'",
  );
  if (tables.isEmpty) return;
  final drafts = await db.query(
    'customer_notes',
    columns: ['id', 'customer_id', 'updated_at'],
    where: "status = 'draft'",
    orderBy: 'updated_at DESC, id DESC',
  );
  final keptCustomer = <String>{};
  for (final row in drafts) {
    final customerId = row['customer_id']! as String;
    final id = row['id']! as String;
    if (keptCustomer.add(customerId)) continue;
    await db.delete('customer_notes', where: 'id = ?', whereArgs: [id]);
  }
  await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_customer_notes_one_draft
    ON customer_notes(customer_id)
    WHERE status = 'draft'
  ''');
}

Future<void> _createVoiceCommands(DatabaseExecutor db) {
  return db.execute('''
    CREATE TABLE IF NOT EXISTS voice_commands (
      execution_id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      note_id TEXT NOT NULL,
      line_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      added_quantity INTEGER NOT NULL,
      previous_quantity INTEGER NOT NULL,
      unit_price_cents INTEGER NOT NULL,
      previous_price_cents INTEGER,
      command_kind TEXT NOT NULL DEFAULT 'add',
      undone INTEGER NOT NULL,
      recorded_at TEXT NOT NULL
    )
  ''');
}

/// The catalog price stays on the product. A line keeps that reference and
/// the price actually practiced, so a commercial discount is visible and is
/// not subtracted again from a total that already uses the practiced price.
Future<void> upgradeReferencePrices(Database db) async {
  final lineColumns = await db.rawQuery(
    'PRAGMA table_info(customer_note_lines)',
  );
  final lineNames = {for (final row in lineColumns) row['name'] as String};
  if (lineNames.isNotEmpty && !lineNames.contains('reference_price_cents')) {
    await db.execute(
      'ALTER TABLE customer_note_lines ADD COLUMN reference_price_cents INTEGER',
    );
    await db.execute('''
      UPDATE customer_note_lines
      SET reference_price_cents = unit_price_cents
      WHERE reference_price_cents IS NULL
      ''');
  }
  final voiceColumns = await db.rawQuery('PRAGMA table_info(voice_commands)');
  final voiceNames = {for (final row in voiceColumns) row['name'] as String};
  if (voiceNames.isEmpty) return;
  if (!voiceNames.contains('previous_price_cents')) {
    await db.execute(
      'ALTER TABLE voice_commands ADD COLUMN previous_price_cents INTEGER',
    );
  }
  if (!voiceNames.contains('command_kind')) {
    await db.execute(
      "ALTER TABLE voice_commands ADD COLUMN command_kind TEXT NOT NULL DEFAULT 'add'",
    );
  }
}

/// One row per voice request. A repeated save of that request does not add
/// again. A later request with the same phrase gets its own id.
Future<void> upgradeVoiceExecutions(Database db) async {
  final existing = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'voice_commands'",
  );
  if (existing.isEmpty) {
    await _createVoiceCommands(db);
    return;
  }
  final columns = await db.rawQuery('PRAGMA table_info(voice_commands)');
  final names = {for (final row in columns) row['name'] as String};
  if (names.contains('execution_id')) return;
  await db.execute('''
    CREATE TABLE voice_commands_v8 (
      execution_id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      note_id TEXT NOT NULL,
      line_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      added_quantity INTEGER NOT NULL,
      previous_quantity INTEGER NOT NULL,
      unit_price_cents INTEGER NOT NULL,
      undone INTEGER NOT NULL,
      recorded_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    INSERT INTO voice_commands_v8 (
      execution_id, customer_id, note_id, line_id, product_id,
      added_quantity, previous_quantity, unit_price_cents, undone, recorded_at
    )
    SELECT fingerprint, customer_id, note_id, line_id, product_id,
      quantity, 0, unit_price_cents, undone, recorded_at
    FROM voice_commands
  ''');
  await db.execute('DROP TABLE voice_commands');
  await db.execute('ALTER TABLE voice_commands_v8 RENAME TO voice_commands');
}
