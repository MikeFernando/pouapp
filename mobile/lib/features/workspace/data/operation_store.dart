import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../catalog/data/operational_schema.dart';
import '../domain/entities/street_ledger.dart';
import 'datasources/street_seed.dart';
import 'models/street_ledger_codec.dart';

class OperationImportException implements Exception {
  const OperationImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Street ledger and customer drafts stored in the catalog database.
///
/// The SharedPreferences ledger and the customer-file drafts stay as the
/// origin. This store becomes the only reader and writer after one verified
/// transaction. Freight is not part of this store.
class OperationStore {
  OperationStore({
    required this.openDatabase,
    required this.readStreetOrigin,
    required this.openCustomerDatabase,
    DateTime Function()? clock,
    this.beforeCommit,
  }) : _clock = clock ?? DateTime.now;

  final Future<Database> Function() openDatabase;
  final String? Function() readStreetOrigin;
  final Future<Database> Function() openCustomerDatabase;
  final DateTime Function() _clock;

  /// Test hook. Runs inside the import transaction, after the copy and the
  /// check, before the source is marked active.
  void Function()? beforeCommit;

  Future<void>? _running;
  bool _ready = false;

  Future<Database> database() => openDatabase();

  Future<bool> isActive() async {
    final db = await openDatabase();
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: const [operationSourceKey],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == operationSourceSqlite;
  }

  Future<void> ensureActive() async {
    if (_ready) return;
    final running = _running;
    if (running != null) return running;
    final run = _ensure();
    _running = run;
    try {
      await run;
    } finally {
      _running = null;
    }
  }

  Future<void> _ensure() async {
    if (await isActive()) {
      _ready = true;
      return;
    }
    await _import();
    _ready = await isActive();
  }

  Future<StreetLedger> readLedger() async {
    final db = await openDatabase();
    return _readLedger(db);
  }

  Future<void> writeLedger(StreetLedger ledger) async {
    if (!await isActive()) {
      throw const OperationImportException(
        'A operação ainda não está na base ativa.',
      );
    }
    final db = await openDatabase();
    await db.transaction((txn) async {
      await _replaceLedger(txn, ledger, legacyOverride: null);
    });
  }

  Future<void> _import() async {
    final raw = readStreetOrigin();
    final StreetLedger ledger;
    try {
      ledger = withPersonNames(
        raw == null || raw.isEmpty
            ? seedStreetLedger(today: _clock())
            : decodeStreetLedger(raw),
      );
    } on FormatException {
      return;
    } catch (_) {
      return;
    }
    final customer = await openCustomerDatabase();
    final notes = await _noteRows(customer);
    final lines = await _noteLineRows(customer);
    final db = await openDatabase();
    await db.transaction((txn) async {
      await _replaceLedger(txn, ledger, legacyOverride: true);
      await _replaceNotes(txn, notes, lines);
      final copied = await _readLedger(txn);
      final copiedNotes = await txn.query('customer_notes');
      final copiedLines = await txn.query('customer_note_lines');
      _expectSame(ledger, copied, notes, copiedNotes, lines, copiedLines);
      final now = _clock().toIso8601String();
      await txn.insert('operation_import', {
        'id': 1,
        'origin_json': raw ?? encodeStreetLedger(ledger),
        'visits': ledger.visits.length,
        'orders': ledger.orders.length,
        'order_lines': _lineCount(ledger),
        'payments': ledger.payments.length,
        'payment_shares': _shareCount(ledger),
        'agreements': ledger.agreements.length,
        'notes': notes.length,
        'note_lines': lines.length,
        'order_total_cents': _orderTotal(ledger),
        'payment_total_cents': _paymentTotal(ledger),
        'imported_at': now,
      });
      final hook = beforeCommit;
      if (hook != null) hook();
      await txn.insert('app_meta', {
        'key': operationSourceKey,
        'value': operationSourceSqlite,
      });
    });
  }
}

Future<List<Map<String, Object?>>> _noteRows(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customer_notes'",
  );
  if (tables.isEmpty) return const [];
  return db.query('customer_notes', orderBy: 'id ASC');
}

Future<List<Map<String, Object?>>> _noteLineRows(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customer_note_lines'",
  );
  if (tables.isEmpty) return const [];
  return db.query('customer_note_lines', orderBy: 'id ASC');
}

