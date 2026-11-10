import '../../domain/entities/company_operation.dart';
import '../../domain/entities/sales_board.dart';
import '../../domain/entities/stock_board.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/company_indicators.dart';
import 'street_seed.dart';

/// One fixed hortifruti company. Widgets never see this source.
class WorkspaceSimulatedDataSource {
  CompanyOperation operation({StreetLedger? ledger}) {
    final street = ledger ?? seedStreetLedger();
    final base = CompanyOperation(
      summary: const SalesSummary(
        soldCents: 0,
        receivedCents: 0,
        pendingDeliveries: 0,
      ),
      deliveries: const [],
      sales: const [],
      team: const [],
      stock: const StockSummary(
        pendingReceipts: 0,
        lowStockProducts: 0,
        movementsToday: 0,
      ),
      receipts: const [],
      products: const [
        StockProduct(
          id: 'product-alho-500',
          name: 'Alho 500 g',
          unit: StockUnit.piece,
          available: 60,
          low: false,
          salePriceCents: 1600,
        ),
        StockProduct(
          id: 'product-alho',
          name: 'Alho 1 kg',
          unit: StockUnit.piece,
          available: 40,
          low: false,
          salePriceCents: 3000,
        ),
        StockProduct(
          id: 'product-cebola',
          name: 'Cebola',
          unit: StockUnit.kilogram,
          available: 600,
          low: false,
          salePriceCents: 450,
        ),
        StockProduct(
          id: 'product-batata',
          name: 'Batata',
          unit: StockUnit.kilogram,
          available: 800,
          low: false,
          salePriceCents: 450,
        ),
        StockProduct(
          id: 'product-banana',
          name: 'Banana nanica',
          unit: StockUnit.dozen,
          available: 40,
          low: false,
          salePriceCents: 590,
        ),
        StockProduct(
          id: 'product-tomate',
          name: 'Tomate italiano',
          unit: StockUnit.box,
          available: 14,
          low: false,
          salePriceCents: 5900,
        ),
        StockProduct(
          id: 'product-alface',
          name: 'Alface crespa',
          unit: StockUnit.piece,
          available: 40,
          low: false,
          salePriceCents: 350,
        ),
        StockProduct(
          id: 'product-laranja',
          name: 'Laranja pera',
          unit: StockUnit.kilogram,
          available: 22,
          low: true,
          salePriceCents: 490,
        ),
        StockProduct(
          id: 'product-mamao',
          name: 'Mamão formosa',
          unit: StockUnit.kilogram,
          available: 8,
          low: true,
          salePriceCents: 690,
        ),
        StockProduct(
          id: 'product-limao',
          name: 'Limão tahiti',
          unit: StockUnit.kilogram,
          available: 6,
          low: true,
          salePriceCents: 690,
        ),
        StockProduct(
          id: 'product-melancia',
          name: 'Melancia',
          unit: StockUnit.piece,
          available: 18,
          low: false,
          salePriceCents: 1290,
        ),
        StockProduct(
          id: 'product-ovos-duzia',
          name: 'Ovos dúzia',
          unit: StockUnit.dozen,
          available: 40,
          low: false,
          salePriceCents: 1200,
        ),
        StockProduct(
          id: 'product-ovos',
          name: 'Ovos bandeja 30',
          unit: StockUnit.piece,
          available: 30,
          low: false,
          salePriceCents: 1890,
        ),
      ],
      street: street,
    );
    return _withStreetActivity(base);
  }
}

/// Company totals come only from street records the operator saved.
/// Demonstration orders and payments stay on the route and do not enter
/// these figures. A payment does not create a sale. Debt and supplier
/// bills are not derived from this ledger.
CompanyOperation _withStreetActivity(CompanyOperation base) {
  final ledger = base.street;
  final indicators = CompanyIndicators.fromLedger(ledger);
  final realOrders = [
    for (final order in ledger.orders)
      if (order.recorded && !order.fromSeed) order,
  ];
  final pending = ledger.visits
      .where(
        (visit) =>
            visit.status == VisitStatus.pending ||
            visit.status == VisitStatus.inService,
      )
      .length;
  return base.copyWith(
    summary: SalesSummary(
      soldCents: indicators.soldCents,
      receivedCents: indicators.receivedCents,
      pendingDeliveries: pending,
    ),
    sales: [
      for (final order in realOrders.reversed)
        RecentSale(
          id: order.id,
          code: order.code,
          customerName: order.customerName,
          amountCents: order.totalCents,
          paymentStatus: allocatedToOrder(ledger, order.id) >= order.totalCents
              ? PaymentStatus.received
              : PaymentStatus.pending,
          occurredOn: order.occurredOn,
        ),
    ],
  );
}
