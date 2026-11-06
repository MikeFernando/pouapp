import 'package:equatable/equatable.dart';

enum SaleUnit { kilogram, piece, bunch }

enum VisitReason { sale, delivery, collection }

enum VisitStatus { pending, inService, completed, missed }

enum PaymentMethod { cash, pix, card }

String isoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime dateFromIso(String iso) {
  final parts = iso.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

class SaleLine extends Equatable {
  const SaleLine({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPriceCents,
  });

  final String productName;
  final double quantity;
  final SaleUnit unit;
  final int unitPriceCents;

  int get totalCents => (quantity * unitPriceCents).round();

  @override
  List<Object?> get props => [productName, quantity, unit, unitPriceCents];
}

class SaleRevision extends Equatable {
  const SaleRevision({required this.lines});

  final List<SaleLine> lines;

  int get totalCents => lines.fold(0, (sum, line) => sum + line.totalCents);

  @override
  List<Object?> get props => [lines];
}

class SaleOrder extends Equatable {
  const SaleOrder({
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerName,
    required this.lines,
    required this.recorded,
    required this.delivered,
    this.createdVisitId,
    this.deliveredDuringVisitId,
    this.correctedDuringVisitId,
    this.revisions = const [],
    this.fromSeed = false,
    this.note,
    this.occurredOn,
    this.recordedAt,
    this.legacy = false,
  });

  final String id;
  final String code;
  final String customerId;
  final String customerName;
  final List<SaleLine> lines;
  final bool recorded;
  final bool delivered;
  final String? createdVisitId;
  final String? deliveredDuringVisitId;
  final String? correctedDuringVisitId;
  final List<SaleRevision> revisions;
  final bool fromSeed;
  final String? note;

  /// Calendar day of the sale. Null when that day was not recorded.
  final String? occurredOn;

  /// Instant the sale was saved. Null on imported history.
  final String? recordedAt;

  /// Imported street history. Not a stock exit and not a new debt.
  final bool legacy;

  int get totalCents => lines.fold(0, (sum, line) => sum + line.totalCents);

  @override
  List<Object?> get props => [
    id,
    code,
    customerId,
    customerName,
    lines,
    recorded,
    delivered,
    createdVisitId,
    deliveredDuringVisitId,
    correctedDuringVisitId,
    revisions,
    fromSeed,
    note,
    occurredOn,
    recordedAt,
    legacy,
  ];
}

class PaymentShare extends Equatable {
  const PaymentShare({required this.orderId, required this.amountCents});

  final String orderId;
  final int amountCents;

  @override
  List<Object?> get props => [orderId, amountCents];
}

class CustomerPayment extends Equatable {
  const CustomerPayment({
    required this.id,
    required this.customerId,
    required this.amountCents,
    required this.paidOn,
    required this.method,
    this.visitId,
    this.shares = const [],
    this.fromSeed = false,
    this.note,
    this.legacy = false,
  });

  final String id;
  final String customerId;
  final int amountCents;
  final String paidOn;
  final PaymentMethod method;
  final String? visitId;
  final List<PaymentShare> shares;
  final bool fromSeed;
  final String? note;
  final bool legacy;

  @override
  List<Object?> get props => [
    id,
    customerId,
    amountCents,
    paidOn,
    method,
    visitId,
    shares,
    fromSeed,
    note,
    legacy,
  ];
}

class PaymentAgreement extends Equatable {
  const PaymentAgreement({
    required this.id,
    required this.customerId,
    required this.agreedOn,
    this.visitId,
    this.note,
    this.legacy = false,
  });

  final String id;
  final String customerId;
  final String agreedOn;
  final String? visitId;
  final String? note;
  final bool legacy;

  @override
  List<Object?> get props => [id, customerId, agreedOn, visitId, note, legacy];
}

class RouteVisit extends Equatable {
  const RouteVisit({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.address,
    required this.reasons,
    required this.status,
    required this.position,
    required this.day,
    this.note,
    this.rescheduledTo,
    this.legacy = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String address;
  final List<VisitReason> reasons;
  final VisitStatus status;
  final int position;
  final String day;
  final String? note;
  final String? rescheduledTo;
  final bool legacy;

  @override
  List<Object?> get props => [
    id,
    customerId,
    customerName,
    address,
    reasons,
    status,
    position,
    day,
    note,
    rescheduledTo,
    legacy,
  ];
}

class RouteCustomerOption extends Equatable {
  const RouteCustomerOption({
    required this.id,
    required this.name,
    required this.address,
  });

  final String id;
  final String name;
  final String address;

  @override
  List<Object?> get props => [id, name, address];
}

class StreetLedger extends Equatable {
  const StreetLedger({
    this.day = '2026-10-20',
    this.nextNumber = 1044,
    this.visits = const [],
    this.orders = const [],
    this.payments = const [],
    this.agreements = const [],
  });

  final String day;
  final int nextNumber;
  final List<RouteVisit> visits;
  final List<SaleOrder> orders;
  final List<CustomerPayment> payments;
  final List<PaymentAgreement> agreements;

  @override
  List<Object?> get props => [
    day,
    nextNumber,
    visits,
    orders,
    payments,
    agreements,
  ];
}

class VisitProgress extends Equatable {
  const VisitProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  List<Object?> get props => [done, total];
}

class VisitWork extends Equatable {
  const VisitWork({
    required this.sales,
    required this.deliveries,
    required this.payments,
    required this.agreements,
    required this.corrections,
  });

  final List<SaleOrder> sales;
  final List<SaleOrder> deliveries;
  final List<CustomerPayment> payments;
  final List<PaymentAgreement> agreements;
  final List<SaleOrder> corrections;

  @override
  List<Object?> get props => [
    sales,
    deliveries,
    payments,
    agreements,
    corrections,
  ];
}

sealed class StreetChange extends Equatable {
  const StreetChange();
}

class AddRouteVisit extends StreetChange {
  const AddRouteVisit({
    required this.customerId,
    required this.customerName,
    required this.address,
    required this.reasons,
  });

  final String customerId;
  final String customerName;
  final String address;
  final List<VisitReason> reasons;

  @override
  List<Object?> get props => [customerId, customerName, address, reasons];
}

class RemoveRouteVisit extends StreetChange {
  const RemoveRouteVisit(this.visitId);

  final String visitId;

  @override
  List<Object?> get props => [visitId];
}

class ReorderRouteVisits extends StreetChange {
  const ReorderRouteVisits(this.visitIds);

  final List<String> visitIds;

  @override
  List<Object?> get props => [visitIds];
}

class StartVisit extends StreetChange {
  const StartVisit(this.visitId);

  final String visitId;

  @override
  List<Object?> get props => [visitId];
}

class SaveSale extends StreetChange {
  const SaveSale({
    required this.visitId,
    required this.customerId,
    required this.customerName,
    required this.lines,
    this.orderId,
    this.note,
    this.occurredOn,
    this.recordedAt,
  });

  final String visitId;
  final String customerId;
  final String customerName;
  final List<SaleLine> lines;
  final String? orderId;
  final String? note;
  final String? occurredOn;
  final String? recordedAt;

  @override
  List<Object?> get props => [
    visitId,
    customerId,
    customerName,
    lines,
    orderId,
    note,
    occurredOn,
    recordedAt,
  ];
}

class MarkOrderDelivered extends StreetChange {
  const MarkOrderDelivered({required this.orderId, required this.visitId});

  final String orderId;
  final String visitId;

  @override
  List<Object?> get props => [orderId, visitId];
}

class RegisterPayment extends StreetChange {
  const RegisterPayment({
    required this.visitId,
    required this.customerId,
    required this.amountCents,
    required this.paidOn,
    required this.method,
    this.orderIds = const [],
    this.note,
  });

  final String visitId;
  final String customerId;
  final int amountCents;
  final String paidOn;
  final PaymentMethod method;
  final List<String> orderIds;
  final String? note;

  @override
  List<Object?> get props => [
    visitId,
    customerId,
    amountCents,
    paidOn,
    method,
    orderIds,
    note,
  ];
}

class RegisterAgreement extends StreetChange {
  const RegisterAgreement({
    required this.visitId,
    required this.customerId,
    required this.agreedOn,
    this.note,
  });

  final String visitId;
  final String customerId;
  final String agreedOn;
  final String? note;

  @override
  List<Object?> get props => [visitId, customerId, agreedOn, note];
}

class SaveVisitNote extends StreetChange {
  const SaveVisitNote({required this.visitId, required this.note});

  final String visitId;
  final String note;

  @override
  List<Object?> get props => [visitId, note];
}

class CompleteVisit extends StreetChange {
  const CompleteVisit(this.visitId);

  final String visitId;

  @override
  List<Object?> get props => [visitId];
}

class MissVisit extends StreetChange {
  const MissVisit({
    required this.visitId,
    required this.rescheduleOn,
    this.note,
  });

  final String visitId;
  final String rescheduleOn;
  final String? note;

  @override
  List<Object?> get props => [visitId, rescheduleOn, note];
}

class StreetUpdate extends Equatable {
  const StreetUpdate({this.ledger, this.error});

  final StreetLedger? ledger;
  final String? error;

  @override
  List<Object?> get props => [ledger, error];
}

int allocatedToOrder(StreetLedger ledger, String orderId) {
  var total = 0;
  for (final payment in ledger.payments) {
    for (final share in payment.shares) {
      if (share.orderId == orderId) total += share.amountCents;
    }
  }
  return total;
}

int orderOpenCents(StreetLedger ledger, SaleOrder order) {
  final open = order.totalCents - allocatedToOrder(ledger, order.id);
  return open < 0 ? 0 : open;
}

int customerBalanceCents(StreetLedger ledger, String customerId) {
  final sold = ledger.orders
      .where((order) => order.customerId == customerId && order.recorded)
      .fold<int>(0, (sum, order) => sum + order.totalCents);
  final paid = ledger.payments
      .where((payment) => payment.customerId == customerId)
      .fold<int>(0, (sum, payment) => sum + payment.amountCents);
  return sold - paid;
}

String? latestAgreementDate(StreetLedger ledger, String customerId) {
  final dates =
      ledger.agreements
          .where((agreement) => agreement.customerId == customerId)
          .map((agreement) => agreement.agreedOn)
          .toList()
        ..sort();
  if (dates.isEmpty) return null;
  return dates.last;
}

List<RouteVisit> visitsOnDay(StreetLedger ledger, String day) {
  final visits = ledger.visits.where((visit) => visit.day == day).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  return visits;
}

VisitProgress visitProgress(StreetLedger ledger) {
  final today = visitsOnDay(ledger, ledger.day);
  final done = today
      .where(
        (visit) =>
            visit.status == VisitStatus.completed ||
            visit.status == VisitStatus.missed,
      )
      .length;
  return VisitProgress(done: done, total: today.length);
}

Map<SaleUnit, double> lineQuantitiesByUnit(List<SaleLine> lines) {
  final totals = <SaleUnit, double>{};
  for (final line in lines) {
    totals[line.unit] = (totals[line.unit] ?? 0) + line.quantity;
  }
  return totals;
}

VisitWork visitWork(StreetLedger ledger, String visitId) {
  return VisitWork(
    sales: [
      for (final order in ledger.orders)
        if (order.createdVisitId == visitId) order,
    ],
    deliveries: [
      for (final order in ledger.orders)
        if (order.deliveredDuringVisitId == visitId) order,
    ],
    payments: [
      for (final payment in ledger.payments)
        if (payment.visitId == visitId) payment,
    ],
    agreements: [
      for (final agreement in ledger.agreements)
        if (agreement.visitId == visitId) agreement,
    ],
    corrections: [
      for (final order in ledger.orders)
        if (order.correctedDuringVisitId == visitId) order,
    ],
  );
}

RouteVisit? nextPendingVisit(StreetLedger ledger, String afterVisitId) {
  final today = visitsOnDay(ledger, ledger.day);
  final index = today.indexWhere((visit) => visit.id == afterVisitId);
  final rest = index < 0 ? today : today.skip(index + 1);
  for (final visit in rest) {
    if (visit.status == VisitStatus.pending ||
        visit.status == VisitStatus.inService) {
      return visit;
    }
  }
  for (final visit in today) {
    if (visit.id == afterVisitId) continue;
    if (visit.status == VisitStatus.pending ||
        visit.status == VisitStatus.inService) {
      return visit;
    }
  }
  return null;
}

StreetUpdate updateStreetLedger(StreetLedger ledger, StreetChange change) {
  return switch (change) {
    AddRouteVisit() => _addVisit(ledger, change),
    RemoveRouteVisit() => _removeVisit(ledger, change),
    ReorderRouteVisits() => _reorder(ledger, change),
    StartVisit() => _startVisit(ledger, change),
    SaveSale() => _saveSale(ledger, change),
    MarkOrderDelivered() => _deliver(ledger, change),
    RegisterPayment() => _pay(ledger, change),
    RegisterAgreement() => _agree(ledger, change),
    SaveVisitNote() => _note(ledger, change),
    CompleteVisit() => _complete(ledger, change),
    MissVisit() => _miss(ledger, change),
  };
}

StreetUpdate _addVisit(StreetLedger ledger, AddRouteVisit change) {
  if (change.reasons.isEmpty) {
    return const StreetUpdate(error: 'Escolha o motivo da visita.');
  }
  final already = visitsOnDay(ledger, ledger.day).any(
    (visit) =>
        visit.customerId == change.customerId &&
        visit.status != VisitStatus.missed,
  );
  if (already) {
    return const StreetUpdate(
      error: 'Esta cliente já está no roteiro de hoje.',
    );
  }
  final today = visitsOnDay(ledger, ledger.day);
  final visit = RouteVisit(
    id: 'visit-${ledger.nextNumber}',
    customerId: change.customerId,
    customerName: change.customerName,
    address: change.address,
    reasons: _reasons(change.reasons),
    status: VisitStatus.pending,
    position: today.length,
    day: ledger.day,
  );
  return StreetUpdate(
    ledger: _copy(
      ledger,
      nextNumber: ledger.nextNumber + 1,
      visits: [...ledger.visits, visit],
    ),
  );
}

StreetUpdate _removeVisit(StreetLedger ledger, RemoveRouteVisit change) {
  final visit = _visit(ledger, change.visitId);
  if (visit == null) {
    return const StreetUpdate(error: 'Visita não encontrada.');
  }
  if (visit.status == VisitStatus.completed ||
      visit.status == VisitStatus.inService) {
    return const StreetUpdate(
      error: 'Uma visita concluída ou em atendimento permanece no histórico.',
    );
  }
  final remaining = [
    for (final item in ledger.visits)
      if (item.id != visit.id) item,
  ];
  return StreetUpdate(
    ledger: _copy(ledger, visits: _reposition(remaining, ledger.day)),
  );
}

StreetUpdate _reorder(StreetLedger ledger, ReorderRouteVisits change) {
  final today = visitsOnDay(ledger, ledger.day);
  final byId = {for (final visit in today) visit.id: visit};
  if (change.visitIds.length != today.length ||
      change.visitIds.any((id) => !byId.containsKey(id))) {
    return const StreetUpdate(error: 'A ordem do roteiro está incompleta.');
  }
  final ordered = [
    for (var index = 0; index < change.visitIds.length; index++)
      _replaceVisit(byId[change.visitIds[index]]!, position: index),
  ];
  final others = [
    for (final visit in ledger.visits)
      if (visit.day != ledger.day) visit,
  ];
  return StreetUpdate(ledger: _copy(ledger, visits: [...others, ...ordered]));
}

StreetUpdate _startVisit(StreetLedger ledger, StartVisit change) {
  final visit = _visit(ledger, change.visitId);
  if (visit == null) {
    return const StreetUpdate(error: 'Visita não encontrada.');
  }
  if (visit.status != VisitStatus.pending) {
    return StreetUpdate(ledger: ledger);
  }
  return StreetUpdate(
    ledger: _copy(
      ledger,
      visits: _replace(ledger, visit, status: VisitStatus.inService),
    ),
  );
}

StreetUpdate _saveSale(StreetLedger ledger, SaveSale change) {
  if (change.lines.isEmpty ||
      change.lines.any((line) => line.productName.trim().isEmpty)) {
    return const StreetUpdate(error: 'Informe ao menos um item na venda.');
  }
  if (change.lines.any(
    (line) => line.quantity <= 0 || line.unitPriceCents < 0,
  )) {
    return const StreetUpdate(
      error: 'Quantidade e preço precisam ser válidos.',
    );
  }
  if (change.orderId == null) {
    final order = SaleOrder(
      id: 'order-${ledger.nextNumber}',
      code: '${ledger.nextNumber}',
      customerId: change.customerId,
      customerName: change.customerName,
      lines: change.lines,
      recorded: true,
      delivered: false,
      createdVisitId: change.visitId,
      note: change.note,
      occurredOn: change.occurredOn,
      recordedAt: change.recordedAt,
    );
    return StreetUpdate(
      ledger: _copy(
        ledger,
        nextNumber: ledger.nextNumber + 1,
        orders: [...ledger.orders, order],
      ),
    );
  }
  final current = _order(ledger, change.orderId!);
  if (current == null) {
    return const StreetUpdate(error: 'Pedido não encontrado.');
  }
  final corrected = SaleOrder(
    id: current.id,
    code: current.code,
    customerId: current.customerId,
    customerName: current.customerName,
    lines: change.lines,
    recorded: true,
    delivered: current.delivered,
    createdVisitId: current.createdVisitId,
    deliveredDuringVisitId: current.deliveredDuringVisitId,
    correctedDuringVisitId: change.visitId,
    revisions: [
      ...current.revisions,
      SaleRevision(lines: current.lines),
    ],
    fromSeed: current.fromSeed,
    note: change.note ?? current.note,
    occurredOn: current.occurredOn,
    recordedAt: current.recordedAt,
    legacy: current.legacy,
  );
  return StreetUpdate(
    ledger: _copy(ledger, orders: _replaceOrder(ledger, corrected)),
  );
}

StreetUpdate _deliver(StreetLedger ledger, MarkOrderDelivered change) {
  final current = _order(ledger, change.orderId);
  if (current == null) {
    return const StreetUpdate(error: 'Pedido não encontrado.');
  }
  if (current.delivered) return StreetUpdate(ledger: ledger);
  final delivered = SaleOrder(
    id: current.id,
    code: current.code,
    customerId: current.customerId,
    customerName: current.customerName,
    lines: current.lines,
    recorded: current.recorded,
    delivered: true,
    createdVisitId: current.createdVisitId,
    deliveredDuringVisitId: change.visitId,
    correctedDuringVisitId: current.correctedDuringVisitId,
    revisions: current.revisions,
    fromSeed: current.fromSeed,
    note: current.note,
    occurredOn: current.occurredOn,
    recordedAt: current.recordedAt,
    legacy: current.legacy,
  );
  return StreetUpdate(
    ledger: _copy(ledger, orders: _replaceOrder(ledger, delivered)),
  );
}

StreetUpdate _pay(StreetLedger ledger, RegisterPayment change) {
  if (change.amountCents <= 0) {
    return const StreetUpdate(
      error: 'O valor do pagamento precisa ser maior que zero.',
    );
  }
  final shares = <PaymentShare>[];
  var remaining = change.amountCents;
  for (final orderId in change.orderIds) {
    if (remaining <= 0) break;
    final order = _order(ledger, orderId);
    if (order == null || order.customerId != change.customerId) continue;
    final open = orderOpenCents(ledger, order);
    if (open <= 0) continue;
    final take = remaining < open ? remaining : open;
    shares.add(PaymentShare(orderId: order.id, amountCents: take));
    remaining -= take;
  }
  final payment = CustomerPayment(
    id: 'pay-${ledger.nextNumber}',
    customerId: change.customerId,
    amountCents: change.amountCents,
    paidOn: change.paidOn,
    method: change.method,
    visitId: change.visitId,
    shares: shares,
    note: change.note,
  );
  return StreetUpdate(
    ledger: _copy(
      ledger,
      nextNumber: ledger.nextNumber + 1,
      payments: [...ledger.payments, payment],
    ),
  );
}

StreetUpdate _agree(StreetLedger ledger, RegisterAgreement change) {
  final agreement = PaymentAgreement(
    id: 'agree-${ledger.nextNumber}',
    customerId: change.customerId,
    agreedOn: change.agreedOn,
    visitId: change.visitId,
    note: change.note,
  );
  return StreetUpdate(
    ledger: _copy(
      ledger,
      nextNumber: ledger.nextNumber + 1,
      agreements: [...ledger.agreements, agreement],
    ),
  );
}

StreetUpdate _note(StreetLedger ledger, SaveVisitNote change) {
  final visit = _visit(ledger, change.visitId);
  if (visit == null) {
    return const StreetUpdate(error: 'Visita não encontrada.');
  }
  return StreetUpdate(
    ledger: _copy(
      ledger,
      visits: _replace(ledger, visit, note: change.note, keepNote: false),
    ),
  );
}

StreetUpdate _complete(StreetLedger ledger, CompleteVisit change) {
  final visit = _visit(ledger, change.visitId);
  if (visit == null) {
    return const StreetUpdate(error: 'Visita não encontrada.');
  }
  return StreetUpdate(
    ledger: _copy(
      ledger,
      visits: _replace(ledger, visit, status: VisitStatus.completed),
    ),
  );
}

StreetUpdate _miss(StreetLedger ledger, MissVisit change) {
  final visit = _visit(ledger, change.visitId);
  if (visit == null) {
    return const StreetUpdate(error: 'Visita não encontrada.');
  }
  final missed = _replace(
    ledger,
    visit,
    status: VisitStatus.missed,
    rescheduledTo: change.rescheduleOn,
    note: change.note ?? visit.note,
    keepNote: change.note == null,
  );
  final futureCount = ledger.visits
      .where((item) => item.day == change.rescheduleOn)
      .length;
  final next = RouteVisit(
    id: 'visit-${ledger.nextNumber}',
    customerId: visit.customerId,
    customerName: visit.customerName,
    address: visit.address,
    reasons: visit.reasons,
    status: VisitStatus.pending,
    position: futureCount,
    day: change.rescheduleOn,
  );
  return StreetUpdate(
    ledger: _copy(
      ledger,
      nextNumber: ledger.nextNumber + 1,
      visits: [...missed, next],
    ),
  );
}

StreetLedger _copy(
  StreetLedger ledger, {
  int? nextNumber,
  List<RouteVisit>? visits,
  List<SaleOrder>? orders,
  List<CustomerPayment>? payments,
  List<PaymentAgreement>? agreements,
}) {
  return StreetLedger(
    day: ledger.day,
    nextNumber: nextNumber ?? ledger.nextNumber,
    visits: visits ?? ledger.visits,
    orders: orders ?? ledger.orders,
    payments: payments ?? ledger.payments,
    agreements: agreements ?? ledger.agreements,
  );
}

List<VisitReason> _reasons(List<VisitReason> reasons) {
  final unique = reasons.toSet().toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return unique;
}

RouteVisit? _visit(StreetLedger ledger, String id) {
  for (final visit in ledger.visits) {
    if (visit.id == id) return visit;
  }
  return null;
}

SaleOrder? _order(StreetLedger ledger, String id) {
  for (final order in ledger.orders) {
    if (order.id == id) return order;
  }
  return null;
}

List<RouteVisit> _replace(
  StreetLedger ledger,
  RouteVisit visit, {
  VisitStatus? status,
  int? position,
  String? note,
  bool keepNote = true,
  String? rescheduledTo,
}) {
  return [
    for (final item in ledger.visits)
      if (item.id == visit.id)
        _replaceVisit(
          item,
          status: status,
          position: position,
          note: keepNote ? item.note : note,
          rescheduledTo: rescheduledTo ?? item.rescheduledTo,
        )
      else
        item,
  ];
}

RouteVisit _replaceVisit(
  RouteVisit visit, {
  VisitStatus? status,
  int? position,
  String? note,
  String? rescheduledTo,
}) {
  return RouteVisit(
    id: visit.id,
    customerId: visit.customerId,
    customerName: visit.customerName,
    address: visit.address,
    reasons: visit.reasons,
    status: status ?? visit.status,
    position: position ?? visit.position,
    day: visit.day,
    note: note ?? visit.note,
    rescheduledTo: rescheduledTo ?? visit.rescheduledTo,
    legacy: visit.legacy,
  );
}

List<SaleOrder> _replaceOrder(StreetLedger ledger, SaleOrder order) {
  return [
    for (final item in ledger.orders)
      if (item.id == order.id) order else item,
  ];
}

List<RouteVisit> _reposition(List<RouteVisit> visits, String day) {
  final today = visits.where((visit) => visit.day == day).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  final positioned = [
    for (var index = 0; index < today.length; index++)
      _replaceVisit(today[index], position: index),
  ];
  return [
    for (final visit in visits)
      if (visit.day != day) visit,
    ...positioned,
  ];
}
