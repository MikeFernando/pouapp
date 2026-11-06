import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../catalog/domain/entities/catalog.dart';
import '../../customers/domain/entities/customer_note.dart';
import '../domain/entities/receivable.dart';
import '../domain/entities/street_ledger.dart';
import '../domain/rules/receivable_rules.dart';

class DeliveryException implements Exception {
  DeliveryException(this.message);

  final String message;
}

class DeliveryPayment {
  const DeliveryPayment({
    required this.id,
    required this.amountCents,
    required this.paidOn,
    required this.method,
    required this.receivableIds,
    this.tenderedCents,
    this.allowCredit = false,
    this.applyCredit = false,
    this.note,
  });

  final String id;
  final int amountCents;
  final String paidOn;
  final PaymentMethod method;
  final List<String> receivableIds;
  final int? tenderedCents;
  final bool allowCredit;
  final bool applyCredit;
  final String? note;
}

class DeliveryResult {
  const DeliveryResult({
    required this.saleId,
    required this.receivableId,
    required this.totalCents,
    required this.occurredOn,
    required this.recordedAt,
    required this.alreadyRecorded,
    this.allocations = const [],
    this.changeCents,
    this.creditCents = 0,
    this.appliedCreditCents = 0,
  });

  final String saleId;
  final String receivableId;
  final int totalCents;
  final String occurredOn;
  final String recordedAt;
  final bool alreadyRecorded;
  final List<PaymentShare> allocations;
  final int? changeCents;
  final int creditCents;
  final int appliedCreditCents;
}

String saleReceivableId(String noteId) => 'sale-$noteId';

