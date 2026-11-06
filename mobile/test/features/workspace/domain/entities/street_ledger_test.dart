import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';

void main() {
  const visitId = 'visit-primavera';
  const customerId = 'demo-customer-primavera';

  StreetLedger ledger() {
    return const StreetLedger(
      day: '2026-10-20',
      nextNumber: 1100,
      visits: [
        RouteVisit(
          id: visitId,
          customerId: customerId,
          customerName: 'Restaurante Primavera',
          address: 'Rua das Flores, 120 · Centro',
          reasons: [VisitReason.delivery, VisitReason.collection],
          status: VisitStatus.pending,
          position: 0,
          day: '2026-10-20',
        ),
        RouteVisit(
          id: 'visit-mercado',
          customerId: 'demo-customer-mercado',
          customerName: 'Mercado Central',
          address: 'Av. Brasil, 450 · Centro',
          reasons: [VisitReason.delivery],
          status: VisitStatus.pending,
          position: 1,
          day: '2026-10-20',
        ),
      ],
      orders: [
        SaleOrder(
          id: 'order-1042',
          code: '1042',
          customerId: customerId,
          customerName: 'Restaurante Primavera',
          lines: [
            SaleLine(
              productName: 'Banana nanica',
              quantity: 10,
              unit: SaleUnit.kilogram,
              unitPriceCents: 1864,
            ),
          ],
          recorded: true,
          delivered: false,
          fromSeed: true,
        ),
      ],
    );
  }

  test('should price decimal quantities without mixing units', () {
    const lines = [
      SaleLine(
        productName: 'Alface crespa',
        quantity: 2.5,
        unit: SaleUnit.bunch,
        unitPriceCents: 350,
      ),
      SaleLine(
        productName: 'Banana nanica',
        quantity: 1.5,
        unit: SaleUnit.kilogram,
        unitPriceCents: 1000,
      ),
    ];

    expect(lines.first.totalCents, 875);
    expect(lineQuantitiesByUnit(lines)[SaleUnit.bunch], 2.5);
    expect(lineQuantitiesByUnit(lines)[SaleUnit.kilogram], 1.5);
    expect(lineQuantitiesByUnit(lines).length, 2);
  });

  test(
    'should keep sale, delivery, agreement and visit apart from payment',
    () {
      final priced = ledger();
      expect(customerBalanceCents(priced, customerId), 18640);

      final delivered = updateStreetLedger(
        priced,
        const MarkOrderDelivered(orderId: 'order-1042', visitId: visitId),
      ).ledger!;
      expect(delivered.orders.single.delivered, isTrue);
      expect(customerBalanceCents(delivered, customerId), 18640);

      final agreed = updateStreetLedger(
        delivered,
        const RegisterAgreement(
          visitId: visitId,
          customerId: customerId,
          agreedOn: '2026-10-22',
        ),
      ).ledger!;
      expect(customerBalanceCents(agreed, customerId), 18640);

      final completed = updateStreetLedger(
        agreed,
        const CompleteVisit(visitId),
      ).ledger!;
      expect(completed.visits.first.status, VisitStatus.completed);
      expect(customerBalanceCents(completed, customerId), 18640);
    },
  );

  test('should reduce the balance on a partial payment and keep history', () {
    final paid = updateStreetLedger(
      ledger(),
      const RegisterPayment(
        visitId: visitId,
        customerId: customerId,
        amountCents: 10000,
        paidOn: '2026-10-20',
        method: PaymentMethod.cash,
        orderIds: ['order-1042'],
      ),
    ).ledger!;

    expect(customerBalanceCents(paid, customerId), 8640);
    expect(orderOpenCents(paid, paid.orders.single), 8640);
    expect(paid.payments.single.shares.single.amountCents, 10000);

    final corrected = updateStreetLedger(
      paid,
      const SaveSale(
        visitId: visitId,
        customerId: customerId,
        customerName: 'Restaurante Primavera',
        orderId: 'order-1042',
        lines: [
          SaleLine(
            productName: 'Banana nanica',
            quantity: 8,
            unit: SaleUnit.kilogram,
            unitPriceCents: 1864,
          ),
        ],
      ),
    ).ledger!;

    expect(corrected.orders.single.revisions.single.totalCents, 18640);
    expect(corrected.orders.single.totalCents, 14912);
    expect(customerBalanceCents(corrected, customerId), 4912);
    expect(corrected.orders, hasLength(1));
  });

  test('should reorder, remove and reschedule without deleting purchases', () {
    final reordered = updateStreetLedger(
      ledger(),
      const ReorderRouteVisits(['visit-mercado', visitId]),
    ).ledger!;
    final today = visitsOnDay(reordered, '2026-10-20');
    expect(today.map((visit) => visit.id), ['visit-mercado', visitId]);

    final removed = updateStreetLedger(
      reordered,
      const RemoveRouteVisit('visit-mercado'),
    ).ledger!;
    expect(visitsOnDay(removed, '2026-10-20'), hasLength(1));
    expect(removed.orders, hasLength(1));

    final missed = updateStreetLedger(
      ledger(),
      const MissVisit(visitId: visitId, rescheduleOn: '2026-10-21'),
    ).ledger!;
    final original = missed.visits.firstWhere((visit) => visit.id == visitId);
    expect(original.status, VisitStatus.missed);
    expect(original.rescheduledTo, '2026-10-21');
    expect(
      missed.visits.where((visit) => visit.day == '2026-10-21').single.status,
      VisitStatus.pending,
    );
    expect(customerBalanceCents(missed, customerId), 18640);
    expect(visitProgress(missed).done, 1);
  });

  test('should describe only what happened in the visit', () {
    var current = ledger();
    current = updateStreetLedger(
      current,
      const SaveSale(
        visitId: visitId,
        customerId: customerId,
        customerName: 'Restaurante Primavera',
        lines: [
          SaleLine(
            productName: 'Alface crespa',
            quantity: 2,
            unit: SaleUnit.bunch,
            unitPriceCents: 350,
          ),
        ],
      ),
    ).ledger!;
    current = updateStreetLedger(
      current,
      const MarkOrderDelivered(orderId: 'order-1042', visitId: visitId),
    ).ledger!;
    final work = visitWork(current, visitId);

    expect(work.sales.single.totalCents, 700);
    expect(work.deliveries.single.id, 'order-1042');
    expect(work.payments, isEmpty);
    expect(customerBalanceCents(current, customerId), 19340);
  });
}
