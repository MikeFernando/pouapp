import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/posted_sale.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:pouapp/features/workspace/domain/rules/month_board.dart';

void main() {
  final today = DateTime(2026, 11, 3);

  PostedSale sale({
    required String id,
    required String customerId,
    required String name,
    required int total,
    required int allocated,
    required String occurredOn,
    String? dueOn,
    bool isSale = true,
  }) {
    return PostedSale(
      id: id,
      customerId: customerId,
      customerName: name,
      totalCents: total,
      allocatedCents: allocated,
      occurredOn: occurredOn,
      dueOn: dueOn,
      sale: isSale,
    );
  }

  test('partial payment stays inside the sale month', () {
    final november = monthSnapshot(
      sales: [
        sale(
          id: 'nov',
          customerId: 'ana',
          name: 'Ana',
          total: 10000,
          allocated: 4000,
          occurredOn: '2026-11-02',
          dueOn: '2026-11-03',
        ),
        sale(
          id: 'future',
          customerId: 'ana',
          name: 'Ana',
          total: 5000,
          allocated: 0,
          occurredOn: '2026-11-20',
        ),
      ],
      month: DateTime(2026, 11),
      today: today,
    );

    expect(november.billedCents, 10000);
    expect(november.receivedCents, 4000);
    expect(november.openCents, 6000);
    expect(november.receivedPercent, 40);
    expect(november.salesByDay, {2: 10000});
    expect(november.chartDays, 3);
    expect(november.empty, isFalse);
  });

  test('another month and unused credit do not inflate what was received', () {
    final sales = [
      sale(
        id: 'october',
        customerId: 'bia',
        name: 'Bia',
        total: 8000,
        allocated: 8000,
        occurredOn: '2026-10-20',
      ),
      sale(
        id: 'november',
        customerId: 'ana',
        name: 'Ana',
        total: 5000,
        allocated: 0,
        occurredOn: '2026-11-02',
      ),
    ];

    final november = monthSnapshot(
      sales: sales,
      month: DateTime(2026, 11),
      today: today,
    );
    final october = monthSnapshot(
      sales: sales,
      month: DateTime(2026, 10),
      today: today,
    );
    final empty = monthSnapshot(
      sales: const [],
      month: DateTime(2026, 11),
      today: today,
    );

    expect(november.receivedCents, 0);
    expect(november.billedCents, 5000);
    expect(november.openCents, 5000);
    expect(october.billedCents, 8000);
    expect(october.receivedCents, 8000);
    expect(october.openCents, 0);
    expect(october.receivedPercent, 100);
    expect(october.chartDays, 31);
    expect(empty.billedCents, 0);
    expect(empty.receivedCents, 0);
    expect(empty.openCents, 0);
    expect(empty.receivedPercent, 0);
    expect(empty.empty, isTrue);
    expect(
      monthSnapshot(
        sales: sales,
        month: DateTime(2026, 12),
        today: today,
      ).chartDays,
      0,
    );
  });

  test('today groups one customer and discounts a partial payment', () {
    final due = duesToday(
      sales: [
        sale(
          id: 'a1',
          customerId: 'ana',
          name: 'Ana Paula',
          total: 10000,
          allocated: 2500,
          occurredOn: '2026-11-01',
          dueOn: '2026-11-03',
        ),
        sale(
          id: 'a2',
          customerId: 'ana',
          name: 'Ana Paula',
          total: 3000,
          allocated: 0,
          occurredOn: '2026-10-01',
          dueOn: '2026-11-03',
        ),
        sale(
          id: 'later',
          customerId: 'ana',
          name: 'Ana Paula',
          total: 2000,
          allocated: 0,
          occurredOn: '2026-11-01',
          dueOn: '2026-11-10',
        ),
        sale(
          id: 'opening',
          customerId: 'ana',
          name: 'Ana Paula',
          total: 4000,
          allocated: 4000,
          occurredOn: '2026-11-01',
          dueOn: '2026-11-03',
          isSale: false,
        ),
        sale(
          id: 'bia',
          customerId: 'bia',
          name: 'Ana Paula',
          total: 1500,
          allocated: 0,
          occurredOn: '2026-11-02',
          dueOn: '2026-11-03',
        ),
      ],
      today: today,
    );

    expect(due, hasLength(2));
    final ana = due.singleWhere((customer) => customer.customerId == 'ana');
    expect(ana.dueCents, 7500 + 3000);
    expect(ana.purchaseCount, 2);
    expect(ana.balanceCents, 7500 + 3000 + 2000);
    final bia = due.singleWhere((customer) => customer.customerId == 'bia');
    expect(bia.dueCents, 1500);
    expect(bia.purchaseCount, 1);
  });

  test('street sales keep only allocated shares and dated records', () {
    const line = SaleLine(
      productName: 'Alface',
      quantity: 1,
      unit: SaleUnit.bunch,
      unitPriceCents: 10000,
    );
    const ledger = StreetLedger(
      orders: [
        SaleOrder(
          id: 'real',
          code: '1',
          customerId: 'ana',
          customerName: 'Ana',
          lines: [line],
          recorded: true,
          delivered: true,
          occurredOn: '2026-11-02',
        ),
        SaleOrder(
          id: 'demo',
          code: '2',
          customerId: 'ana',
          customerName: 'Ana',
          lines: [line],
          recorded: true,
          delivered: false,
          fromSeed: true,
          occurredOn: '2026-11-02',
        ),
        SaleOrder(
          id: 'draft',
          code: '3',
          customerId: 'ana',
          customerName: 'Ana',
          lines: [line],
          recorded: false,
          delivered: false,
          occurredOn: '2026-11-02',
        ),
        SaleOrder(
          id: 'undated',
          code: '4',
          customerId: 'ana',
          customerName: 'Ana',
          lines: [line],
          recorded: true,
          delivered: true,
        ),
      ],
      payments: [
        CustomerPayment(
          id: 'pay',
          customerId: 'ana',
          amountCents: 9000,
          paidOn: '2026-11-03',
          method: PaymentMethod.pix,
          shares: [PaymentShare(orderId: 'real', amountCents: 4000)],
        ),
      ],
    );

    final sales = confirmedStreetSales(ledger);
    expect(sales, hasLength(1));
    expect(sales.single.allocatedCents, 4000);
    final month = monthSnapshot(
      sales: sales,
      month: DateTime(2026, 11),
      today: today,
    );
    expect(month.billedCents, 10000);
    expect(month.receivedCents, 4000);
    expect(month.openCents, 6000);
  });

  test(
    'month billed delta compares the current month with the previous one',
    () {
      final sales = [
        sale(
          id: 'october',
          customerId: 'bia',
          name: 'Bia',
          total: 10000,
          allocated: 10000,
          occurredOn: '2026-10-20',
        ),
        sale(
          id: 'november',
          customerId: 'ana',
          name: 'Ana',
          total: 14830,
          allocated: 5000,
          occurredOn: '2026-11-02',
        ),
      ];

      final delta = monthBilledDelta(sales: sales, today: today);
      expect(delta.billedCents, 14830);
      expect(delta.deltaCents, 4830);
      expect(delta.hasPercent, isTrue);
      expect(delta.deltaPercent, closeTo(48.3, 0.01));

      final empty = monthBilledDelta(sales: const [], today: today);
      expect(empty.billedCents, 0);
      expect(empty.deltaCents, 0);
      expect(empty.hasPercent, isFalse);
    },
  );
}
