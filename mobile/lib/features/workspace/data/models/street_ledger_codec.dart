import 'dart:convert';

import '../../domain/entities/street_ledger.dart';

String encodeStreetLedger(StreetLedger ledger) {
  return jsonEncode(ledger.toMap());
}

StreetLedger decodeStreetLedger(String source) {
  final map = jsonDecode(source) as Map<String, dynamic>;
  return StreetLedger(
    day: map['day'] as String,
    nextNumber: map['nextNumber'] as int,
    visits: [
      for (final item in map['visits'] as List<dynamic>)
        _visit(item as Map<String, dynamic>),
    ],
    orders: [
      for (final item in map['orders'] as List<dynamic>)
        _order(item as Map<String, dynamic>),
    ],
    payments: [
      for (final item in map['payments'] as List<dynamic>)
        _payment(item as Map<String, dynamic>),
    ],
    agreements: [
      for (final item in map['agreements'] as List<dynamic>)
        _agreement(item as Map<String, dynamic>),
    ],
  );
}

extension on StreetLedger {
  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'nextNumber': nextNumber,
      'visits': [
        for (final visit in visits)
          {
            'id': visit.id,
            'customerId': visit.customerId,
            'customerName': visit.customerName,
            'address': visit.address,
            'reasons': [for (final reason in visit.reasons) reason.name],
            'status': visit.status.name,
            'position': visit.position,
            'day': visit.day,
            'note': visit.note,
            'rescheduledTo': visit.rescheduledTo,
            'legacy': visit.legacy,
          },
      ],
      'orders': [
        for (final order in orders)
          {
            'id': order.id,
            'code': order.code,
            'customerId': order.customerId,
            'customerName': order.customerName,
            'lines': [
              for (final line in order.lines)
                {
                  'productName': line.productName,
                  'quantity': line.quantity,
                  'unit': line.unit.name,
                  'unitPriceCents': line.unitPriceCents,
                },
            ],
            'recorded': order.recorded,
            'delivered': order.delivered,
            'createdVisitId': order.createdVisitId,
            'deliveredDuringVisitId': order.deliveredDuringVisitId,
            'correctedDuringVisitId': order.correctedDuringVisitId,
            'revisions': [
              for (final revision in order.revisions)
                {
                  'lines': [
                    for (final line in revision.lines)
                      {
                        'productName': line.productName,
                        'quantity': line.quantity,
                        'unit': line.unit.name,
                        'unitPriceCents': line.unitPriceCents,
                      },
                  ],
                },
            ],
            'fromSeed': order.fromSeed,
            'note': order.note,
            'occurredOn': order.occurredOn,
            'recordedAt': order.recordedAt,
            'legacy': order.legacy,
          },
      ],
      'payments': [
        for (final payment in payments)
          {
            'id': payment.id,
            'customerId': payment.customerId,
            'amountCents': payment.amountCents,
            'paidOn': payment.paidOn,
            'method': payment.method.name,
            'visitId': payment.visitId,
            'shares': [
              for (final share in payment.shares)
                {'orderId': share.orderId, 'amountCents': share.amountCents},
            ],
            'fromSeed': payment.fromSeed,
            'note': payment.note,
            'legacy': payment.legacy,
          },
      ],
      'agreements': [
        for (final agreement in agreements)
          {
            'id': agreement.id,
            'customerId': agreement.customerId,
            'agreedOn': agreement.agreedOn,
            'visitId': agreement.visitId,
            'note': agreement.note,
            'legacy': agreement.legacy,
          },
      ],
    };
  }
}

RouteVisit _visit(Map<String, dynamic> map) {
  return RouteVisit(
    id: map['id'] as String,
    customerId: map['customerId'] as String,
    customerName: map['customerName'] as String,
    address: map['address'] as String,
    reasons: [
      for (final reason in map['reasons'] as List<dynamic>)
        VisitReason.values.byName(reason as String),
    ],
    status: VisitStatus.values.byName(map['status'] as String),
    position: map['position'] as int,
    day: map['day'] as String,
    note: map['note'] as String?,
    rescheduledTo: map['rescheduledTo'] as String?,
    legacy: map.containsKey('legacy') ? map['legacy'] as bool : true,
  );
}

SaleLine _line(Map<String, dynamic> map) {
  return SaleLine(
    productName: map['productName'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unit: SaleUnit.values.byName(map['unit'] as String),
    unitPriceCents: map['unitPriceCents'] as int,
  );
}

SaleOrder _order(Map<String, dynamic> map) {
  return SaleOrder(
    id: map['id'] as String,
    code: map['code'] as String,
    customerId: map['customerId'] as String,
    customerName: map['customerName'] as String,
    lines: [
      for (final line in map['lines'] as List<dynamic>)
        _line(line as Map<String, dynamic>),
    ],
    recorded: map['recorded'] as bool,
    delivered: map['delivered'] as bool,
    createdVisitId: map['createdVisitId'] as String?,
    deliveredDuringVisitId: map['deliveredDuringVisitId'] as String?,
    correctedDuringVisitId: map['correctedDuringVisitId'] as String?,
    revisions: [
      for (final revision in map['revisions'] as List<dynamic>)
        SaleRevision(
          lines: [
            for (final line
                in (revision as Map<String, dynamic>)['lines'] as List<dynamic>)
              _line(line as Map<String, dynamic>),
          ],
        ),
    ],
    fromSeed: map['fromSeed'] as bool? ?? false,
    note: map['note'] as String?,
    occurredOn: map['occurredOn'] as String?,
    recordedAt: map['recordedAt'] as String?,
    legacy: map.containsKey('legacy') ? map['legacy'] as bool : true,
  );
}

CustomerPayment _payment(Map<String, dynamic> map) {
  return CustomerPayment(
    id: map['id'] as String,
    customerId: map['customerId'] as String,
    amountCents: map['amountCents'] as int,
    paidOn: map['paidOn'] as String,
    method: PaymentMethod.values.byName(map['method'] as String),
    visitId: map['visitId'] as String?,
    shares: [
      for (final share in map['shares'] as List<dynamic>)
        PaymentShare(
          orderId: (share as Map<String, dynamic>)['orderId'] as String,
          amountCents: share['amountCents'] as int,
        ),
    ],
    fromSeed: map['fromSeed'] as bool? ?? false,
    note: map['note'] as String?,
    legacy: map.containsKey('legacy') ? map['legacy'] as bool : true,
  );
}

PaymentAgreement _agreement(Map<String, dynamic> map) {
  return PaymentAgreement(
    id: map['id'] as String,
    customerId: map['customerId'] as String,
    agreedOn: map['agreedOn'] as String,
    visitId: map['visitId'] as String?,
    note: map['note'] as String?,
    legacy: map.containsKey('legacy') ? map['legacy'] as bool : true,
  );
}