Future<void> _replaceNotes(
  DatabaseExecutor txn,
  List<Map<String, Object?>> notes,
  List<Map<String, Object?>> lines,
) async {
  await txn.delete('customer_note_lines');
  await txn.delete('customer_notes');
  for (final note in notes) {
    await txn.insert('customer_notes', {
      'id': note['id'],
      'customer_id': note['customer_id'],
      'status': note['status'],
      'due_on': note['due_on'],
      'created_at': note['created_at'],
      'updated_at': note['updated_at'],
    });
  }
  for (final line in lines) {
    await txn.insert('customer_note_lines', {
      'id': line['id'],
      'note_id': line['note_id'],
      'position': line['position'],
      'product_id': line['product_id'],
      'name': line['name'],
      'unit': line['unit'],
      'quantity': line['quantity'],
      'unit_price_cents': line['unit_price_cents'],
      'reference_price_cents':
          line['reference_price_cents'] ?? line['unit_price_cents'],
    });
  }
}

Future<void> _replaceLedger(
  DatabaseExecutor txn,
  StreetLedger ledger, {
  required bool? legacyOverride,
}) async {
  await txn.delete('street_order_lines');
  await txn.delete('street_payment_shares');
  await txn.delete('street_orders');
  await txn.delete('street_payments');
  await txn.delete('street_visits');
  await txn.delete('street_agreements');
  await txn.delete('street_state');
  await txn.insert('street_state', {
    'id': 1,
    'day': ledger.day,
    'next_number': ledger.nextNumber,
  });
  for (final visit in ledger.visits) {
    await txn.insert('street_visits', {
      'id': visit.id,
      'customer_id': visit.customerId,
      'customer_name': visit.customerName,
      'address': visit.address,
      'reasons': jsonEncode([for (final reason in visit.reasons) reason.name]),
      'status': visit.status.name,
      'position': visit.position,
      'day': visit.day,
      'note': visit.note,
      'rescheduled_to': visit.rescheduledTo,
      'legacy': _bit(_keptLegacy(legacyOverride, visit.legacy)),
    });
  }
  for (final order in ledger.orders) {
    await txn.insert('street_orders', {
      'id': order.id,
      'code': order.code,
      'customer_id': order.customerId,
      'customer_name': order.customerName,
      'recorded': _bit(order.recorded),
      'delivered': _bit(order.delivered),
      'created_visit_id': order.createdVisitId,
      'delivered_during_visit_id': order.deliveredDuringVisitId,
      'corrected_during_visit_id': order.correctedDuringVisitId,
      'from_seed': _bit(order.fromSeed),
      'note': order.note,
      'legacy': _bit(_keptLegacy(legacyOverride, order.legacy)),
      'occurred_on': order.occurredOn,
      'recorded_at': order.recordedAt,
    });
    await _insertLines(txn, order.id, 0, order.lines);
    for (var index = 0; index < order.revisions.length; index++) {
      await _insertLines(
        txn,
        order.id,
        index + 1,
        order.revisions[index].lines,
      );
    }
  }
  for (final payment in ledger.payments) {
    await txn.insert('street_payments', {
      'id': payment.id,
      'customer_id': payment.customerId,
      'amount_cents': payment.amountCents,
      'paid_on': payment.paidOn,
      'method': payment.method.name,
      'visit_id': payment.visitId,
      'from_seed': _bit(payment.fromSeed),
      'note': payment.note,
      'legacy': _bit(_keptLegacy(legacyOverride, payment.legacy)),
      'recorded_at': null,
    });
    for (final share in payment.shares) {
      await txn.insert('street_payment_shares', {
        'payment_id': payment.id,
        'order_id': share.orderId,
        'amount_cents': share.amountCents,
      });
    }
  }
  for (final agreement in ledger.agreements) {
    await txn.insert('street_agreements', {
      'id': agreement.id,
      'customer_id': agreement.customerId,
      'agreed_on': agreement.agreedOn,
      'visit_id': agreement.visitId,
      'note': agreement.note,
      'legacy': _bit(_keptLegacy(legacyOverride, agreement.legacy)),
    });
  }
}

