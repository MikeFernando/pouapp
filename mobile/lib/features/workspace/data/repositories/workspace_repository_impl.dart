import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../domain/entities/company_operation.dart';
import '../../domain/entities/posted_sale.dart';
import '../../domain/entities/stock_board.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/failures/street_failure.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../../domain/rules/month_board.dart';
import '../delivery_store.dart';
import '../operation_store.dart';
import '../receivable_store.dart';
import '../datasources/street_seed.dart';
import '../datasources/workspace_local_data_source.dart';
import '../datasources/workspace_simulated_data_source.dart';
import '../models/street_ledger_codec.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  WorkspaceRepositoryImpl({
    required this.localDataSource,
    required this.simulatedDataSource,
    this.catalogRepository,
    this.operationStore,
    this.receivableStore,
    this.deliveryStore,
    this.customers,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WorkspaceLocalDataSource localDataSource;
  final WorkspaceSimulatedDataSource simulatedDataSource;
  final CatalogRepository? catalogRepository;
  final OperationStore? operationStore;
  final ReceivableStore? receivableStore;
  final DeliveryStore? deliveryStore;
  final CustomerRepository? customers;
  final DateTime Function() _clock;

  @override
  Future<Either<Failure, CompanyOperation>> getOperation() async {
    try {
      final operation = simulatedDataSource.operation(ledger: await _ledger());
      return Right(await _withAccounts(await _withCatalog(operation)));
    } on CacheException {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, CompanyOperation>> applyStreetChange(
    StreetChange change,
  ) async {
    try {
      final update = updateStreetLedger(await _ledger(), _dated(change));
      final ledger = update.ledger;
      if (update.error != null || ledger == null) {
        return Left(
          StreetChangeFailure(
            update.error ?? 'Não foi possível atualizar a visita.',
          ),
        );
      }
      final store = operationStore;
      if (store != null && await store.isActive()) {
        await store.writeLedger(ledger);
      } else {
        await localDataSource.saveStreetLedger(encodeStreetLedger(ledger));
      }
      return Right(
        await _withAccounts(
          await _withCatalog(simulatedDataSource.operation(ledger: ledger)),
        ),
      );
    } on CacheException {
      return const Left(CacheFailure());
    } on OperationImportException {
      return const Left(CacheFailure());
    }
  }

  Future<CompanyOperation> _withAccounts(CompanyOperation operation) async {
    final store = receivableStore;
    if (store == null) {
      return operation.copyWith(
        postedSales: confirmedStreetSales(operation.street),
      );
    }
    final open = await store.companyOpenCents();
    final received = await store.netReceivedCents();
    final payments = await store.paymentsForIndicators();
    final sold = await deliveryStore?.soldCents() ?? 0;
    return operation.copyWith(
      summary: operation.summary.copyWith(
        soldCents: operation.summary.soldCents + sold,
        receivedCents: operation.summary.receivedCents + received,
        receivableCents: open,
      ),
      accountPayments: payments,
      postedSales: await _postedSales(operation.street),
    );
  }

  Future<List<PostedSale>> _postedSales(StreetLedger ledger) async {
    final sales = confirmedStreetSales(ledger);
    final store = receivableStore;
    if (store == null) return sales;
    final names = <String, String>{};
    for (final sale in sales) {
      if (sale.customerName.trim().isNotEmpty) {
        names[sale.customerId] = sale.customerName;
      }
    }
    for (final visit in ledger.visits) {
      final name = visit.customerName.trim();
      if (name.isNotEmpty) names.putIfAbsent(visit.customerId, () => name);
    }
    final rows = await store.postedSales();
    final repo = customers;
    if (repo != null) {
      for (final row in rows) {
        if (names.containsKey(row.customerId)) continue;
        final found = await repo.getCustomerById(row.customerId);
        found.fold((_) {}, (customer) => names[row.customerId] = customer.name);
      }
    }
    return [
      ...sales,
      for (final row in rows)
        PostedSale(
          id: row.id,
          customerId: row.customerId,
          customerName: names[row.customerId] ?? 'Cliente',
          totalCents: row.totalCents,
          allocatedCents: row.allocatedCents,
          occurredOn: row.occurredOn,
          dueOn: row.dueOn,
          sale: row.sale,
        ),
    ];
  }

  Future<CompanyOperation> _withCatalog(CompanyOperation operation) async {
    final catalog = catalogRepository;
    if (catalog == null) return operation;
    final snapshot = await catalog.load();
    return snapshot.fold(
      (_) => operation,
      (data) => _overlayCatalog(operation, data),
    );
  }

  StreetLedger _legacyLedger() {
    final saved = localDataSource.readStreetLedger();
    if (saved == null || saved.isEmpty) return seedStreetLedger();
    try {
      return withPersonNames(decodeStreetLedger(saved));
    } catch (_) {
      return seedStreetLedger();
    }
  }

  Future<StreetLedger> _ledger() async {
    final store = operationStore;
    if (store == null) return _legacyLedger();
    try {
      await store.ensureActive();
    } on OperationImportException {
      return _legacyLedger();
    }
    if (!await store.isActive()) return _legacyLedger();
    return withPersonNames(await store.readLedger());
  }

  StreetChange _dated(StreetChange change) {
    if (change is! SaveSale ||
        change.orderId != null ||
        change.occurredOn != null) {
      return change;
    }
    final now = _clock();
    return SaveSale(
      visitId: change.visitId,
      customerId: change.customerId,
      customerName: change.customerName,
      lines: change.lines,
      note: change.note,
      occurredOn: isoDate(now),
      recordedAt: now.toIso8601String(),
    );
  }
}

CompanyOperation _overlayCatalog(
  CompanyOperation operation,
  CatalogSnapshot snapshot,
) {
  final products = [
    for (final row in snapshot.products)
      if (row.product.active)
        StockProduct(
          id: row.product.id,
          name: row.product.name,
          unit: _stockUnit(row.product.unit),
          available: _displayQuantity(row.product.unit, row.total),
          montana: _displayQuantity(
            row.product.unit,
            row.balances[StockLocationCode.montana] ?? 0,
          ),
          low: row.low,
        ),
  ];
  return operation.copyWith(
    products: products,
    stock: StockSummary(
      pendingReceipts: operation.stock.pendingReceipts,
      lowStockProducts: products.where((product) => product.low).length,
      movementsToday: snapshot.movementsToday,
    ),
  );
}

double _displayQuantity(CatalogUnit unit, int quantity) {
  if (unit == CatalogUnit.kilogram) return quantity / 1000;
  return quantity.toDouble();
}

StockUnit _stockUnit(CatalogUnit unit) {
  return switch (unit) {
    CatalogUnit.kilogram => StockUnit.kilogram,
    CatalogUnit.piece => StockUnit.piece,
    CatalogUnit.bunch => StockUnit.bunch,
    CatalogUnit.box => StockUnit.box,
    CatalogUnit.dozen => StockUnit.dozen,
  };
}
