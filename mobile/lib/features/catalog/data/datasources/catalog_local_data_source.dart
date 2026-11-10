import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../customers/data/customer_demo_policy.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/stock_operation.dart';
import '../../domain/rules/stock_rules.dart';
import '../catalog_seed.dart';
import '../exceptions/catalog_exceptions.dart';
import '../operational_schema.dart';

/// Test hook. Production leaves this null and uses the app database file.
String? catalogDatabasePathOverride;

abstract class CatalogLocalDataSource {
  Future<CatalogSnapshot> load();

  Future<ProductStock> getProduct(String id);

  Future<ProductStock> createProduct(ProductDraft draft);

  /// Saves the packing count on this phone. Stock balances stay unchanged.
  Future<void> recordWeighing({
    required String productId,
    required int packGrams,
    required int packageCount,
    required int warehouseGrams,
  });

  Future<ProductStock> recordOpening({
    required String productId,
    required StockLocationCode location,
    required int quantity,
  });

  Future<ProductStock> setActive({required String id, required bool active});

  Future<ProductStock> setSalePrice({
    required String id,
    required int salePriceCents,
  });

  Future<void> deleteProduct(String id);

  /// Reuses the open draft of this kind. The id stays until confirmation.
  Future<StockDraft> ensureStockDraft(StockOperationKind kind);

  /// Writes both sides, or the loss, or the count difference, in one
  /// transaction. The same [id] does not move stock a second time.
  Future<StockOperationRecord> confirmStockOperation({
    required String id,
    required StockOperationKind kind,
    StockLocationCode? location,
    String? reason,
    required List<StockDraftLine> lines,
  });

  /// [desired] is the quantity that should stay on the Montana.
  /// Only the difference is transferred. The same [id] does not move again.
  Future<StockOperationRecord> adjustMontanaLoad({
    required String id,
    required List<StockDraftLine> desired,
  });

  Future<StockOperationRecord> stockOperation(String id);

  Future<List<StockMovement>> productMovements(String productId);

  Future<void> close();

  /// Connection shared with the operational ledger and drafts.
  Future<Database> database();
}

