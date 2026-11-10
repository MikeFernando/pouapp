import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../catalog/data/operational_schema.dart';
import '../domain/entities/posted_sale.dart';
import '../domain/entities/receivable.dart';
import '../domain/entities/street_ledger.dart';
import '../domain/rules/receivable_rules.dart';

class ReceivableException implements Exception {
  ReceivableException(this.message);

  final String message;
}

/// Receivables, receipts and charge preparations on the catalog connection.
///
/// Street sales, drafts and stock movements are not written here. Repeating a
/// receipt id does not allocate again. A reversal keeps the original row.
class ReceivableStore {
  ReceivableStore({
    required this.openDatabase,
    DateTime Function()? clock,
    String Function()? newId,
    this.beforeCommit,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? _generateId;

  final Future<Database> Function() openDatabase;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Test hook inside the receipt transaction, after the insert and before
  /// the commit.
  Future<void> Function()? beforeCommit;

  String nextId() => _newId();

  Future<Receivable> openDebt({
    required String id,
    required String customerId,
    required int amountCents,
    String description = 'Saldo inicial',
    String? dueOn,
  }) async {
    if (amountCents <= 0) {
      throw ReceivableException('O saldo inicial precisa ser maior que zero.');
    }
    final db = await openDatabase();
    final now = _clock();
    await db.transaction((txn) async {
      final existing = await txn.query(
        'receivables',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) return;
      await txn.insert('receivables', {
        'id': id,
        'customer_id': customerId,
        'kind': 'opening',
        'description': description.trim().isEmpty
            ? 'Saldo inicial'
            : description.trim(),
        'amount_cents': amountCents,
        'due_on': dueOn,
        'occurred_on': _day(now),
        'recorded_at': now.toIso8601String(),
      });
    }, exclusive: true);
    final account = await this.account(customerId);
    return account.receivables.firstWhere((item) => item.id == id);
  }

  Future<void> updateDueOn({
    required String id,
    required String? dueOn,
  }) async {
    final db = await openDatabase();
    final updated = await db.update(
      'receivables',
      {'due_on': dueOn},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      throw ReceivableException('Dívida não encontrada.');
    }
  }

  Future<AccountReceipt> confirmReceipt({
    required String id,
    required String customerId,
    required int amountCents,
    required String paidOn,
    required PaymentMethod method,
    required List<String> receivableIds,
    int? tenderedCents,
    bool allowCredit = false,
    String? note,
  }) async {
    if (method == PaymentMethod.card) {
      throw ReceivableException('Este recebimento aceita dinheiro ou Pix.');
    }
    final db = await openDatabase();
    return db.transaction((txn) async {
      final existing = await txn.query(
        'customer_receipts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return _receipt(txn, existing.single, alreadyRecorded: true);
      }
      final open = await _openReceivables(txn, customerId);
      final selected = [
        for (final item in open)
          if (receivableIds.contains(item.id)) item,
      ];
      final plan = planReceipt(
        amountCents: amountCents,
        selected: selected,
        tenderedCents: tenderedCents,
        allowCredit: allowCredit,
      );
      if (plan.error != null) throw ReceivableException(plan.error!);
      final now = _clock();
      await txn.insert('customer_receipts', {
        'id': id,
        'customer_id': customerId,
        'amount_cents': amountCents,
        'tendered_cents': tenderedCents,
        'change_cents': plan.changeCents,
        'credit_cents': plan.creditCents,
        'paid_on': paidOn,
        'method': method.name,
        'note': _blank(note),
        'recorded_at': now.toIso8601String(),
      });
      for (final share in plan.allocations) {
        await txn.insert('receipt_allocations', {
          'receipt_id': id,
          'receivable_id': share.orderId,
          'amount_cents': share.amountCents,
        });
      }
      await enqueueSync(
        txn,
        id: 'receipt:$id',
        kind: 'receipt',
        recordedAt: now.toIso8601String(),
        payload: id,
      );
      if (beforeCommit != null) await beforeCommit!();
      return _receipt(txn, {
        'id': id,
        'customer_id': customerId,
        'amount_cents': amountCents,
        'tendered_cents': tenderedCents,
        'change_cents': plan.changeCents,
        'credit_cents': plan.creditCents,
        'paid_on': paidOn,
        'method': method.name,
        'note': _blank(note),
      });
    }, exclusive: true);
  }

  Future<AccountReversal> reverseReceipt({
    required String reversalId,
    required String receiptId,
    String? reason,
  }) async {
    final db = await openDatabase();
    return db.transaction((txn) async {
      final byId = await txn.query(
        'receipt_reversals',
        where: 'id = ?',
        whereArgs: [reversalId],
        limit: 1,
      );
      if (byId.isNotEmpty) {
        return _reversal(byId.single, alreadyRecorded: true);
      }
      final byReceipt = await txn.query(
        'receipt_reversals',
        where: 'receipt_id = ?',
        whereArgs: [receiptId],
        limit: 1,
      );
      if (byReceipt.isNotEmpty) {
        return _reversal(byReceipt.single, alreadyRecorded: true);
      }
      final receipts = await txn.query(
        'customer_receipts',
        where: 'id = ?',
        whereArgs: [receiptId],
        limit: 1,
      );
      if (receipts.isEmpty) {
        throw ReceivableException('Pagamento não encontrado.');
      }
      final receipt = receipts.single;
      await txn.insert('receipt_reversals', {
        'id': reversalId,
        'receipt_id': receiptId,
        'method': receipt['method'],
        'amount_cents': receipt['amount_cents'],
        'reason': _blank(reason),
        'recorded_at': _clock().toIso8601String(),
      });
      return AccountReversal(
        id: reversalId,
        receiptId: receiptId,
        method: PaymentMethod.values.byName(receipt['method']! as String),
        amountCents: receipt['amount_cents']! as int,
        reason: _blank(reason),
      );
    }, exclusive: true);
  }

  Future<CustomerAccount> account(String customerId) async {
    final db = await openDatabase();
    final receivables = await _openReceivables(
      db,
      customerId,
      includePaid: true,
    );
    final receiptRows = await db.query(
      'customer_receipts',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'recorded_at ASC, id ASC',
    );
    final appliedCredit = await _appliedCredit(db);
    final receipts = <AccountReceipt>[];
    for (final row in receiptRows) {
      receipts.add(
        await _receipt(
          db,
          row,
          appliedCreditCents: appliedCredit[row['id']! as String] ?? 0,
        ),
      );
    }
    final charges = await db.query(
      'charge_preparations',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at ASC',
    );
    return CustomerAccount(
      customerId: customerId,
      receivables: receivables,
      receipts: receipts,
      charges: [for (final row in charges) _charge(row)],
    );
  }

  /// Every receivable, with the money explicitly applied to it.
  ///
  /// A reversed receipt and unused credit are not part of [PostedSale.allocatedCents].
  Future<List<PostedSale>> postedSales() async {
    final db = await openDatabase();
    final rows = await db.query(
      'receivables',
      orderBy: 'occurred_on ASC, id ASC',
    );
    final allocated = await _allocated(db);
    return [
      for (final row in rows)
        PostedSale(
          id: row['id']! as String,
          customerId: row['customer_id']! as String,
          customerName: '',
          totalCents: row['amount_cents']! as int,
          allocatedCents: allocated[row['id']! as String] ?? 0,
          occurredOn: row['occurred_on']! as String,
          dueOn: row['due_on'] as String?,
          sale: row['kind'] == 'sale',
        ),
    ];
  }

  Future<int> companyOpenCents() async {
    final db = await openDatabase();
    final rows = await db.query('receivables');
    final customers = {for (final row in rows) row['customer_id']! as String};
    var total = 0;
    for (final customerId in customers) {
      final account = await this.account(customerId);
      if (account.balanceCents > 0) total += account.balanceCents;
    }
    return total;
  }

  Future<int> netReceivedCents() async {
    final db = await openDatabase();
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(r.amount_cents), 0) AS total
      FROM customer_receipts r
      LEFT JOIN receipt_reversals v ON v.receipt_id = r.id
      WHERE v.id IS NULL
    ''');
    return rows.single['total'] as int? ?? 0;
  }

  Future<List<CustomerPayment>> paymentsForIndicators() async {
    final db = await openDatabase();
    final rows = await db.rawQuery('''
      SELECT r.* FROM customer_receipts r
      LEFT JOIN receipt_reversals v ON v.receipt_id = r.id
      WHERE v.id IS NULL
      ORDER BY r.paid_on ASC, r.id ASC
    ''');
    return [
      for (final row in rows)
        CustomerPayment(
          id: row['id']! as String,
          customerId: row['customer_id']! as String,
          amountCents: row['amount_cents']! as int,
          paidOn: row['paid_on']! as String,
          method: PaymentMethod.values.byName(row['method']! as String),
          note: row['note'] as String?,
        ),
    ];
  }

  Future<BusinessProfile> readProfile() async {
    final db = await openDatabase();
    final rows = await db.query('business_profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return const BusinessProfile();
    final row = rows.single;
    final type = row['pix_key_type'] as String?;
    return BusinessProfile(
      pixKeyType: type == null ? null : PixKeyType.values.byName(type),
      pixKey: row['pix_key'] as String?,
      receiverName: row['pix_receiver_name'] as String?,
    );
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    final problem = pixProfileProblem(profile);
    if (problem != null) throw ReceivableException(problem);
    final db = await openDatabase();
    await db.insert('business_profile', {
      'id': 1,
      'pix_key_type': profile.pixKeyType!.name,
      'pix_key': profile.pixKey!.trim(),
      'pix_receiver_name': profile.receiverName!.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ChargePreparation> prepareCharge({
    required String id,
    required String customerId,
    required int amountCents,
    required String description,
    required String message,
    String? phone,
  }) async {
    final db = await openDatabase();
    final existing = await db.query(
      'charge_preparations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isNotEmpty) return _charge(existing.single);
    await db.insert('charge_preparations', {
      'id': id,
      'customer_id': customerId,
      'amount_cents': amountCents,
      'description': description,
      'message': message,
      'status': ChargeStatus.prepared.name,
      'phone': phone,
      'created_at': _clock().toIso8601String(),
    });
    return ChargePreparation(
      id: id,
      customerId: customerId,
      amountCents: amountCents,
      description: description,
      message: message,
      status: ChargeStatus.prepared,
      phone: phone,
    );
  }

  /// Opening WhatsApp does not mean the message was delivered or paid.
  Future<ChargePreparation> markWhatsAppOpened(String id) async {
    final db = await openDatabase();
    final rows = await db.query(
      'charge_preparations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw ReceivableException('Cobrança não encontrada.');
    }
    await db.update(
      'charge_preparations',
      {'status': ChargeStatus.whatsappOpened.name},
      where: 'id = ?',
      whereArgs: [id],
    );
    return _charge({
      ...rows.single,
      'status': ChargeStatus.whatsappOpened.name,
    });
  }

  Future<List<Receivable>> _openReceivables(
    DatabaseExecutor db,
    String customerId, {
    bool includePaid = false,
  }) async {
    final rows = await db.query(
      'receivables',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'occurred_on ASC, id ASC',
    );
    final allocated = await _allocated(db);
    final result = <Receivable>[];
    for (final row in rows) {
      final id = row['id']! as String;
      final amount = row['amount_cents']! as int;
      final open = amount - (allocated[id] ?? 0);
      if (!includePaid && open <= 0) continue;
      result.add(
        Receivable(
          id: id,
          customerId: customerId,
          description: row['description']! as String,
          amountCents: amount,
          openCents: open < 0 ? 0 : open,
          occurredOn: row['occurred_on']! as String,
          dueOn: row['due_on'] as String?,
        ),
      );
    }
    return result;
  }

  Future<Map<String, int>> _allocated(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''
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

  Future<Map<String, int>> _appliedCredit(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''
      SELECT receipt_id, COALESCE(SUM(amount_cents), 0) AS total
      FROM credit_applications
      GROUP BY receipt_id
    ''');
    return {
      for (final row in rows)
        row['receipt_id']! as String: row['total']! as int,
    };
  }

