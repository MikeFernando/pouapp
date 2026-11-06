import 'package:sqflite/sqflite.dart';

import '../../../../core/error/exceptions.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../domain/entities/customer_note.dart';
import '../../../catalog/data/operational_schema.dart';
import '../exceptions/note_exceptions.dart';
import 'customer_local_data_source.dart';

abstract class CustomerNoteLocalDataSource {
  Future<CustomerNote> activeDraft(String customerId);

  /// Draft when one is open, otherwise the latest delivery. Creates a draft
  /// only when the customer has neither.
  Future<CustomerNote> openNote(String customerId);

  Future<CustomerNote?> currentNote(String customerId);

  Future<CustomerNote> note(String id);

  Future<CustomerNote> saveLines({
    required String noteId,
    required List<NoteLineDraft> lines,
  });

  Future<CustomerNote> setDueOn({
    required String noteId,
    required DateTime? dueOn,
  });
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
          'created_at': now,
          'updated_at': now,
        });
        return _read(txn, id);
      });
    } on DatabaseException catch (error) {
      if (!error.isUniqueConstraintError()) throw CacheException();
      final db = await openDatabase();
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
        await txn.delete(
          'customer_note_lines',
          where: 'note_id = ?',
          whereArgs: [noteId],
        );
        for (var index = 0; index < prepared.length; index++) {
          final line = prepared[index];
          await txn.insert('customer_note_lines', {
            'id': line.id ?? _newId(),
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
  }) async {
    final values = <String, Object?>{
      'updated_at': _clock().toUtc().toIso8601String(),
    };
    if (replaceDueOn) values['due_on'] = _dateText(dueOn);
    final updated = await txn.update(
      'customer_notes',
      values,
      where: 'id = ? AND status = ?',
      whereArgs: [noteId, NoteStatus.draft.name],
    );
    if (updated != 1) throw const NoteNotFoundException();
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