class CatalogLocalDataSourceImpl implements CatalogLocalDataSource {
  CatalogLocalDataSourceImpl({
    this.databasePath,
    bool? seedDemo,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _seedDemo = seedDemo ?? customerDemoAllowed,
       _clock = clock ?? DateTime.now,
       _newId = newId ?? _generateId;

  final String? databasePath;
  final bool _seedDemo;
  final DateTime Function() _clock;
  final String Function() _newId;
  Database? _database;

  /// Test hook. Runs inside the transfer transaction after the origin exit
  /// and before the destination entry.
  Future<void> Function()? beforeDestinationEntry;

  @override
  Future<CatalogSnapshot> load() async {
    final db = await _databaseOrOpen();
    return _snapshot(db);
  }

  @override
  Future<ProductStock> getProduct(String id) async {
    final db = await _databaseOrOpen();
    final snapshot = await _snapshot(db);
    for (final row in snapshot.products) {
      if (row.product.id == id) return row;
    }
    throw ProductNotFoundException();
  }

  @override
  Future<ProductStock> createProduct(ProductDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw CatalogRuleException(StockRuleViolation.nameRequired);
    }
    final violation = openingViolation(
      active: true,
      quantity: draft.openingQuantity,
      openingAlreadyRecorded: false,
      minimum: draft.minimumQuantity,
    );
    if (violation != null) throw CatalogRuleException(violation);
    final db = await _databaseOrOpen();
    final now = _clock();
    final id = _newId();
    final nextSort =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(MAX(sort_index), -1) FROM products',
          ),
        )! +
        1;
    await db.transaction((txn) async {
      await txn.insert('products', {
        'id': id,
        'name': name,
        'category': _blank(draft.category),
        'sku': _blank(draft.sku),
        'unit': draft.unit.name,
        'active': 1,
        'sale_price_cents': draft.salePriceCents,
        'sort_index': nextSort,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      final minimum = draft.minimumQuantity;
      if (minimum != null) {
        await txn.insert('product_minimums', {
          'product_id': id,
          'location_code': draft.openingLocation.name,
          'quantity': minimum,
        });
      }
      await _insertOpening(
        txn,
        productId: id,
        location: draft.openingLocation,
        quantity: draft.openingQuantity,
        now: now,
      );
      await enqueueSync(
        txn,
        id: 'product:$id',
        kind: 'product',
        recordedAt: now.toIso8601String(),
        payload: id,
      );
    });
    return getProduct(id);
  }

  @override
  Future<void> recordWeighing({
    required String productId,
    required int packGrams,
    required int packageCount,
    required int warehouseGrams,
  }) async {
    if (packageCount <= 0 || packGrams <= 0) {
      throw CatalogRuleException(StockRuleViolation.negativeQuantity);
    }
    final db = await _databaseOrOpen();
    final now = _clock().toIso8601String();
    final id = _newId();
    await db.transaction((txn) async {
      await txn.insert('weighing_records', {
        'id': id,
        'product_id': productId,
        'pack_grams': packGrams,
        'package_count': packageCount,
        'warehouse_grams': warehouseGrams,
        'recorded_at': now,
      });
      await enqueueSync(
        txn,
        id: 'weighing:$id',
        kind: 'weighing',
        recordedAt: now,
        payload: productId,
      );
    });
  }

  @override
  Future<ProductStock> recordOpening({
    required String productId,
    required StockLocationCode location,
    required int quantity,
  }) async {
    final current = await getProduct(productId);
    final db = await _databaseOrOpen();
    final existing = await db.query(
      'movements',
      where: 'product_id = ? AND location_code = ? AND kind = ?',
      whereArgs: [productId, location.name, MovementKind.opening.name],
    );
    final violation = openingViolation(
      active: current.product.active,
      quantity: quantity,
      openingAlreadyRecorded: existing.isNotEmpty,
    );
    if (violation != null) throw CatalogRuleException(violation);
    final now = _clock();
    await _insertOpening(
      db,
      productId: productId,
      location: location,
      quantity: quantity,
      now: now,
    );
    return getProduct(productId);
  }

  @override
  Future<ProductStock> setActive({
    required String id,
    required bool active,
  }) async {
    final db = await _databaseOrOpen();
    final updated = await db.update(
      'products',
      {'active': active ? 1 : 0, 'updated_at': _clock().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) throw ProductNotFoundException();
    return getProduct(id);
  }

  @override
  Future<ProductStock> setSalePrice({
    required String id,
    required int salePriceCents,
  }) async {
    if (salePriceCents < 0) {
      throw CatalogRuleException(StockRuleViolation.negativeQuantity);
    }
    final db = await _databaseOrOpen();
    final updated = await db.update(
      'products',
      {
        'sale_price_cents': salePriceCents,
        'updated_at': _clock().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) throw ProductNotFoundException();
    return getProduct(id);
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await _databaseOrOpen();
    await db.transaction((txn) async {
      await txn.delete(
        'stock_draft_lines',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      await txn.delete('movements', where: 'product_id = ?', whereArgs: [id]);
      await txn.delete(
        'product_minimums',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      final removed = await txn.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (removed == 0) throw ProductNotFoundException();
      await txn.insert('app_meta', {
        'key': 'deleted_product:$id',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<bool> _productWasDeleted(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'app_meta',
      columns: const ['key'],
      where: 'key = ?',
      whereArgs: ['deleted_product:$id'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<StockDraft> ensureStockDraft(StockOperationKind kind) async {
    final db = await _databaseOrOpen();
    final existing = await db.query(
      'stock_drafts',
      where: 'kind = ?',
      whereArgs: [kind.name],
      limit: 1,
    );
    if (existing.isNotEmpty) return _draftFrom(db, existing.first);
    final now = _clock().toIso8601String();
    final id = _newId();
    await db.insert('stock_drafts', {
      'id': id,
      'kind': kind.name,
      'location_code': null,
      'reason': null,
      'created_at': now,
      'updated_at': now,
    });
    return StockDraft(id: id, kind: kind, lines: const []);
  }

  @override
  Future<StockOperationRecord> confirmStockOperation({
    required String id,
    required StockOperationKind kind,
    StockLocationCode? location,
    String? reason,
    required List<StockDraftLine> lines,
  }) async {
    final db = await _databaseOrOpen();
    final existing = await db.query(
      'stock_operations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return _readOperation(db, id, alreadyRecorded: true);
    }
    await _saveDraft(
      db,
      id: id,
      kind: kind,
      location: location,
      reason: reason,
      lines: lines,
    );
    return _commitDraft(db, id);
  }

  @override
  Future<StockOperationRecord> adjustMontanaLoad({
    required String id,
    required List<StockDraftLine> desired,
  }) async {
    final db = await _databaseOrOpen();
    final returnId = '$id:return';
    final existing = await db.query(
      'stock_operations',
      where: 'id = ? OR id = ?',
      whereArgs: [id, returnId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return _readOperation(
        db,
        existing.first['id']! as String,
        alreadyRecorded: true,
      );
    }
    return db.transaction((txn) async {
      final again = await txn.query(
        'stock_operations',
        where: 'id = ? OR id = ?',
        whereArgs: [id, returnId],
        limit: 1,
      );
      if (again.isNotEmpty) {
        return _readOperation(
          txn,
          again.first['id']! as String,
          alreadyRecorded: true,
        );
      }
      final products = await _products(txn);
      final balances = await _balances(txn);
      final problems = <String>[];
      final loads = <_AppliedLine>[];
      final returns = <_AppliedLine>[];
      final seen = <String>{};
      for (final line in desired) {
        if (!seen.add(line.productId)) {
          problems.add('Produto repetido nesta carga.');
          continue;
        }
        final product = products[line.productId];
        if (product == null) {
          problems.add('Produto não encontrado.');
          continue;
        }
        if (line.quantity < 0) {
          problems.add('A quantidade não pode ser negativa.');
          continue;
        }
        final onTruck =
            balances[line.productId]?[StockLocationCode.montana] ?? 0;
        final inWarehouse =
            balances[line.productId]?[StockLocationCode.warehouse] ?? 0;
        final delta = line.quantity - onTruck;
        if (delta == 0) continue;
        if (!product.active) {
          problems.add('${product.name} está inativo.');
          continue;
        }
        if (delta > 0) {
          if (inWarehouse < delta) {
            problems.add(
              '${product.name}: em Depósito há ${formatBaseQuantity(product.unit, inWarehouse)}.',
            );
            continue;
          }
          loads.add(
            _AppliedLine(
              productId: line.productId,
              quantity: delta,
              previous: inWarehouse,
              delta: -delta,
            ),
          );
        } else {
          returns.add(
            _AppliedLine(
              productId: line.productId,
              quantity: -delta,
              previous: onTruck,
              delta: delta,
            ),
          );
        }
      }
      if (problems.isNotEmpty) {
        throw StockOperationException(problems.join('\n'));
      }
      if (loads.isEmpty && returns.isEmpty) {
        throw StockOperationException('A carga da Montana continua igual.');
      }
      final now = _clock();
      final recordedAt = now.toIso8601String();
      final occurredOn = _day(now);
      var destinationArmed = false;
      StockOperationRecord? recorded;
      if (loads.isNotEmpty) {
        recorded = await _recordTransfer(
          txn,
          id: id,
          kind: StockOperationKind.load,
          lines: loads,
          origin: StockLocationCode.warehouse,
          destination: StockLocationCode.montana,
          occurredOn: occurredOn,
          recordedAt: recordedAt,
          armDestination: () async {
            if (destinationArmed || beforeDestinationEntry == null) return;
            destinationArmed = true;
            await beforeDestinationEntry!();
          },
        );
      }
      if (returns.isNotEmpty) {
        recorded = await _recordTransfer(
          txn,
          id: loads.isEmpty ? id : returnId,
          kind: StockOperationKind.returnToWarehouse,
          lines: returns,
          origin: StockLocationCode.montana,
          destination: StockLocationCode.warehouse,
          occurredOn: occurredOn,
          recordedAt: recordedAt,
          armDestination: () async {
            if (destinationArmed || beforeDestinationEntry == null) return;
            destinationArmed = true;
            await beforeDestinationEntry!();
          },
        );
      }
      await txn.delete(
        'stock_draft_lines',
        where: 'draft_id = ?',
        whereArgs: [id],
      );
      await txn.delete('stock_drafts', where: 'id = ?', whereArgs: [id]);
      return recorded!;
    }, exclusive: true);
  }

  Future<StockOperationRecord> _recordTransfer(
    DatabaseExecutor txn, {
    required String id,
    required StockOperationKind kind,
    required List<_AppliedLine> lines,
    required StockLocationCode origin,
    required StockLocationCode destination,
    required String occurredOn,
    required String recordedAt,
    required Future<void> Function() armDestination,
  }) async {
    final reason = _operationReason(kind, null);
    await txn.insert('stock_operations', {
      'id': id,
      'kind': kind.name,
      'occurred_on': occurredOn,
      'recorded_at': recordedAt,
      'origin_code': origin.name,
      'destination_code': destination.name,
      'location_code': null,
      'reason': reason,
    });
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      await _insertMovement(
        txn,
        id: _newId(),
        operationId: id,
        productId: line.productId,
        location: origin,
        quantity: -line.quantity,
        kind: MovementKind.transferOut,
        reason: reason,
        occurredOn: occurredOn,
        recordedAt: recordedAt,
        idempotencyKey: 'transfer:$id:${line.productId}:out',
      );
      await armDestination();
      await _insertMovement(
        txn,
        id: _newId(),
        operationId: id,
        productId: line.productId,
        location: destination,
        quantity: line.quantity,
        kind: MovementKind.transferIn,
        reason: reason,
        occurredOn: occurredOn,
        recordedAt: recordedAt,
        idempotencyKey: 'transfer:$id:${line.productId}:in',
      );
      await txn.insert('stock_operation_lines', {
        'id': '$id:line:$index',
        'operation_id': id,
        'product_id': line.productId,
        'quantity': line.quantity,
        'previous_quantity': line.previous,
        'delta': line.delta,
        'position': index,
      });
    }
    await enqueueSync(
      txn,
      id: 'stock:$id',
      kind: 'stock',
      recordedAt: recordedAt,
      payload: id,
    );
    return _readOperation(txn, id);
  }

  @override
  Future<StockOperationRecord> stockOperation(String id) async {
    final db = await _databaseOrOpen();
    final rows = await db.query(
      'stock_operations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StockOperationException('Movimentação não encontrada.');
    }
    return _readOperation(db, id);
  }

  @override
  Future<List<StockMovement>> productMovements(String productId) async {
    final db = await _databaseOrOpen();
    final rows = await db.query(
      'movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'recorded_at ASC, id ASC',
    );
    return [for (final row in rows) _movementFromMap(row)];
  }

  Future<void> _saveDraft(
    Database db, {
    required String id,
    required StockOperationKind kind,
    StockLocationCode? location,
    String? reason,
    required List<StockDraftLine> lines,
  }) async {
    final now = _clock().toIso8601String();
    await db.transaction((txn) async {
      final confirmed = await txn.query(
        'stock_operations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (confirmed.isNotEmpty) return;
      final updated = await txn.update(
        'stock_drafts',
        {
          'kind': kind.name,
          'location_code': location?.name,
          'reason': _blank(reason),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) {
        await txn.insert('stock_drafts', {
          'id': id,
          'kind': kind.name,
          'location_code': location?.name,
          'reason': _blank(reason),
          'created_at': now,
          'updated_at': now,
        });
      }
      await txn.delete(
        'stock_draft_lines',
        where: 'draft_id = ?',
        whereArgs: [id],
      );
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        await txn.insert('stock_draft_lines', {
          'id': '$id:$index',
          'draft_id': id,
          'product_id': line.productId,
          'quantity': line.quantity,
          'position': index,
        });
      }
    });
  }

  Future<StockOperationRecord> _commitDraft(Database db, String id) {
    return db.transaction((txn) async {
      final confirmed = await txn.query(
        'stock_operations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (confirmed.isNotEmpty) {
        return _readOperation(txn, id, alreadyRecorded: true);
      }
      final drafts = await txn.query(
        'stock_drafts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (drafts.isEmpty) {
        throw StockOperationException(
          'Esta movimentação não está mais em rascunho.',
        );
      }
      final draft = drafts.single;
      final kind = StockOperationKind.values.byName(draft['kind']! as String);
      final location = draft['location_code'] == null
          ? null
          : StockLocationCode.values.byName(draft['location_code']! as String);
      final reason = draft['reason'] as String?;
      final headerProblem = stockOperationProblem(
        kind: kind,
        location: location,
        reason: reason,
      );
      final lineRows = await txn.query(
        'stock_draft_lines',
        where: 'draft_id = ?',
        whereArgs: [id],
        orderBy: 'position ASC',
      );
      if (lineRows.isEmpty) {
        throw StockOperationException('Inclua ao menos um produto.');
      }
      final products = await _products(txn);
      final balances = await _balances(txn);
      final problems = <String>[?headerProblem];
      final seen = <String>{};
      final applied = <_AppliedLine>[];
      final ends =
          kind == StockOperationKind.load ||
              kind == StockOperationKind.returnToWarehouse
          ? transferEnds(kind)
          : null;
      for (final row in lineRows) {
        final productId = row['product_id']! as String;
        final quantity = row['quantity']! as int;
        final product = products[productId];
        if (product == null) {
          problems.add('Produto não encontrado.');
          continue;
        }
        final place = ends?.$1 ?? location;
        final available = place == null
            ? 0
            : (balances[productId]?[place] ?? 0);
        final problem = stockLineProblem(
          kind: kind,
          productName: product.name,
          active: product.active,
          unit: product.unit,
          quantity: quantity,
          available: available,
          duplicate: !seen.add(productId),
          place: place == null ? '' : locationName(place),
        );
        if (problem != null) {
          problems.add(problem);
          continue;
        }
        final previous = available;
        final delta = kind == StockOperationKind.count
            ? quantity - previous
            : -quantity;
        if (place != null && kind != StockOperationKind.count) {
          final next = Map<StockLocationCode, int>.from(
            balances[productId] ??
                {for (final code in StockLocationCode.values) code: 0},
          );
          next[place] = previous + delta;
          balances[productId] = next;
        }
        if (kind == StockOperationKind.count && place != null) {
          final next = Map<StockLocationCode, int>.from(
            balances[productId] ??
                {for (final code in StockLocationCode.values) code: 0},
          );
          next[place] = quantity;
          balances[productId] = next;
        }
        applied.add(
          _AppliedLine(
            productId: productId,
            quantity: quantity,
            previous: previous,
            delta: delta,
          ),
        );
      }
      if (problems.isNotEmpty) {
        throw StockOperationException(problems.join('\n'));
      }
      final now = _clock();
      final recordedAt = now.toIso8601String();
      final occurredOn = _day(now);
      final storedReason = _operationReason(kind, reason);
      await txn.insert('stock_operations', {
        'id': id,
        'kind': kind.name,
        'occurred_on': occurredOn,
        'recorded_at': recordedAt,
        'origin_code': ends?.$1.name,
        'destination_code': ends?.$2.name,
        'location_code': location?.name,
        'reason': storedReason,
      });
      var destinationArmed = false;
      for (var index = 0; index < applied.length; index++) {
        final line = applied[index];
        if (ends != null) {
          await _insertMovement(
            txn,
            id: _newId(),
            operationId: id,
            productId: line.productId,
            location: ends.$1,
            quantity: -line.quantity,
            kind: MovementKind.transferOut,
            reason: storedReason,
            occurredOn: occurredOn,
            recordedAt: recordedAt,
            idempotencyKey: 'transfer:$id:${line.productId}:out',
          );
          if (!destinationArmed && beforeDestinationEntry != null) {
            destinationArmed = true;
            await beforeDestinationEntry!();
          }
          await _insertMovement(
            txn,
            id: _newId(),
            operationId: id,
            productId: line.productId,
            location: ends.$2,
            quantity: line.quantity,
            kind: MovementKind.transferIn,
            reason: storedReason,
            occurredOn: occurredOn,
            recordedAt: recordedAt,
            idempotencyKey: 'transfer:$id:${line.productId}:in',
          );
        } else if (kind == StockOperationKind.loss && location != null) {
          await _insertMovement(
            txn,
            id: _newId(),
            operationId: id,
            productId: line.productId,
            location: location,
            quantity: -line.quantity,
            kind: MovementKind.loss,
            reason: storedReason,
            occurredOn: occurredOn,
            recordedAt: recordedAt,
            idempotencyKey: 'loss:$id:${line.productId}',
          );
        } else if (location != null) {
          await _insertMovement(
            txn,
            id: _newId(),
            operationId: id,
            productId: line.productId,
            location: location,
            quantity: line.delta,
            kind: MovementKind.adjustment,
            reason: storedReason,
            occurredOn: occurredOn,
            recordedAt: recordedAt,
            idempotencyKey: 'count:$id:${line.productId}',
          );
        }
        await txn.insert('stock_operation_lines', {
          'id': '$id:line:$index',
          'operation_id': id,
          'product_id': line.productId,
          'quantity': line.quantity,
          'previous_quantity': line.previous,
          'delta': line.delta,
          'position': index,
        });
      }
      await txn.delete(
        'stock_draft_lines',
        where: 'draft_id = ?',
        whereArgs: [id],
      );
      await txn.delete('stock_drafts', where: 'id = ?', whereArgs: [id]);
      await enqueueSync(
        txn,
        id: 'stock:$id',
        kind: 'stock',
        recordedAt: recordedAt,
        payload: id,
      );
      return _readOperation(txn, id);
    }, exclusive: true);
  }

  Future<void> _insertMovement(
    DatabaseExecutor txn, {
    required String id,
    required String operationId,
    required String productId,
    required StockLocationCode location,
    required int quantity,
    required MovementKind kind,
    required String reason,
    required String occurredOn,
    required String recordedAt,
    required String idempotencyKey,
  }) {
    return txn.insert('movements', {
      'id': id,
      'product_id': productId,
      'location_code': location.name,
      'quantity': quantity,
      'kind': kind.name,
      'reason': reason,
      'occurred_on': occurredOn,
      'recorded_at': recordedAt,
      'idempotency_key': idempotencyKey,
      'operation_id': operationId,
    });
  }

  Future<Map<String, _CatalogProductRow>> _products(DatabaseExecutor db) async {
    final rows = await db.query('products');
    return {
      for (final row in rows)
        row['id']! as String: _CatalogProductRow(
          name: row['name']! as String,
          unit: CatalogUnit.values.byName(row['unit']! as String),
          active: (row['active']! as int) == 1,
        ),
    };
  }

  Future<Map<String, Map<StockLocationCode, int>>> _balances(
    DatabaseExecutor db,
  ) async {
    final rows = await db.query('movements');
    final balances = <String, Map<StockLocationCode, int>>{};
    for (final row in rows) {
      final productId = row['product_id']! as String;
      final location = StockLocationCode.values.byName(
        row['location_code']! as String,
      );
      final totals = balances.putIfAbsent(productId, () {
        return {for (final code in StockLocationCode.values) code: 0};
      });
      totals[location] = totals[location]! + (row['quantity']! as int);
    }
    return balances;
  }

  Future<StockDraft> _draftFrom(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final id = row['id']! as String;
    final lines = await db.query(
      'stock_draft_lines',
      where: 'draft_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    return StockDraft(
      id: id,
      kind: StockOperationKind.values.byName(row['kind']! as String),
      location: row['location_code'] == null
          ? null
          : StockLocationCode.values.byName(row['location_code']! as String),
      reason: row['reason'] as String?,
      lines: [
        for (final line in lines)
          StockDraftLine(
            productId: line['product_id']! as String,
            quantity: line['quantity']! as int,
          ),
      ],
    );
  }

  Future<StockOperationRecord> _readOperation(
    DatabaseExecutor db,
    String id, {
    bool alreadyRecorded = false,
  }) async {
    final rows = await db.query(
      'stock_operations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final row = rows.single;
    final products = await _products(db);
    final lines = await db.query(
      'stock_operation_lines',
      where: 'operation_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    return StockOperationRecord(
      id: id,
      kind: StockOperationKind.values.byName(row['kind']! as String),
      occurredOn: DateTime.parse(row['occurred_on']! as String),
      recordedAt: DateTime.parse(row['recorded_at']! as String),
      origin: row['origin_code'] == null
          ? null
          : StockLocationCode.values.byName(row['origin_code']! as String),
      destination: row['destination_code'] == null
          ? null
          : StockLocationCode.values.byName(row['destination_code']! as String),
      location: row['location_code'] == null
          ? null
          : StockLocationCode.values.byName(row['location_code']! as String),
      reason: row['reason'] as String?,
      alreadyRecorded: alreadyRecorded,
      lines: [
        for (final line in lines)
          StockOperationLine(
            productId: line['product_id']! as String,
            productName: products[line['product_id']]?.name ?? 'Produto',
            unit: products[line['product_id']]?.unit ?? CatalogUnit.kilogram,
            quantity: line['quantity']! as int,
            previousQuantity: line['previous_quantity'] as int?,
            delta: line['delta'] as int?,
          ),
      ],
    );
  }

  String _operationReason(StockOperationKind kind, String? reason) {
    return switch (kind) {
      StockOperationKind.load => 'Carga da Montana',
      StockOperationKind.returnToWarehouse => 'Retorno ao depósito',
      StockOperationKind.loss || StockOperationKind.count => reason!.trim(),
    };
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  @override
  Future<Database> database() => _databaseOrOpen();

  Future<void> _insertOpening(
    DatabaseExecutor txn, {
    required String productId,
    required StockLocationCode location,
    required int quantity,
    required DateTime now,
  }) {
    final day = _day(now);
    return txn.insert('movements', {
      'id': _newId(),
      'product_id': productId,
      'location_code': location.name,
      'quantity': quantity,
      'kind': MovementKind.opening.name,
      'reason': 'Saldo inicial',
      'occurred_on': day,
      'recorded_at': now.toIso8601String(),
      'idempotency_key': 'opening:$productId:${location.name}',
    });
  }

  Future<CatalogSnapshot> _snapshot(Database db) async {
    final productRows = await db.query(
      'products',
      orderBy: 'sort_index ASC, name COLLATE NOCASE ASC',
    );
    final minimumRows = await db.query('product_minimums');
    final movementRows = await db.query('movements');
    final minimums = <String, Map<StockLocationCode, int>>{};
    for (final row in minimumRows) {
      final productId = row['product_id']! as String;
      final location = StockLocationCode.values.byName(
        row['location_code']! as String,
      );
      minimums.putIfAbsent(productId, () => {})[location] =
          row['quantity']! as int;
    }
    final movements = <String, List<StockMovement>>{};
    final today = _day(_clock());
    var movementsToday = 0;
    DateTime? latest;
    for (final row in movementRows) {
      final movement = _movementFromMap(row);
      movements.putIfAbsent(movement.productId, () => []).add(movement);
      if (row['occurred_on'] == today) movementsToday += 1;
      if (latest == null || movement.recordedAt.isAfter(latest)) {
        latest = movement.recordedAt;
      }
    }
    final products = [
      for (final row in productRows)
        _stockFromRow(
          row,
          minimums[row['id'] as String] ?? const {},
          movements[row['id'] as String] ?? const [],
        ),
    ];
    return CatalogSnapshot(
      products: products,
      movementsToday: movementsToday,
      updatedAt: latest,
    );
  }

  ProductStock _stockFromRow(
    Map<String, Object?> row,
    Map<StockLocationCode, int> minimums,
    List<StockMovement> movements,
  ) {
    final product = CatalogProduct(
      id: row['id']! as String,
      name: row['name']! as String,
      category: row['category'] as String?,
      sku: row['sku'] as String?,
      unit: CatalogUnit.values.byName(row['unit']! as String),
      active: (row['active']! as int) == 1,
      salePriceCents: row['sale_price_cents']! as int,
      minimums: minimums,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
    final balances = balancesFor(movements);
    return ProductStock(
      product: product,
      balances: balances,
      low: isLowStock(product, balances),
    );
  }

  StockMovement _movementFromMap(Map<String, Object?> row) {
    return StockMovement(
      id: row['id']! as String,
      productId: row['product_id']! as String,
      location: StockLocationCode.values.byName(
        row['location_code']! as String,
      ),
      quantity: row['quantity']! as int,
      kind: MovementKind.values.byName(row['kind']! as String),
      occurredOn: DateTime.parse(row['occurred_on']! as String),
      recordedAt: DateTime.parse(row['recorded_at']! as String),
      reason: row['reason'] as String?,
      operationId: row['operation_id'] as String?,
    );
  }

  Future<Database> _databaseOrOpen() async {
    final current = _database;
    if (current != null) return current;
    final path =
        databasePath ??
        catalogDatabasePathOverride ??
        '${await getDatabasesPath()}/pouapp_catalog.db';
    final database = await openDatabase(
      path,
      version: catalogDatabaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
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
        await db.execute('''
          CREATE TABLE product_minimums (
            product_id TEXT NOT NULL REFERENCES products(id),
            location_code TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            PRIMARY KEY (product_id, location_code)
          )
        ''');
        await db.execute('''
          CREATE TABLE movements (
            id TEXT PRIMARY KEY,
            product_id TEXT NOT NULL REFERENCES products(id),
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
        await db.execute('''
          CREATE TABLE app_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await createOperationalTables(db);
        await createStockOperationTables(db);
        await createReceivableTables(db);
        await createDeliveryTables(db);
        await upgradeSyncQueue(db);
        await upgradeVoiceTables(db);
        await upgradeVoiceExecutions(db);
        await upgradeReferencePrices(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await createOperationalTables(db);
        if (oldVersion < 3) await upgradeStockOperations(db);
        if (oldVersion < 4) await createReceivableTables(db);
        if (oldVersion < 5) await createDeliveryTables(db);
        if (oldVersion < 6) await upgradeSyncQueue(db);
        if (oldVersion < 7) await upgradeVoiceTables(db);
        if (oldVersion < 8) await upgradeVoiceExecutions(db);
        if (oldVersion < 9) await upgradeReferencePrices(db);
      },
    );
    await _ensureLocationsAndSeed(database);
    _database = database;
    return database;
  }

  Future<void> _ensureLocationsAndSeed(Database db) async {
    if (!_seedDemo) return;
    final seeded = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: const ['catalog_seeded'],
    );
    final now = _clock();
    if (seeded.isEmpty) {
      await db.transaction((txn) async {
        for (final demo in demoCatalogProducts) {
          await _insertDemo(txn, demo, now);
        }
        await txn.insert('app_meta', {'key': 'catalog_seeded', 'value': '1'});
      });
    }
    await _packDemoGarlic(db);
    await _ensureStaples(db, now);
    await _ensurePackedProducts(db, now);
    await _sellDemoBananaByDozen(db);
    await _syncDemoSalePrices(db, now);
  }

  /// Keeps demo catalog prices aligned with [demoCatalogProducts].
  Future<void> _syncDemoSalePrices(Database db, DateTime now) async {
    await db.transaction((txn) async {
      for (final demo in demoCatalogProducts) {
        if (demo.salePriceCents <= 0) continue;
        await txn.update(
          'products',
          {
            'sale_price_cents': demo.salePriceCents,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ? AND sale_price_cents = 0',
          whereArgs: [demo.id],
        );
      }
    });
  }

  /// The first demo garlic was 500 kg loose. The house basket sells a
  /// 500 g pack and a 1 kg pack. Only the untouched opening balance is
  /// rewritten into the 1 kg pack.
  Future<void> _packDemoGarlic(Database db) async {
    final products = await db.query(
      'products',
      where: 'id = ? AND name = ? AND unit = ?',
      whereArgs: const ['product-alho', 'Alho', 'kilogram'],
    );
    if (products.isEmpty) return;
    final movements = await db.query(
      'movements',
      where: 'product_id = ?',
      whereArgs: const ['product-alho'],
    );
    if (movements.length != 1 || movements.single['quantity'] != 500000) {
      return;
    }
    final garlic = demoCatalogProducts.firstWhere(
      (product) => product.id == 'product-alho',
    );
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {
          'name': garlic.name,
          'unit': garlic.unit.name,
          'sale_price_cents': garlic.salePriceCents,
          'sort_index': garlic.sortIndex,
          'updated_at': _clock().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: const ['product-alho'],
      );
      await txn.update(
        'movements',
        {'quantity': garlic.quantity},
        where: 'id = ?',
        whereArgs: [movements.single['id']],
      );
      await txn.update(
        'product_minimums',
        {'quantity': garlic.minimum},
        where: 'product_id = ?',
        whereArgs: const ['product-alho'],
      );
    });
  }

  Future<void> _ensurePackedProducts(Database db, DateTime now) async {
    final present = await db.query(
      'products',
      columns: const ['id'],
      where:
          'id IN (${List.filled(packedCatalogProducts.length, '?').join(',')})',
      whereArgs: [for (final product in packedCatalogProducts) product.id],
    );
    final known = {for (final row in present) row['id'] as String};
    final missing = [
      for (final product in packedCatalogProducts)
        if (!known.contains(product.id) &&
            !await _productWasDeleted(db, product.id))
          product,
    ];
    if (missing.isEmpty) return;
    await db.transaction((txn) async {
      for (final product in missing) {
        await _insertDemo(txn, product, now);
      }
    });
  }

  Future<void> _ensureStaples(Database db, DateTime now) async {
    final present = await db.query(
      'products',
      columns: const ['id'],
      where:
          'id IN (${List.filled(stapleCatalogProducts.length, '?').join(',')})',
      whereArgs: [for (final staple in stapleCatalogProducts) staple.id],
    );
    final known = {for (final row in present) row['id'] as String};
    final missing = [
      for (final staple in stapleCatalogProducts)
        if (!known.contains(staple.id) &&
            !await _productWasDeleted(db, staple.id))
          staple,
    ];
    if (missing.isEmpty) return;
    final minSort = Sqflite.firstIntValue(
      await db.rawQuery('SELECT MIN(sort_index) FROM products'),
    );
    var sort = (minSort ?? 0) - missing.length;
    await db.transaction((txn) async {
      for (final staple in missing) {
        await _insertDemo(txn, staple, now, sortIndex: sort);
        sort += 1;
      }
    });
  }

  /// The demo banana was stored in kilograms. It is sold by the dozen.
  /// Only the untouched opening balance is rewritten.
  Future<void> _sellDemoBananaByDozen(Database db) async {
    final products = await db.query(
      'products',
      where: 'id = ? AND unit = ?',
      whereArgs: const ['product-banana', 'kilogram'],
    );
    if (products.isEmpty) return;
    final movements = await db.query(
      'movements',
      where: 'product_id = ?',
      whereArgs: const ['product-banana'],
    );
    if (movements.length != 1 || movements.single['quantity'] != 86000) {
      return;
    }
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'unit': CatalogUnit.dozen.name},
        where: 'id = ?',
        whereArgs: const ['product-banana'],
      );
      await txn.update(
        'movements',
        {'quantity': 40},
        where: 'id = ?',
        whereArgs: [movements.single['id']],
      );
      await txn.update(
        'product_minimums',
        {'quantity': 10},
        where: 'product_id = ?',
        whereArgs: const ['product-banana'],
      );
    });
  }

  Future<void> _insertDemo(
    DatabaseExecutor txn,
    DemoCatalogProduct demo,
    DateTime now, {
    int? sortIndex,
  }) async {
    await txn.insert('products', {
      'id': demo.id,
      'name': demo.name,
      'category': 'Hortifruti',
      'sku': null,
      'unit': demo.unit.name,
      'active': 1,
      'sale_price_cents': demo.salePriceCents,
      'sort_index': sortIndex ?? demo.sortIndex,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    await txn.insert('product_minimums', {
      'product_id': demo.id,
      'location_code': StockLocationCode.warehouse.name,
      'quantity': demo.minimum,
    });
    await txn.insert('movements', {
      'id': 'opening-${demo.id}',
      'product_id': demo.id,
      'location_code': StockLocationCode.warehouse.name,
      'quantity': demo.quantity,
      'kind': MovementKind.opening.name,
      'reason': 'Saldo inicial',
      'occurred_on': _day(now),
      'recorded_at': now.toIso8601String(),
      'idempotency_key':
          'opening:${demo.id}:${StockLocationCode.warehouse.name}',
    });
  }
}

class _CatalogProductRow {
  const _CatalogProductRow({
    required this.name,
    required this.unit,
    required this.active,
  });

  final String name;
  final CatalogUnit unit;
  final bool active;
}

class _AppliedLine {
  const _AppliedLine({
    required this.productId,
    required this.quantity,
    required this.previous,
    required this.delta,
  });

  final String productId;
  final int quantity;
  final int previous;
  final int delta;
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
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
