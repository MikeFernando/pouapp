import 'package:sqflite/sqflite.dart';

import '../../../../core/error/exceptions.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../catalog/data/operational_schema.dart';
import '../../../workspace/domain/entities/street_ledger.dart';
import '../../domain/entities/customer_note.dart';
import '../exceptions/note_exceptions.dart';
import 'customer_local_data_source.dart';

abstract class CustomerNoteLocalDataSource {
  Future<CustomerNote> activeDraft(String customerId);

  /// Draft when one is open, otherwise the latest delivery. Creates a draft
  /// only when the customer has neither.
  Future<CustomerNote> openNote(String customerId);

  Future<CustomerNote?> currentNote(String customerId);

  Future<CustomerNote> note(String id);

  /// Draft notes that already have a due date and a positive total.
  Future<List<CustomerNote>> draftNotesWithDue();

  /// Customers whose draft is empty or has no due — home must hide remote rows.
  Future<Set<String>> clearedDraftCustomerIds();

  Future<CustomerNote> saveLines({
    required String noteId,
    required List<NoteLineDraft> lines,
  });

  Future<CustomerNote> setDueOn({
    required String noteId,
    required DateTime? dueOn,
  });

  Future<CustomerNote> setPaymentMethod({
    required String noteId,
    required PaymentMethod? paymentMethod,
  });

  /// Marks the draft as deleted and returns a new empty draft for the customer.
  Future<CustomerNote> deleteNote(String noteId);

  Future<List<CustomerNote>> deletedNotes(String customerId);
}

class CustomerNoteLocalDataSourceImpl implements CustomerNoteLocalDataSource {
  CustomerNoteLocalDataSourceImpl({
    required this.openDatabase,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? generateEntityId;

  final Future<Database> Function() openDatabase;
  final DateTime Function() _clock;
  final String Function() _newId;

  @override
  Future<CustomerNote> activeDraft(String customerId) async {
    final db = await openDatabase();
    try {
      return await db.transaction((txn) async {
        await _purgeExtraDrafts(txn, customerId: customerId);
        final existing = await txn.query(
          'customer_notes',
          where: 'customer_id = ? AND status = ?',
          whereArgs: [customerId, NoteStatus.draft.name],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return _read(txn, existing.first['id']! as String);
        }
        final now = _clock().toUtc().toIso8601String();
        final id = _newId();
        await txn.insert('customer_notes', {
          'id': id,
          'customer_id': customerId,
          'status': NoteStatus.draft.name,
          'due_on': null,
          'payment_method': null,
          'created_at': now,
          'updated_at': now,
        });
        return _read(txn, id);
      });
    } on DatabaseException catch (error) {
      if (!error.isUniqueConstraintError()) throw CacheException();
      final db = await openDatabase();
      await consolidateCustomerDraftNotes(db);
      final existing = await db.query(
        'customer_notes',
        columns: ['id'],
        where: 'customer_id = ? AND status = ?',
        whereArgs: [customerId, NoteStatus.draft.name],
        limit: 1,
      );
      if (existing.isEmpty) throw CacheException();
      return _read(db, existing.first['id']! as String);
    }
  }

  @override
  Future<CustomerNote> openNote(String customerId) async {
    final db = await openDatabase();
    try {
      await consolidateCustomerDraftNotes(db);
    } on DatabaseException {
      // Still open/create a draft even if cleanup fails.
    }
    final draft = await db.query(
      'customer_notes',
      columns: ['id'],
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, NoteStatus.draft.name],
      limit: 1,
    );
    if (draft.isNotEmpty) return _read(db, draft.first['id']! as String);
    final delivered = await db.query(
      'customer_notes',
      columns: ['id'],
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, NoteStatus.delivered.name],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (delivered.isNotEmpty) {
      return _read(db, delivered.first['id']! as String);
    }
    return activeDraft(customerId);
  }

  @override
  Future<CustomerNote?> currentNote(String customerId) async {
    final db = await openDatabase();
    try {
      await consolidateCustomerDraftNotes(db);
    } on DatabaseException {
      // Ignore cleanup failures when only reading.
    }
    final draft = await db.query(
      'customer_notes',
      columns: ['id'],
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, NoteStatus.draft.name],
      limit: 1,
    );
    if (draft.isNotEmpty) return _read(db, draft.first['id']! as String);
    final delivered = await db.query(
      'customer_notes',
      columns: ['id'],
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, NoteStatus.delivered.name],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (delivered.isEmpty) return null;
    return _read(db, delivered.first['id']! as String);
  }