  Future<AccountReceipt> _receipt(
    DatabaseExecutor db,
    Map<String, Object?> row, {
    bool alreadyRecorded = false,
    int appliedCreditCents = 0,
  }) async {
    final id = row['id']! as String;
    final reversals = await db.query(
      'receipt_reversals',
      where: 'receipt_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return AccountReceipt(
      id: id,
      customerId: row['customer_id']! as String,
      amountCents: row['amount_cents']! as int,
      creditCents: row['credit_cents']! as int,
      paidOn: row['paid_on']! as String,
      method: PaymentMethod.values.byName(row['method']! as String),
      reversed: reversals.isNotEmpty,
      tenderedCents: row['tendered_cents'] as int?,
      changeCents: row['change_cents'] as int?,
      note: row['note'] as String?,
      appliedCreditCents: appliedCreditCents,
      alreadyRecorded: alreadyRecorded,
    );
  }

  AccountReversal _reversal(
    Map<String, Object?> row, {
    bool alreadyRecorded = false,
  }) {
    return AccountReversal(
      id: row['id']! as String,
      receiptId: row['receipt_id']! as String,
      method: PaymentMethod.values.byName(row['method']! as String),
      amountCents: row['amount_cents']! as int,
      reason: row['reason'] as String?,
      alreadyRecorded: alreadyRecorded,
    );
  }

  ChargePreparation _charge(Map<String, Object?> row) {
    return ChargePreparation(
      id: row['id']! as String,
      customerId: row['customer_id']! as String,
      amountCents: row['amount_cents']! as int,
      description: row['description']! as String,
      message: row['message']! as String,
      status: ChargeStatus.values.byName(row['status']! as String),
      phone: row['phone'] as String?,
    );
  }
}

String _day(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
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
