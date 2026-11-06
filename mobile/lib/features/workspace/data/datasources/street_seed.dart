import '../../domain/entities/street_ledger.dart';

const legacyCompanyNames = {
  'demo-customer-primavera': 'Restaurante Primavera',
  'demo-customer-mercado': 'Mercado Central',
  'demo-customer-padaria': 'Padaria Bom Sabor',
  'demo-customer-hortifruti': 'Hortifruti São José',
};

const personCustomerNames = {
  'demo-customer-primavera': 'Marina Costa',
  'demo-customer-mercado': 'Ricardo Alves',
  'demo-customer-padaria': 'Beatriz Nunes',
  'demo-customer-hortifruti': 'Pedro Almeida',
};

String displayCustomerName(String customerId, String current) {
  if (legacyCompanyNames[customerId] == current) {
    return personCustomerNames[customerId] ?? current;
  }
  return current;
}

StreetLedger withPersonNames(StreetLedger ledger) {
  return StreetLedger(
    day: ledger.day,
    nextNumber: ledger.nextNumber,
    payments: ledger.payments,
    agreements: ledger.agreements,
    visits: [
      for (final visit in ledger.visits)
        RouteVisit(
          id: visit.id,
          customerId: visit.customerId,
          customerName: displayCustomerName(
            visit.customerId,
            visit.customerName,
          ),
          address: visit.address,
          reasons: visit.reasons,
          status: visit.status,
          position: visit.position,
          day: visit.day,
          note: visit.note,
          rescheduledTo: visit.rescheduledTo,
          legacy: visit.legacy,
        ),
    ],
    orders: [
      for (final order in ledger.orders)
        SaleOrder(
          id: order.id,
          code: order.code,
          customerId: order.customerId,
          customerName: displayCustomerName(
            order.customerId,
            order.customerName,
          ),
          lines: order.lines,
          recorded: order.recorded,
          delivered: order.delivered,
          createdVisitId: order.createdVisitId,
          deliveredDuringVisitId: order.deliveredDuringVisitId,
          correctedDuringVisitId: order.correctedDuringVisitId,
          revisions: order.revisions,
          fromSeed: order.fromSeed,
          note: order.note,
          occurredOn: order.occurredOn,
          recordedAt: order.recordedAt,
          legacy: order.legacy,
        ),
    ],
  );
}

StreetLedger seedStreetLedger({DateTime? today}) {
  final day = isoDate(today ?? DateTime.now());
  return StreetLedger(
    day: day,
    nextNumber: 1044,
    visits: [
      RouteVisit(
        id: 'visit-primavera',
        customerId: 'demo-customer-primavera',
        customerName: 'Marina Costa',
        address: 'Rua das Flores, 120 · Centro',
        reasons: const [VisitReason.delivery, VisitReason.collection],
        status: VisitStatus.pending,
        position: 0,
        day: day,
      ),
      RouteVisit(
        id: 'visit-mercado',
        customerId: 'demo-customer-mercado',
        customerName: 'Ricardo Alves',
        address: 'Av. Brasil, 450 · Centro',
        reasons: const [VisitReason.delivery],
        status: VisitStatus.pending,
        position: 1,
        day: day,
      ),
      RouteVisit(
        id: 'visit-padaria',
        customerId: 'demo-customer-padaria',
        customerName: 'Beatriz Nunes',
        address: 'Rua do Comércio, 88 · Batel',
        reasons: const [VisitReason.sale],
        status: VisitStatus.pending,
        position: 2,
        day: day,
      ),
      RouteVisit(
        id: 'visit-saojose',
        customerId: 'demo-customer-hortifruti',
        customerName: 'Pedro Almeida',
        address: 'Rua das Hortênsias, 45 · Centro',
        reasons: const [VisitReason.sale],
        status: VisitStatus.pending,
        position: 3,
        day: day,
      ),
    ],
    orders: const [
      SaleOrder(
        id: 'order-1042',
        code: '1042',
        customerId: 'demo-customer-primavera',
        customerName: 'Marina Costa',
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
      SaleOrder(
        id: 'order-1043',
        code: '1043',
        customerId: 'demo-customer-mercado',
        customerName: 'Ricardo Alves',
        lines: [
          SaleLine(
            productName: 'Tomate italiano',
            quantity: 40,
            unit: SaleUnit.kilogram,
            unitPriceCents: 1050,
          ),
        ],
        recorded: true,
        delivered: false,
        fromSeed: true,
      ),
      SaleOrder(
        id: 'order-1041',
        code: '1041',
        customerId: 'demo-customer-padaria',
        customerName: 'Beatriz Nunes',
        lines: [
          SaleLine(
            productName: 'Maçã gala',
            quantity: 8,
            unit: SaleUnit.piece,
            unitPriceCents: 900,
          ),
        ],
        recorded: true,
        delivered: true,
        fromSeed: true,
      ),
    ],
    payments: const [
      CustomerPayment(
        id: 'pay-1041',
        customerId: 'demo-customer-padaria',
        amountCents: 7200,
        paidOn: '2026-10-20',
        method: PaymentMethod.pix,
        shares: [PaymentShare(orderId: 'order-1041', amountCents: 7200)],
        fromSeed: true,
      ),
    ],
    agreements: const [
      PaymentAgreement(
        id: 'agree-primavera',
        customerId: 'demo-customer-primavera',
        agreedOn: '2026-10-22',
        note: 'Paga na próxima entrega.',
      ),
    ],
  );
}