  @override
  Future<List<CustomerNote>> draftNotesWithDue() async {
    final db = await openDatabase();
    try {
      await consolidateCustomerDraftNotes(db);
    } on DatabaseException {
      // Prefer returning what we can over failing the home board.
    }
    final rows = await db.query(
      'customer_notes',
      where: 'status = ? AND due_on IS NOT NULL',
      whereArgs: [NoteStatus.draft.name],
      orderBy: 'due_on ASC',
    );
    final notes = <CustomerNote>[];
    for (final row in rows) {
      final note = await _read(db, row['id']! as String);
      if (note.dueOn == null || note.totalCents <= 0) continue;
      notes.add(note);
    }
    return notes;
  }

  @override
  Future<Set<String>> clearedDraftCustomerIds() async {
    final db = await openDatabase();
    try {
      await consolidateCustomerDraftNotes(db);
    } on DatabaseException {
      // Prefer returning what we can over failing the home board.
    }
    final rows = await db.query(
      'customer_notes',
      columns: ['id', 'customer_id'],
      where: 'status = ?',
      whereArgs: [NoteStatus.draft.name],
    );
    final cleared = <String>{};
    for (final row in rows) {
      final note = await _read(db, row['id']! as String);
      // Brand-new empty drafts (open customer, no edit) must not hide remote
      // home dues. Only drafts that lost their due/amount after having content
      // — or an explicit due clear with lines still present — count as cleared.
      final emptyShell =
          note.dueOn == null && note.totalCents <= 0 && note.lines.isEmpty;
      if (emptyShell) continue;
      if (note.dueOn == null || note.totalCents <= 0) {
        cleared.add(note.customerId);
      }
    }
    return cleared;
  }

  @override
  Future<CustomerNote> note(String id) async {
    final db = await openDatabase();
    return _read(db, id);
  }

  @override
  Future<CustomerNote> saveLines({
    required String noteId,
    required List<NoteLineDraft> lines,
  }) async {
    final prepared = [for (final line in lines) _checked(line)];
    final db = await openDatabase();
    try {
      return await db.transaction((txn) async {
        await _touchDraft(txn, noteId);
        final current = await _read(txn, noteId);
        await _purgeExtraDrafts(
          txn,
          customerId: current.customerId,
          keepId: noteId,
        );
        await txn.delete(
          'customer_note_lines',
          where: 'note_id = ?',
          whereArgs: [noteId],
        );
        for (var index = 0; index < prepared.length; index++) {
          final line = prepared[index];
          // Always allocate a fresh id: ephemeral UI ids like `local-0` collide
          // across notes because line id is the global primary key.
          await txn.insert('customer_note_lines', {
            'id': _newId(),
            'note_id': noteId,
            'position': index,
            'product_id': line.productId,
            'name': line.name.trim(),
            'unit': line.unit.name,
            'quantity': line.quantity,
            'unit_price_cents': line.unitPriceCents,
            'reference_price_cents': line.referencePriceCents,
          });
        }
        await _queueNote(txn, noteId);
        return _read(txn, noteId);
      });
    } on NoteNotFoundException {
      rethrow;
    } on DatabaseException {
      throw CacheException();
    }
  }

  @override
  Future<CustomerNote> setDueOn({
    required String noteId,
    required DateTime? dueOn,
  }) async {
    final db = await openDatabase();
    try {
      return await db.transaction((txn) async {
        final current = await _read(txn, noteId);
        await _purgeExtraDrafts(
          txn,
          customerId: current.customerId,
          keepId: noteId,
        );
        await _touchDraft(txn, noteId, dueOn: dueOn, replaceDueOn: true);
        await _queueNote(txn, noteId);
        return _read(txn, noteId);
      });
    } on NoteNotFoundException {
      rethrow;
    } on DatabaseException {
      throw CacheException();
    }
  }

  @override
  Future<CustomerNote> setPaymentMethod({
    required String noteId,
    required PaymentMethod? paymentMethod,
  }) async {
    final db = await openDatabase();
    try {
      return await db.transaction((txn) async {
        final current = await _read(txn, noteId);
        await _purgeExtraDrafts(
          txn,
          customerId: current.customerId,
          keepId: noteId,
        );
        await _touchDraft(
          txn,
          noteId,
          paymentMethod: paymentMethod,
          replacePaymentMethod: true,
        );
        await _queueNote(txn, noteId);
        return _read(txn, noteId);
      });
    } on NoteNotFoundException {
      rethrow;
    } on DatabaseException {
      throw CacheException();
    }
  }