Future<void> _insertLines(
  DatabaseExecutor txn,
  String orderId,
  int generation,
  List<SaleLine> lines,
) async {
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    await txn.insert('street_order_lines', {
      'order_id': orderId,
      'generation': generation,
      'line_index': index,
      'product_name': line.productName,
      'quantity': line.quantity,
      'unit': line.unit.name,
      'unit_price_cents': line.unitPriceCents,
      'product_id': null,
    });
  }
}

Future<StreetLedger> _readLedger(DatabaseExecutor db) async {
  final state = await db.query('street_state', limit: 1);
  if (state.isEmpty) {
    throw const OperationImportException('A operação importada está vazia.');
  }
  final row = state.first;
  final visits = await db.query(
    'street_visits',
    orderBy: 'position ASC, id ASC',
  );
  final orders = await db.query('street_orders', orderBy: 'code ASC, id ASC');
  final lines = await db.query(
    'street_order_lines',
    orderBy: 'order_id ASC, generation ASC, line_index ASC',
  );
  final payments = await db.query('street_payments', orderBy: 'id ASC');
  final shares = await db.query(
    'street_payment_shares',
    orderBy: 'payment_id ASC',
  );
  final agreements = await db.query('street_agreements', orderBy: 'id ASC');
  final linesByOrder = <String, Map<int, List<SaleLine>>>{};
  for (final line in lines) {
    final orderId = line['order_id']! as String;
    final generation = line['generation']! as int;
    final grouped = linesByOrder.putIfAbsent(orderId, () => {});
    grouped.putIfAbsent(generation, () => []).add(_saleLine(line));
  }
  final sharesByPayment = <String, List<PaymentShare>>{};
  for (final share in shares) {
    final paymentId = share['payment_id']! as String;
    sharesByPayment
        .putIfAbsent(paymentId, () => [])
        .add(
          PaymentShare(
            orderId: share['order_id']! as String,
            amountCents: share['amount_cents']! as int,
          ),
        );
  }
  return StreetLedger(
    day: row['day']! as String,
    nextNumber: row['next_number']! as int,
    visits: [for (final visit in visits) _visit(visit)],
    orders: [
      for (final order in orders)
        _order(order, linesByOrder[order['id'] as String] ?? const {}),
    ],
    payments: [
      for (final payment in payments)
        _payment(payment, sharesByPayment[payment['id'] as String] ?? const []),
    ],
    agreements: [for (final agreement in agreements) _agreement(agreement)],
  );
}

RouteVisit _visit(Map<String, Object?> row) {
  final reasons = jsonDecode(row['reasons']! as String) as List<dynamic>;
  return RouteVisit(
    id: row['id']! as String,
    customerId: row['customer_id']! as String,
    customerName: row['customer_name']! as String,
    address: row['address']! as String,
    reasons: [
      for (final reason in reasons) VisitReason.values.byName(reason as String),
    ],
    status: VisitStatus.values.byName(row['status']! as String),
    position: row['position']! as int,
    day: row['day']! as String,
    note: row['note'] as String?,
    rescheduledTo: row['rescheduled_to'] as String?,
    legacy: row['legacy'] == 1,
  );
}

SaleOrder _order(Map<String, Object?> row, Map<int, List<SaleLine>> lines) {
  final generations = lines.keys.toList()..sort();
  return SaleOrder(
    id: row['id']! as String,
    code: row['code']! as String,
    customerId: row['customer_id']! as String,
    customerName: row['customer_name']! as String,
    lines: lines[0] ?? const [],
    recorded: row['recorded'] == 1,
    delivered: row['delivered'] == 1,
    createdVisitId: row['created_visit_id'] as String?,
    deliveredDuringVisitId: row['delivered_during_visit_id'] as String?,
    correctedDuringVisitId: row['corrected_during_visit_id'] as String?,
    revisions: [
      for (final generation in generations)
        if (generation > 0) SaleRevision(lines: lines[generation]!),
    ],
    fromSeed: row['from_seed'] == 1,
    note: row['note'] as String?,
    occurredOn: row['occurred_on'] as String?,
    recordedAt: row['recorded_at'] as String?,
    legacy: row['legacy'] == 1,
  );
}