/// Confirms a draft note: sale, Montana exit, debt and optional payment
/// share one transaction. The confirmation id is the note id.
class DeliveryStore {
  DeliveryStore({
    required this.openDatabase,
    DateTime Function()? clock,
    String Function()? newId,
    this.beforeCommit,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? _generateId;

  final Future<Database> Function() openDatabase;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Runs after the writes and before the commit. A throw rolls every
  /// effect back.
  Future<void> Function()? beforeCommit;

  String nextId() => _newId();

  Future<int> soldCents() async {
    final db = await openDatabase();
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total_cents), 0) AS total FROM door_sales',
    );
    return rows.single['total'] as int? ?? 0;
  }

  Future<DeliveryResult> confirm({
    required String noteId,
    DeliveryPayment? payment,
  }) async {
    final db = await openDatabase();
    return db.transaction((txn) async {
      final existing = await txn.query(
        'door_sales',
        where: 'id = ?',
        whereArgs: [noteId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return _existing(txn, existing.single);
      }
      final note = await _note(txn, noteId);
      if (note.status != NoteStatus.draft) {
        throw DeliveryException('Esta nota já foi entregue.');
      }
      if (note.lines.isEmpty) {
        throw DeliveryException('Inclua os produtos da entrega.');
      }
      if (note.dueOn == null) {
        throw DeliveryException('Informe o vencimento desta compra.');
      }
      final products = await _products(txn);
      final montana = await _montana(txn);
      final consumption = <String, int>{};
      final descriptions = <String>[];
      for (final line in note.lines) {
        final problem = _lineProblem(line, products);
        if (problem != null) throw DeliveryException(problem);
        final productId = line.productId!;
        consumption[productId] = (consumption[productId] ?? 0) + line.quantity;
        descriptions.add(line.name.trim());
      }
      for (final entry in consumption.entries) {
        final product = products[entry.key]!;
        final have = montana[entry.key] ?? 0;
        if (have < entry.value) {
          throw DeliveryException(
            '${product.name} não tem saldo na Montana. '
            'A entrega pede ${_quantity(product.unit, entry.value)} '
            'e há ${_quantity(product.unit, have)}.',
          );
        }
      }
      final now = _clock();
      final occurredOn = _day(now);
      final recordedAt = now.toIso8601String();
      final total = note.totalCents;
      final dueOn = _day(note.dueOn!);
      await txn.insert('door_sales', {
        'id': noteId,
        'note_id': noteId,
        'customer_id': note.customerId,
        'total_cents': total,
        'occurred_on': occurredOn,
        'recorded_at': recordedAt,
      });
      for (var index = 0; index < note.lines.length; index++) {
        final line = note.lines[index];
        await txn.insert('door_sale_lines', {
          'id': '$noteId:line:$index',
          'sale_id': noteId,
          'position': index,
          'product_id': line.productId,
          'name': line.name.trim(),
          'unit': line.unit.name,
          'quantity': line.quantity,
          'unit_price_cents': line.unitPriceCents,
        });
      }
      for (final entry in consumption.entries) {
        await txn.insert('movements', {
          'id': _newId(),
          'product_id': entry.key,
          'location_code': StockLocationCode.montana.name,
          'quantity': -entry.value,
          'kind': MovementKind.sale.name,
          'reason': 'Entrega',
          'occurred_on': occurredOn,
          'recorded_at': recordedAt,
          'idempotency_key': 'sale:$noteId:${entry.key}',
          'operation_id': noteId,
        });
      }
      final receivableId = saleReceivableId(noteId);
      await txn.insert('receivables', {
        'id': receivableId,
        'customer_id': note.customerId,
        'kind': 'sale',
        'description': 'Entrega de ${descriptions.join(', ')}',
        'amount_cents': total,
        'due_on': dueOn,
        'occurred_on': occurredOn,
        'recorded_at': recordedAt,
      });
      final selectable = await _openReceivables(txn, note.customerId);
      var allocations = const <PaymentShare>[];
      int? changeCents;
      var creditCents = 0;
      var appliedCredit = 0;
      if (payment != null) {
        if (payment.method == PaymentMethod.card) {
          throw DeliveryException('Este recebimento aceita dinheiro ou Pix.');
        }
        final byId = {for (final item in selectable) item.id: item};
        final selected = [
          for (final id in payment.receivableIds)
            if (byId[id] != null) byId[id]!,
        ];
        final plan = planReceipt(
          amountCents: payment.amountCents,
          selected: selected,
          tenderedCents: payment.tenderedCents,
          allowCredit: payment.allowCredit,
        );
        if (plan.error != null) throw DeliveryException(plan.error!);
        final creditBefore = payment.applyCredit
            ? await _creditSource(txn, note.customerId)
            : null;
        if (payment.applyCredit && creditBefore == null) {
          throw DeliveryException('Não há crédito para usar.');
        }
        final duplicate = await txn.query(
          'customer_receipts',
          where: 'id = ?',
          whereArgs: [payment.id],
          limit: 1,
        );
        if (duplicate.isNotEmpty) {
          throw DeliveryException('Este recebimento já foi registrado.');
        }
        await txn.insert('customer_receipts', {
          'id': payment.id,
          'customer_id': note.customerId,
          'amount_cents': payment.amountCents,
          'tendered_cents': payment.tenderedCents,
          'change_cents': plan.changeCents,
          'credit_cents': plan.creditCents,
          'paid_on': payment.paidOn,
          'method': payment.method.name,
          'note': _blank(payment.note),
          'recorded_at': recordedAt,
        });
        for (final share in plan.allocations) {
          await txn.insert('receipt_allocations', {
            'receipt_id': payment.id,
            'receivable_id': share.orderId,
            'amount_cents': share.amountCents,
          });
        }
        allocations = plan.allocations;
        changeCents = plan.changeCents;
        creditCents = plan.creditCents;
        if (creditBefore != null) {
          final uses = planCreditUse(
            availableCents: creditBefore.available,
            selected: selected,
            alreadyAllocated: plan.allocations,
          );
          for (final share in uses) {
            await txn.insert('credit_applications', {
              'id': _newId(),
              'receipt_id': creditBefore.receiptId,
              'receivable_id': share.orderId,
              'amount_cents': share.amountCents,
              'recorded_at': recordedAt,
            });
            appliedCredit += share.amountCents;
          }
        }
      }
      final updated = await txn.update(
        'customer_notes',
        {'status': NoteStatus.delivered.name, 'updated_at': recordedAt},
        where: 'id = ? AND status = ?',
        whereArgs: [noteId, NoteStatus.draft.name],
      );
      if (updated != 1) {
        throw DeliveryException('Esta nota já foi entregue.');
      }
      await txn.insert('pending_sync', {
        'id': noteId,
        'kind': 'delivery',
        'status': 'local',
        'recorded_at': recordedAt,
      });
      if (beforeCommit != null) await beforeCommit!();
      return DeliveryResult(
        saleId: noteId,
        receivableId: receivableId,
        totalCents: total,
        occurredOn: occurredOn,
        recordedAt: recordedAt,
        alreadyRecorded: false,
        allocations: allocations,
        changeCents: changeCents,
        creditCents: creditCents,
        appliedCreditCents: appliedCredit,
      );
    }, exclusive: true);
  }

  Future<DeliveryResult> _existing(
    DatabaseExecutor txn,
    Map<String, Object?> row,
  ) async {
    final id = row['id']! as String;
    final allocations = await txn.rawQuery(
      '''
      SELECT a.receivable_id, a.amount_cents
      FROM receipt_allocations a
      JOIN receivables r ON r.id = a.receivable_id
      WHERE r.id = ?
      ''',
      [saleReceivableId(id)],
    );
    return DeliveryResult(
      saleId: id,
      receivableId: saleReceivableId(id),
      totalCents: row['total_cents']! as int,
      occurredOn: row['occurred_on']! as String,
      recordedAt: row['recorded_at']! as String,
      alreadyRecorded: true,
      allocations: [
        for (final share in allocations)
          PaymentShare(
            orderId: share['receivable_id']! as String,
            amountCents: share['amount_cents']! as int,
          ),
      ],
    );
  }

  String? _lineProblem(NoteLine line, Map<String, _Product> products) {
    final productId = line.productId;
    if (productId == null || productId.isEmpty) {
      return 'O item ${line.name} não está ligado ao estoque. '
          'A confirmação não converte pelo nome.';
    }
    final product = products[productId];
    if (product == null) return 'Produto não encontrado.';
    if (!product.active) {
      return '${product.name} está inativo e não pode ser vendido.';
    }
    if (product.unit != line.unit) {
      return '${product.name} está em ${_unit(product.unit)} no estoque. '
          'Esta nota pede ${_unit(line.unit)} e não há conversão cadastrada.';
    }
    return null;
  }

  Future<CustomerNote> _note(DatabaseExecutor txn, String id) async {
    final rows = await txn.query(
      'customer_notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw DeliveryException('Nota não encontrada.');
    final row = rows.single;
    final lines = await txn.query(
      'customer_note_lines',
      where: 'note_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    return CustomerNote(
      id: id,
      customerId: row['customer_id']! as String,
      status: NoteStatus.values.byName(row['status']! as String),
      dueOn: _date(row['due_on'] as String?),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      lines: [
        for (final line in lines)
          NoteLine(
            id: line['id']! as String,
            productId: line['product_id'] as String?,
            name: line['name']! as String,
            unit: CatalogUnit.values.byName(line['unit']! as String),
            quantity: line['quantity']! as int,
            unitPriceCents: line['unit_price_cents']! as int,
          ),
      ],
    );
  }

  Future<Map<String, _Product>> _products(DatabaseExecutor txn) async {
    final rows = await txn.query('products');
    return {
      for (final row in rows)
        row['id']! as String: _Product(
          name: row['name']! as String,
          unit: CatalogUnit.values.byName(row['unit']! as String),
          active: (row['active']! as int) == 1,
        ),
    };
  }

  Future<Map<String, int>> _montana(DatabaseExecutor txn) async {
    final rows = await txn.rawQuery(
      '''
      SELECT product_id, COALESCE(SUM(quantity), 0) AS total
      FROM movements
      WHERE location_code = ?
      GROUP BY product_id
      ''',
      [StockLocationCode.montana.name],
    );
    return {
      for (final row in rows)
        row['product_id']! as String: row['total']! as int,
    };
  }

  Future<List<Receivable>> _openReceivables(
    DatabaseExecutor txn,
    String customerId,
  ) async {
    final rows = await txn.query(
      'receivables',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'occurred_on ASC, id ASC',
    );
    final allocated = await _allocated(txn);
    final result = <Receivable>[];
    for (final row in rows) {
      final id = row['id']! as String;
      final amount = row['amount_cents']! as int;
      final open = amount - (allocated[id] ?? 0);
      if (open <= 0) continue;
      result.add(
        Receivable(
          id: id,
          customerId: customerId,
          description: row['description']! as String,
          amountCents: amount,
          openCents: open,
          occurredOn: row['occurred_on']! as String,
          dueOn: row['due_on'] as String?,
        ),
      );
    }
    return result;
  }

  Future<Map<String, int>> _allocated(DatabaseExecutor txn) async {
    final rows = await txn.rawQuery('''
      SELECT receivable_id, COALESCE(SUM(amount_cents), 0) AS total
      FROM (
        SELECT a.receivable_id AS receivable_id, a.amount_cents AS amount_cents
        FROM receipt_allocations a
        JOIN customer_receipts r ON r.id = a.receipt_id
        LEFT JOIN receipt_reversals v ON v.receipt_id = r.id
        WHERE v.id IS NULL
        UNION ALL
        SELECT c.receivable_id, c.amount_cents
        FROM credit_applications c
        JOIN customer_receipts r ON r.id = c.receipt_id
        LEFT JOIN receipt_reversals v ON v.receipt_id = r.id
        WHERE v.id IS NULL
      )
      GROUP BY receivable_id
    ''');
    return {
      for (final row in rows)
        row['receivable_id']! as String: row['total']! as int,
    };
  }

  Future<_CreditSource?> _creditSource(
    DatabaseExecutor txn,
    String customerId,
  ) async {
    final rows = await txn.rawQuery(
      '''
      SELECT r.id, r.credit_cents,
             COALESCE((
               SELECT SUM(c.amount_cents)
               FROM credit_applications c
               WHERE c.receipt_id = r.id
             ), 0) AS used
      FROM customer_receipts r
      LEFT JOIN receipt_reversals v ON v.receipt_id = r.id
      WHERE r.customer_id = ? AND v.id IS NULL AND r.credit_cents > 0
      ORDER BY r.recorded_at ASC
      ''',
      [customerId],
    );
    if (rows.isEmpty) return null;
    final first = rows.first;
    final available = (first['credit_cents']! as int) - (first['used']! as int);
    if (available <= 0) return null;
    return _CreditSource(
      receiptId: first['id']! as String,
      available: available,
    );
  }
}

class _CreditSource {
  const _CreditSource({required this.receiptId, required this.available});

  final String receiptId;
  final int available;
}

class _Product {
  const _Product({
    required this.name,
    required this.unit,
    required this.active,
  });

  final String name;
  final CatalogUnit unit;
  final bool active;
}

String _unit(CatalogUnit unit) {
  return switch (unit) {
    CatalogUnit.kilogram => 'kg',
    CatalogUnit.piece => 'un',
    CatalogUnit.bunch => 'maço',
    CatalogUnit.box => 'cx',
    CatalogUnit.dozen => 'dúzia',
  };
}

String _quantity(CatalogUnit unit, int quantity) {
  if (unit == CatalogUnit.kilogram) {
    final text = (quantity / 1000).toStringAsFixed(3);
    final trimmed = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '${trimmed.replaceAll('.', ',')} kg';
  }
  return '$quantity ${_unit(unit)}';
}

String _day(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? _date(String? value) {
  if (value == null) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String? _blank(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

String _generateId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