  @override
  Future<CustomerNote> deleteNote(String noteId) async {
    final db = await openDatabase();
    try {
      return await db.transaction((txn) async {
        final current = await _read(txn, noteId);
        if (current.status != NoteStatus.draft) {
          throw const NoteNotFoundException();
        }
        final now = _clock().toUtc().toIso8601String();
        final updated = await txn.update(
          'customer_notes',
          {
            'status': NoteStatus.deleted.name,
            'updated_at': now,
          },
          where: 'id = ? AND status = ?',
          whereArgs: [noteId, NoteStatus.draft.name],
        );
        if (updated != 1) throw const NoteNotFoundException();
        await _queueNote(txn, noteId);

        final draftId = _newId();
        await txn.insert('customer_notes', {
          'id': draftId,
          'customer_id': current.customerId,
          'status': NoteStatus.draft.name,
          'due_on': null,
          'payment_method': null,
          'created_at': now,
          'updated_at': now,
        });
        await _purgeExtraDrafts(
          txn,
          customerId: current.customerId,
          keepId: draftId,
        );
        return _read(txn, draftId);
      });
    } on NoteNotFoundException {
      rethrow;
    } on DatabaseException {
      throw CacheException();
    }
  }

  @override
  Future<List<CustomerNote>> deletedNotes(String customerId) async {
    final db = await openDatabase();
    final rows = await db.query(
      'customer_notes',
      columns: ['id'],
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, NoteStatus.deleted.name],
      orderBy: 'updated_at DESC, id DESC',
    );
    return [for (final row in rows) await _read(db, row['id']! as String)];
  }

  NoteLineDraft _checked(NoteLineDraft line) {
    if (line.name.trim().isEmpty) {
      throw const NoteRuleException('Informe o nome do item.');
    }
    if (line.quantity <= 0) {
      throw const NoteRuleException('Informe uma quantidade maior que zero.');
    }
    if (line.unitPriceCents < 0) {
      throw const NoteRuleException('Informe um preço válido.');
    }
    return line;
  }

  Future<void> _queueNote(DatabaseExecutor txn, String noteId) {
    final recordedAt = _clock().toUtc().toIso8601String();
    return enqueueSync(
      txn,
      id: 'note:$noteId',
      kind: 'note',
      recordedAt: recordedAt,
      payload: noteId,
    );
  }

  Future<void> _touchDraft(
    Transaction txn,
    String noteId, {
    DateTime? dueOn,
    bool replaceDueOn = false,
    PaymentMethod? paymentMethod,
    bool replacePaymentMethod = false,
  }) async {
    final values = <String, Object?>{
      'updated_at': _clock().toUtc().toIso8601String(),
    };
    if (replaceDueOn) values['due_on'] = _dateText(dueOn);
    if (replacePaymentMethod) {
      values['payment_method'] = paymentMethod?.name;
    }
    final updated = await txn.update(
      'customer_notes',
      values,
      where: 'id = ? AND status = ?',
      whereArgs: [noteId, NoteStatus.draft.name],
    );
    if (updated != 1) throw const NoteNotFoundException();
  }

  /// Enforces one open draft per customer. Prefer [keepId] when provided,
  /// otherwise keep the newest `updated_at`.
  Future<void> _purgeExtraDrafts(
    DatabaseExecutor txn, {
    required String customerId,
    String? keepId,
  }) async {
    final rows = await txn.query(
      'customer_notes',
      columns: ['id', 'updated_at'],
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, NoteStatus.draft.name],
      orderBy: 'updated_at DESC, id DESC',
    );
    if (rows.length <= 1) return;
    final survivor =
        keepId ??
        (rows.first['id']! as String);
    await txn.delete(
      'customer_notes',
      where: 'customer_id = ? AND status = ? AND id != ?',
      whereArgs: [customerId, NoteStatus.draft.name, survivor],
    );
  }

  Future<CustomerNote> _read(DatabaseExecutor txn, String id) async {
    final rows = await txn.query(
      'customer_notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw const NoteNotFoundException();
    final row = rows.first;
    final lineRows = await txn.query(
      'customer_note_lines',
      where: 'note_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    return CustomerNote(
      id: row['id']! as String,
      customerId: row['customer_id']! as String,
      status: NoteStatus.values.byName(row['status']! as String),
      dueOn: _date(row['due_on']),
      paymentMethod: _paymentMethod(row['payment_method']),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      lines: [
        for (final line in lineRows)
          NoteLine(
            id: line['id']! as String,
            productId: line['product_id'] as String?,
            name: line['name']! as String,
            unit: CatalogUnit.values.byName(line['unit']! as String),
            quantity: line['quantity']! as int,
            unitPriceCents: line['unit_price_cents']! as int,
            referencePriceCents: line['reference_price_cents'] as int?,
          ),
      ],
    );
  }
}

PaymentMethod? _paymentMethod(Object? value) {
  if (value is! String || value.isEmpty) return null;
  for (final method in PaymentMethod.values) {
    if (method.name == value) return method;
  }
  return null;
}

String? _dateText(DateTime? date) {
  if (date == null) return null;
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  final parts = (value as String).split('-');
  if (parts.length != 3) return null;
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