CustomerPayment _payment(Map<String, Object?> row, List<PaymentShare> shares) {
  return CustomerPayment(
    id: row['id']! as String,
    customerId: row['customer_id']! as String,
    amountCents: row['amount_cents']! as int,
    paidOn: row['paid_on']! as String,
    method: PaymentMethod.values.byName(row['method']! as String),
    visitId: row['visit_id'] as String?,
    shares: shares,
    fromSeed: row['from_seed'] == 1,
    note: row['note'] as String?,
    legacy: row['legacy'] == 1,
  );
}

PaymentAgreement _agreement(Map<String, Object?> row) {
  return PaymentAgreement(
    id: row['id']! as String,
    customerId: row['customer_id']! as String,
    agreedOn: row['agreed_on']! as String,
    visitId: row['visit_id'] as String?,
    note: row['note'] as String?,
    legacy: row['legacy'] == 1,
  );
}

SaleLine _saleLine(Map<String, Object?> row) {
  return SaleLine(
    productName: row['product_name']! as String,
    quantity: (row['quantity']! as num).toDouble(),
    unit: SaleUnit.values.byName(row['unit']! as String),
    unitPriceCents: row['unit_price_cents']! as int,
  );
}

void _expectSame(
  StreetLedger source,
  StreetLedger copied,
  List<Map<String, Object?>> notes,
  List<Map<String, Object?>> copiedNotes,
  List<Map<String, Object?>> lines,
  List<Map<String, Object?>> copiedLines,
) {
  if (copied.visits.length != source.visits.length ||
      copied.orders.length != source.orders.length ||
      copied.payments.length != source.payments.length ||
      copied.agreements.length != source.agreements.length ||
      _lineCount(copied) != _lineCount(source) ||
      _shareCount(copied) != _shareCount(source) ||
      _orderTotal(copied) != _orderTotal(source) ||
      _paymentTotal(copied) != _paymentTotal(source) ||
      copied.nextNumber != source.nextNumber ||
      copied.day != source.day) {
    throw const OperationImportException(
      'A conferência da rua não fechou. A origem continua ativa.',
    );
  }
  if (copiedNotes.length != notes.length ||
      copiedLines.length != lines.length) {
    throw const OperationImportException(
      'A conferência dos rascunhos não fechou. A origem continua ativa.',
    );
  }
  final noteIds = {for (final note in notes) note['id'] as String};
  final copiedIds = {for (final note in copiedNotes) note['id'] as String};
  if (noteIds.length != copiedIds.length || !noteIds.containsAll(copiedIds)) {
    throw const OperationImportException(
      'Os rascunhos importados não batem com a origem.',
    );
  }
  for (final note in notes) {
    final match = copiedNotes.singleWhere((row) => row['id'] == note['id']);
    if (match['status'] != note['status'] ||
        match['due_on'] != note['due_on'] ||
        match['customer_id'] != note['customer_id']) {
      throw const OperationImportException(
        'Um rascunho mudou de cliente, situação ou vencimento.',
      );
    }
  }
  for (final line in lines) {
    final match = copiedLines.singleWhere((row) => row['id'] == line['id']);
    if (match['quantity'] != line['quantity'] ||
        match['unit_price_cents'] != line['unit_price_cents'] ||
        match['product_id'] != line['product_id'] ||
        match['note_id'] != line['note_id']) {
      throw const OperationImportException(
        'Um item de rascunho mudou na importação.',
      );
    }
  }
}

int _lineCount(StreetLedger ledger) {
  var count = 0;
  for (final order in ledger.orders) {
    count += order.lines.length;
    for (final revision in order.revisions) {
      count += revision.lines.length;
    }
  }
  return count;
}

int _shareCount(StreetLedger ledger) {
  return ledger.payments.fold(0, (sum, payment) => sum + payment.shares.length);
}

int _orderTotal(StreetLedger ledger) {
  return ledger.orders.fold(0, (sum, order) => sum + order.totalCents);
}

int _paymentTotal(StreetLedger ledger) {
  return ledger.payments.fold(0, (sum, payment) => sum + payment.amountCents);
}

int _bit(bool value) => value ? 1 : 0;

bool _keptLegacy(bool? override, bool value) => override ?? value;
