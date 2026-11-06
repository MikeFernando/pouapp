import 'package:equatable/equatable.dart';

enum FreightTripStatus { planned, underway, completed, cancelled }

enum FreightDirection { outbound, inbound, local }

enum FreightStatus { draft, scheduled, collected, delivered, cancelled }

enum FreightPayMethod { pix, cash, card }

enum FreightPaymentStanding { open, partial, paid }

class FreightMark extends Equatable {
  const FreightMark({required this.action, required this.at, this.note});

  final String action;
  final String at;
  final String? note;

  @override
  List<Object?> get props => [action, at, note];
}

class FreightTrip extends Equatable {
  const FreightTrip({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.departOn,
    required this.returnOn,
    required this.status,
    this.spaceNote,
  });

  final String id;
  final String name;
  final String origin;
  final String destination;
  final String departOn;
  final String returnOn;
  final FreightTripStatus status;
  final String? spaceNote;

  @override
  List<Object?> get props => [
    id,
    name,
    origin,
    destination,
    departOn,
    returnOn,
    status,
    spaceNote,
  ];
}

class FreightJob extends Equatable {
  const FreightJob({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.direction,
    required this.description,
    required this.pickup,
    required this.dropoff,
    required this.plannedOn,
    required this.priceCents,
    required this.status,
    required this.sortOrder,
    this.tripId,
    this.quantity,
    this.unit,
    this.pickupContact,
    this.dropoffContact,
    this.dueOn,
    this.notes,
    this.cancelReason,
    this.marks = const [],
  });

  final String id;
  final String customerId;
  final String customerName;
  final String? tripId;
  final FreightDirection direction;
  final String description;
  final String? quantity;
  final String? unit;
  final String pickup;
  final String dropoff;
  final String? pickupContact;
  final String? dropoffContact;
  final String plannedOn;
  final int priceCents;
  final String? dueOn;
  final String? notes;
  final FreightStatus status;
  final int sortOrder;
  final String? cancelReason;
  final List<FreightMark> marks;

  @override
  List<Object?> get props => [
    id,
    customerId,
    customerName,
    tripId,
    direction,
    description,
    quantity,
    unit,
    pickup,
    dropoff,
    pickupContact,
    dropoffContact,
    plannedOn,
    priceCents,
    dueOn,
    notes,
    status,
    sortOrder,
    cancelReason,
    marks,
  ];
}

class FreightReceipt extends Equatable {
  const FreightReceipt({
    required this.id,
    required this.jobId,
    required this.amountCents,
    required this.paidOn,
    required this.method,
    this.note,
    this.voided = false,
  });

  final String id;
  final String jobId;
  final int amountCents;
  final String paidOn;
  final FreightPayMethod method;
  final String? note;
  final bool voided;

  @override
  List<Object?> get props => [
    id,
    jobId,
    amountCents,
    paidOn,
    method,
    note,
    voided,
  ];
}

class FreightExpense extends Equatable {
  const FreightExpense({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.paidOn,
    this.tripId,
    this.jobId,
    this.paid = true,
  });

  final String id;
  final String? tripId;
  final String? jobId;
  final String description;
  final int amountCents;
  final String paidOn;
  final bool paid;

  @override
  List<Object?> get props => [
    id,
    tripId,
    jobId,
    description,
    amountCents,
    paidOn,
    paid,
  ];
}

class FreightLedger extends Equatable {
  const FreightLedger({
    this.trips = const [],
    this.jobs = const [],
    this.receipts = const [],
    this.expenses = const [],
    this.nextNumber = 1,
  });

  final List<FreightTrip> trips;
  final List<FreightJob> jobs;
  final List<FreightReceipt> receipts;
  final List<FreightExpense> expenses;
  final int nextNumber;

  @override
  List<Object?> get props => [trips, jobs, receipts, expenses, nextNumber];
}

class FreightUpdate extends Equatable {
  const FreightUpdate({this.ledger, this.error});

  final FreightLedger? ledger;
  final String? error;

  @override
  List<Object?> get props => [ledger, error];
}

class FreightPeriodSummary extends Equatable {
  const FreightPeriodSummary({
    required this.combinedCents,
    required this.receivedCents,
    required this.receivableCents,
    required this.pendingCount,
  });

  final int combinedCents;
  final int receivedCents;
  final int receivableCents;
  final int pendingCount;

  @override
  List<Object?> get props => [
    combinedCents,
    receivedCents,
    receivableCents,
    pendingCount,
  ];
}

class FreightTripSummary extends Equatable {
  const FreightTripSummary({
    required this.revenueCents,
    required this.receivedCents,
    required this.receivableCents,
    required this.pendingCount,
    required this.expenseCents,
    required this.paidExpenseCents,
  });

  final int revenueCents;
  final int receivedCents;
  final int receivableCents;
  final int pendingCount;
  final int expenseCents;
  final int paidExpenseCents;

  int get extraResultCents => revenueCents - expenseCents;

  int get cashAfterExpensesCents => receivedCents - paidExpenseCents;

  @override
  List<Object?> get props => [
    revenueCents,
    receivedCents,
    receivableCents,
    pendingCount,
    expenseCents,
    paidExpenseCents,
  ];
}

sealed class FreightChange extends Equatable {
  const FreightChange();
}

class SaveFreightTrip extends FreightChange {
  const SaveFreightTrip({
    this.id,
    required this.name,
    required this.departOn,
    required this.returnOn,
    this.origin = 'Apiaí',
    this.destination = 'Curitiba',
    this.spaceNote,
  });

  final String? id;
  final String name;
  final String origin;
  final String destination;
  final String departOn;
  final String returnOn;
  final String? spaceNote;

  @override
  List<Object?> get props => [
    id,
    name,
    origin,
    destination,
    departOn,
    returnOn,
    spaceNote,
  ];
}

class SaveFreightJob extends FreightChange {
  const SaveFreightJob({
    this.id,
    required this.customerId,
    required this.customerName,
    required this.direction,
    required this.description,
    required this.pickup,
    required this.dropoff,
    required this.plannedOn,
    required this.priceCents,
    this.tripId,
    this.quantity,
    this.unit,
    this.pickupContact,
    this.dropoffContact,
    this.dueOn,
    this.notes,
    this.draft = false,
    this.allowZero = false,
  });

  final String? id;
  final String customerId;
  final String customerName;
  final String? tripId;
  final FreightDirection direction;
  final String description;
  final String pickup;
  final String dropoff;
  final String plannedOn;
  final int priceCents;
  final String? quantity;
  final String? unit;
  final String? pickupContact;
  final String? dropoffContact;
  final String? dueOn;
  final String? notes;
  final bool draft;
  final bool allowZero;

  @override
  List<Object?> get props => [
    id,
    customerId,
    customerName,
    tripId,
    direction,
    description,
    pickup,
    dropoff,
    plannedOn,
    priceCents,
    quantity,
    unit,
    pickupContact,
    dropoffContact,
    dueOn,
    notes,
    draft,
    allowZero,
  ];
}

class CollectFreight extends FreightChange {
  const CollectFreight(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class DeliverFreight extends FreightChange {
  const DeliverFreight(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class CancelFreight extends FreightChange {
  const CancelFreight({
    required this.jobId,
    required this.reason,
    this.cargoNote,
  });

  final String jobId;
  final String reason;
  final String? cargoNote;

  @override
  List<Object?> get props => [jobId, reason, cargoNote];
}

class SaveFreightReceipt extends FreightChange {
  const SaveFreightReceipt({
    required this.id,
    required this.jobId,
    required this.amountCents,
    required this.paidOn,
    required this.method,
    this.note,
  });

  final String id;
  final String jobId;
  final int amountCents;
  final String paidOn;
  final FreightPayMethod method;
  final String? note;

  @override
  List<Object?> get props => [id, jobId, amountCents, paidOn, method, note];
}

class VoidFreightReceipt extends FreightChange {
  const VoidFreightReceipt(this.receiptId);

  final String receiptId;

  @override
  List<Object?> get props => [receiptId];
}

class SaveFreightExpense extends FreightChange {
  const SaveFreightExpense({
    required this.description,
    required this.amountCents,
    required this.paidOn,
    this.tripId,
    this.jobId,
    this.paid = true,
  });

  final String description;
  final int amountCents;
  final String paidOn;
  final String? tripId;
  final String? jobId;
  final bool paid;

  @override
  List<Object?> get props => [
    description,
    amountCents,
    paidOn,
    tripId,
    jobId,
    paid,
  ];
}

class CompleteFreightTrip extends FreightChange {
  const CompleteFreightTrip(this.tripId);

  final String tripId;

  @override
  List<Object?> get props => [tripId];
}

class StartFreightTrip extends FreightChange {
  const StartFreightTrip(this.tripId);

  final String tripId;

  @override
  List<Object?> get props => [tripId];
}

bool freightConfirmed(FreightJob job) {
  return job.status == FreightStatus.scheduled ||
      job.status == FreightStatus.collected ||
      job.status == FreightStatus.delivered;
}

bool freightInMonth(String iso, int year, int month) {
  final prefix = '$year-${month.toString().padLeft(2, '0')}';
  return iso.startsWith(prefix);
}

int netReceivedCents(FreightLedger ledger, String jobId) {
  return ledger.receipts
      .where((receipt) => receipt.jobId == jobId && !receipt.voided)
      .fold(0, (sum, receipt) => sum + receipt.amountCents);
}

int freightBalanceCents(FreightLedger ledger, FreightJob job) {
  return job.priceCents - netReceivedCents(ledger, job.id);
}

FreightPaymentStanding freightPaymentStanding(
  FreightLedger ledger,
  FreightJob job,
) {
  final received = netReceivedCents(ledger, job.id);
  if (job.priceCents == 0 && received == 0) {
    return FreightPaymentStanding.paid;
  }
  if (received <= 0) return FreightPaymentStanding.open;
  if (received < job.priceCents) return FreightPaymentStanding.partial;
  return FreightPaymentStanding.paid;
}

bool freightOverdue(FreightLedger ledger, FreightJob job, String today) {
  final due = job.dueOn;
  if (due == null || due.isEmpty || !freightConfirmed(job)) return false;
  if (freightBalanceCents(ledger, job) <= 0) return false;
  return due.compareTo(today) < 0;
}

FreightPeriodSummary freightPeriodSummary(
  FreightLedger ledger, {
  required int year,
  required int month,
}) {
  final jobs = ledger.jobs.where((job) {
    return freightConfirmed(job) && freightInMonth(job.plannedOn, year, month);
  });
  final combined = jobs.fold(0, (sum, job) => sum + job.priceCents);
  final receivable = jobs.fold(
    0,
    (sum, job) => sum + freightBalanceCents(ledger, job),
  );
  final pending = ledger.jobs.where((job) {
    final open =
        job.status == FreightStatus.scheduled ||
        job.status == FreightStatus.collected;
    return open && freightInMonth(job.plannedOn, year, month);
  }).length;
  final received = ledger.receipts
      .where(
        (receipt) =>
            !receipt.voided && freightInMonth(receipt.paidOn, year, month),
      )
      .fold(0, (sum, receipt) => sum + receipt.amountCents);
  return FreightPeriodSummary(
    combinedCents: combined,
    receivedCents: received,
    receivableCents: receivable,
    pendingCount: pending,
  );
}

FreightTripSummary freightTripSummary(FreightLedger ledger, String tripId) {
  final jobs = ledger.jobs.where(
    (job) => job.tripId == tripId && freightConfirmed(job),
  );
  final jobIds = jobs.map((job) => job.id).toSet();
  final revenue = jobs.fold(0, (sum, job) => sum + job.priceCents);
  final received = jobIds.fold(
    0,
    (sum, id) => sum + netReceivedCents(ledger, id),
  );
  final pending = ledger.jobs.where((job) {
    return job.tripId == tripId &&
        (job.status == FreightStatus.scheduled ||
            job.status == FreightStatus.collected);
  }).length;
  final seen = <String>{};
  var expenses = 0;
  var paidExpenses = 0;
  for (final expense in ledger.expenses) {
    final linked =
        expense.tripId == tripId ||
        (expense.jobId != null && jobIds.contains(expense.jobId));
    if (!linked || !seen.add(expense.id)) continue;
    expenses += expense.amountCents;
    if (expense.paid) paidExpenses += expense.amountCents;
  }
  return FreightTripSummary(
    revenueCents: revenue,
    receivedCents: received,
    receivableCents: revenue - received,
    pendingCount: pending,
    expenseCents: expenses,
    paidExpenseCents: paidExpenses,
  );
}

FreightTrip? nextFreightTrip(FreightLedger ledger) {
  final open =
      ledger.trips
          .where(
            (trip) =>
                trip.status == FreightTripStatus.planned ||
                trip.status == FreightTripStatus.underway,
          )
          .toList()
        ..sort((a, b) => a.departOn.compareTo(b.departOn));
  if (open.isEmpty) return null;
  return open.first;
}

FreightUpdate updateFreightLedger(
  FreightLedger ledger,
  FreightChange change, {
  DateTime? now,
}) {
  final at = (now ?? DateTime.now()).toIso8601String();
  return switch (change) {
    SaveFreightTrip() => _saveTrip(ledger, change),
    SaveFreightJob() => _saveJob(ledger, change, at),
    CollectFreight() => _collect(ledger, change, at),
    DeliverFreight() => _deliver(ledger, change, at),
    CancelFreight() => _cancel(ledger, change, at),
    SaveFreightReceipt() => _receipt(ledger, change),
    VoidFreightReceipt() => _voidReceipt(ledger, change),
    SaveFreightExpense() => _expense(ledger, change),
    CompleteFreightTrip() => _completeTrip(ledger, change),
    StartFreightTrip() => _startTrip(ledger, change),
  };
}

FreightLedger exampleFreightLedger() {
  return const FreightLedger(
    nextNumber: 4,
    trips: [
      FreightTrip(
        id: 'trip-curitiba',
        name: 'Curitiba — outubro',
        origin: 'Apiaí',
        destination: 'Curitiba',
        departOn: '2026-10-28',
        returnOn: '2026-10-29',
        status: FreightTripStatus.planned,
        spaceNote: 'A volta leva as compras do Ceasa.',
      ),
    ],
    jobs: [
      FreightJob(
        id: 'job-ida-marina',
        customerId: 'demo-customer-primavera',
        customerName: 'Marina Costa',
        tripId: 'trip-curitiba',
        direction: FreightDirection.outbound,
        description: 'Duas caixas de peças',
        pickup: 'Apiaí, centro',
        dropoff: 'Curitiba, CIC',
        plannedOn: '2026-10-28',
        priceCents: 12000,
        status: FreightStatus.scheduled,
        sortOrder: 0,
      ),
      FreightJob(
        id: 'job-volta-ricardo',
        customerId: 'demo-customer-mercado',
        customerName: 'Ricardo Alves',
        tripId: 'trip-curitiba',
        direction: FreightDirection.inbound,
        description: 'Encomenda na volta',
        pickup: 'Curitiba, Ceasa',
        dropoff: 'Apiaí, centro',
        plannedOn: '2026-10-29',
        dueOn: '2026-11-05',
        priceCents: 18000,
        status: FreightStatus.scheduled,
        sortOrder: 1,
      ),
      FreightJob(
        id: 'job-volta-beatriz',
        customerId: 'demo-customer-padaria',
        customerName: 'Beatriz Nunes',
        tripId: 'trip-curitiba',
        direction: FreightDirection.inbound,
        description: 'Uma caixa',
        pickup: 'Curitiba, centro',
        dropoff: 'Apiaí, Batel',
        plannedOn: '2026-10-29',
        priceCents: 10000,
        status: FreightStatus.scheduled,
        sortOrder: 2,
      ),
    ],
    receipts: [
      FreightReceipt(
        id: 'receipt-marina',
        jobId: 'job-ida-marina',
        amountCents: 12000,
        paidOn: '2026-10-18',
        method: FreightPayMethod.pix,
      ),
      FreightReceipt(
        id: 'receipt-ricardo',
        jobId: 'job-volta-ricardo',
        amountCents: 8000,
        paidOn: '2026-10-18',
        method: FreightPayMethod.cash,
      ),
    ],
    expenses: [
      FreightExpense(
        id: 'expense-estacionamento',
        tripId: 'trip-curitiba',
        description: 'Estacionamento para retirar encomenda',
        amountCents: 5000,
        paidOn: '2026-10-28',
      ),
    ],
  );
}

FreightUpdate _saveTrip(FreightLedger ledger, SaveFreightTrip change) {
  final name = change.name.trim();
  if (name.isEmpty) {
    return const FreightUpdate(error: 'Informe o nome da viagem.');
  }
  if (change.departOn.isEmpty || change.returnOn.isEmpty) {
    return const FreightUpdate(error: 'Informe as datas de ida e volta.');
  }
  if (change.returnOn.compareTo(change.departOn) < 0) {
    return const FreightUpdate(error: 'A volta não pode ser antes da ida.');
  }
  final existing = ledger.trips.where((trip) => trip.id == change.id);
  if (change.id != null && existing.isEmpty) {
    return const FreightUpdate(error: 'Viagem não encontrada.');
  }
  final trip = FreightTrip(
    id: change.id ?? 'trip-${ledger.nextNumber}',
    name: name,
    origin: change.origin.trim().isEmpty ? 'Apiaí' : change.origin.trim(),
    destination: change.destination.trim().isEmpty
        ? 'Curitiba'
        : change.destination.trim(),
    departOn: change.departOn,
    returnOn: change.returnOn,
    status: existing.isEmpty
        ? FreightTripStatus.planned
        : existing.first.status,
    spaceNote: change.spaceNote ?? existing.firstOrNull?.spaceNote,
  );
  final trips = [
    for (final current in ledger.trips)
      if (current.id != trip.id) current,
    trip,
  ];
  return FreightUpdate(
    ledger: FreightLedger(
      trips: trips,
      jobs: ledger.jobs,
      receipts: ledger.receipts,
      expenses: ledger.expenses,
      nextNumber: change.id == null ? ledger.nextNumber + 1 : ledger.nextNumber,
    ),
  );
}

FreightUpdate _saveJob(FreightLedger ledger, SaveFreightJob change, String at) {
  if (change.customerId.trim().isEmpty || change.customerName.trim().isEmpty) {
    return const FreightUpdate(error: 'Escolha o cliente.');
  }
  final current = ledger.jobs.where((job) => job.id == change.id).firstOrNull;
  if (change.id != null && current == null) {
    return const FreightUpdate(error: 'Frete não encontrado.');
  }
  if (current?.status == FreightStatus.cancelled) {
    return const FreightUpdate(error: 'Frete cancelado não pode ser alterado.');
  }
  if (!change.draft) {
    if (change.description.trim().isEmpty) {
      return const FreightUpdate(error: 'Informe a descrição da carga.');
    }
    if (change.pickup.trim().isEmpty || change.dropoff.trim().isEmpty) {
      return const FreightUpdate(error: 'Informe a retirada e a entrega.');
    }
    if (change.plannedOn.isEmpty) {
      return const FreightUpdate(error: 'Informe a data prevista.');
    }
    if (change.direction == FreightDirection.local) {
      if (change.tripId != null) {
        return const FreightUpdate(error: 'Frete local não usa viagem.');
      }
    } else if (change.tripId == null ||
        ledger.trips.every((trip) => trip.id != change.tripId)) {
      return const FreightUpdate(error: 'Escolha a viagem da ida ou da volta.');
    }
    if (change.priceCents < 0) {
      return const FreightUpdate(error: 'Informe o valor do frete.');
    }
    if (change.priceCents == 0 && !change.allowZero) {
      return const FreightUpdate(error: 'Confirme o frete com valor zero.');
    }
  }
  final received = current == null ? 0 : netReceivedCents(ledger, current.id);
  if (change.priceCents < received) {
    return const FreightUpdate(
      error: 'O valor não pode ficar abaixo do que já foi recebido.',
    );
  }
  final status = change.draft
      ? FreightStatus.draft
      : (current == null || current.status == FreightStatus.draft
            ? FreightStatus.scheduled
            : current.status);
  final order = current?.sortOrder ?? ledger.jobs.length;
  final job = FreightJob(
    id: current?.id ?? 'freight-${ledger.nextNumber}',
    customerId: change.customerId.trim(),
    customerName: change.customerName.trim(),
    tripId: change.direction == FreightDirection.local ? null : change.tripId,
    direction: change.direction,
    description: change.description.trim(),
    quantity: _blank(change.quantity),
    unit: _blank(change.unit),
    pickup: change.pickup.trim(),
    dropoff: change.dropoff.trim(),
    pickupContact: _blank(change.pickupContact),
    dropoffContact: _blank(change.dropoffContact),
    plannedOn: change.plannedOn,
    priceCents: change.priceCents,
    dueOn: _blank(change.dueOn),
    notes: _blank(change.notes),
    status: status,
    sortOrder: order,
    marks: [
      ...?current?.marks,
      if (current == null || current.status != status)
        FreightMark(action: status.name, at: at),
    ],
  );
  return FreightUpdate(
    ledger: FreightLedger(
      trips: ledger.trips,
      jobs: [
        for (final item in ledger.jobs)
          if (item.id != job.id) item,
        job,
      ],
      receipts: ledger.receipts,
      expenses: ledger.expenses,
      nextNumber: current == null ? ledger.nextNumber + 1 : ledger.nextNumber,
    ),
  );
}

FreightUpdate _collect(FreightLedger ledger, CollectFreight change, String at) {
  final job = _job(ledger, change.jobId);
  if (job == null) return const FreightUpdate(error: 'Frete não encontrado.');
  if (job.status != FreightStatus.scheduled) {
    return const FreightUpdate(
      error: 'Só um frete agendado pode ser coletado.',
    );
  }
  return FreightUpdate(
    ledger: _replaceJob(ledger, _withStatus(job, FreightStatus.collected, at)),
  );
}

FreightUpdate _deliver(FreightLedger ledger, DeliverFreight change, String at) {
  final job = _job(ledger, change.jobId);
  if (job == null) return const FreightUpdate(error: 'Frete não encontrado.');
  if (job.status != FreightStatus.collected) {
    return const FreightUpdate(error: 'Colete a encomenda antes de entregar.');
  }
  return FreightUpdate(
    ledger: _replaceJob(ledger, _withStatus(job, FreightStatus.delivered, at)),
  );
}

FreightUpdate _cancel(FreightLedger ledger, CancelFreight change, String at) {
  final job = _job(ledger, change.jobId);
  if (job == null) return const FreightUpdate(error: 'Frete não encontrado.');
  if (change.reason.trim().isEmpty) {
    return const FreightUpdate(error: 'Informe o motivo do cancelamento.');
  }
  if (job.status == FreightStatus.collected &&
      (change.cargoNote == null || change.cargoNote!.trim().isEmpty)) {
    return const FreightUpdate(
      error: 'Informe o destino da carga antes de cancelar.',
    );
  }
  if (netReceivedCents(ledger, job.id) > 0) {
    return const FreightUpdate(
      error: 'Estorne o recebimento antes de cancelar o frete.',
    );
  }
  return FreightUpdate(
    ledger: _replaceJob(
      ledger,
      FreightJob(
        id: job.id,
        customerId: job.customerId,
        customerName: job.customerName,
        tripId: job.tripId,
        direction: job.direction,
        description: job.description,
        quantity: job.quantity,
        unit: job.unit,
        pickup: job.pickup,
        dropoff: job.dropoff,
        pickupContact: job.pickupContact,
        dropoffContact: job.dropoffContact,
        plannedOn: job.plannedOn,
        priceCents: job.priceCents,
        dueOn: job.dueOn,
        notes: job.notes,
        status: FreightStatus.cancelled,
        sortOrder: job.sortOrder,
        cancelReason: change.reason.trim(),
        marks: [
          ...job.marks,
          FreightMark(
            action: FreightStatus.cancelled.name,
            at: at,
            note: change.cargoNote?.trim(),
          ),
        ],
      ),
    ),
  );
}

FreightUpdate _receipt(FreightLedger ledger, SaveFreightReceipt change) {
  if (ledger.receipts.any((receipt) => receipt.id == change.id)) {
    return FreightUpdate(ledger: ledger);
  }
  final job = _job(ledger, change.jobId);
  if (job == null) return const FreightUpdate(error: 'Frete não encontrado.');
  if (!freightConfirmed(job)) {
    return const FreightUpdate(error: 'Confirme o frete antes de receber.');
  }
  if (change.amountCents <= 0) {
    return const FreightUpdate(error: 'Informe o valor recebido.');
  }
  final balance = freightBalanceCents(ledger, job);
  if (change.amountCents > balance) {
    return const FreightUpdate(
      error: 'O recebimento não pode ser maior que o saldo.',
    );
  }
  return FreightUpdate(
    ledger: FreightLedger(
      trips: ledger.trips,
      jobs: ledger.jobs,
      receipts: [
        ...ledger.receipts,
        FreightReceipt(
          id: change.id,
          jobId: change.jobId,
          amountCents: change.amountCents,
          paidOn: change.paidOn,
          method: change.method,
          note: _blank(change.note),
        ),
      ],
      expenses: ledger.expenses,
      nextNumber: ledger.nextNumber,
    ),
  );
}

FreightUpdate _voidReceipt(FreightLedger ledger, VoidFreightReceipt change) {
  final index = ledger.receipts.indexWhere(
    (receipt) => receipt.id == change.receiptId,
  );
  if (index < 0) {
    return const FreightUpdate(error: 'Recebimento não encontrado.');
  }
  final current = ledger.receipts[index];
  final receipts = [
    for (final receipt in ledger.receipts)
      if (receipt.id == current.id)
        FreightReceipt(
          id: receipt.id,
          jobId: receipt.jobId,
          amountCents: receipt.amountCents,
          paidOn: receipt.paidOn,
          method: receipt.method,
          note: receipt.note,
          voided: true,
        )
      else
        receipt,
  ];
  return FreightUpdate(
    ledger: FreightLedger(
      trips: ledger.trips,
      jobs: ledger.jobs,
      receipts: receipts,
      expenses: ledger.expenses,
      nextNumber: ledger.nextNumber,
    ),
  );
}

FreightUpdate _expense(FreightLedger ledger, SaveFreightExpense change) {
  if (change.description.trim().isEmpty) {
    return const FreightUpdate(error: 'Informe a descrição do gasto.');
  }
  if (change.amountCents <= 0) {
    return const FreightUpdate(error: 'Informe o valor do gasto.');
  }
  final hasTrip = change.tripId != null;
  final hasJob = change.jobId != null;
  if (hasTrip == hasJob) {
    return const FreightUpdate(
      error: 'Vincule o gasto à viagem ou a um frete.',
    );
  }
  return FreightUpdate(
    ledger: FreightLedger(
      trips: ledger.trips,
      jobs: ledger.jobs,
      receipts: ledger.receipts,
      expenses: [
        ...ledger.expenses,
        FreightExpense(
          id: 'expense-${ledger.nextNumber}',
          tripId: change.tripId,
          jobId: change.jobId,
          description: change.description.trim(),
          amountCents: change.amountCents,
          paidOn: change.paidOn,
          paid: change.paid,
        ),
      ],
      nextNumber: ledger.nextNumber + 1,
    ),
  );
}

FreightUpdate _completeTrip(FreightLedger ledger, CompleteFreightTrip change) {
  final trip = ledger.trips
      .where((item) => item.id == change.tripId)
      .firstOrNull;
  if (trip == null) return const FreightUpdate(error: 'Viagem não encontrada.');
  final pending = ledger.jobs.where((job) {
    return job.tripId == trip.id &&
        job.status != FreightStatus.delivered &&
        job.status != FreightStatus.cancelled;
  });
  if (pending.isNotEmpty) {
    return const FreightUpdate(
      error: 'Resolva os fretes pendentes antes de concluir a viagem.',
    );
  }
  return FreightUpdate(
    ledger: _replaceTrip(ledger, trip, FreightTripStatus.completed),
  );
}

FreightUpdate _startTrip(FreightLedger ledger, StartFreightTrip change) {
  final trip = ledger.trips
      .where((item) => item.id == change.tripId)
      .firstOrNull;
  if (trip == null) return const FreightUpdate(error: 'Viagem não encontrada.');
  if (trip.status != FreightTripStatus.planned) {
    return const FreightUpdate(error: 'Esta viagem já foi iniciada.');
  }
  return FreightUpdate(
    ledger: _replaceTrip(ledger, trip, FreightTripStatus.underway),
  );
}

FreightJob? _job(FreightLedger ledger, String id) {
  return ledger.jobs.where((job) => job.id == id).firstOrNull;
}

FreightJob _withStatus(FreightJob job, FreightStatus status, String at) {
  return FreightJob(
    id: job.id,
    customerId: job.customerId,
    customerName: job.customerName,
    tripId: job.tripId,
    direction: job.direction,
    description: job.description,
    quantity: job.quantity,
    unit: job.unit,
    pickup: job.pickup,
    dropoff: job.dropoff,
    pickupContact: job.pickupContact,
    dropoffContact: job.dropoffContact,
    plannedOn: job.plannedOn,
    priceCents: job.priceCents,
    dueOn: job.dueOn,
    notes: job.notes,
    status: status,
    sortOrder: job.sortOrder,
    cancelReason: job.cancelReason,
    marks: [
      ...job.marks,
      FreightMark(action: status.name, at: at),
    ],
  );
}

FreightLedger _replaceJob(FreightLedger ledger, FreightJob job) {
  return FreightLedger(
    trips: ledger.trips,
    jobs: [
      for (final current in ledger.jobs)
        if (current.id == job.id) job else current,
    ],
    receipts: ledger.receipts,
    expenses: ledger.expenses,
    nextNumber: ledger.nextNumber,
  );
}

FreightLedger _replaceTrip(
  FreightLedger ledger,
  FreightTrip trip,
  FreightTripStatus status,
) {
  final updated = FreightTrip(
    id: trip.id,
    name: trip.name,
    origin: trip.origin,
    destination: trip.destination,
    departOn: trip.departOn,
    returnOn: trip.returnOn,
    status: status,
    spaceNote: trip.spaceNote,
  );
  return FreightLedger(
    trips: [
      for (final current in ledger.trips)
        if (current.id == updated.id) updated else current,
    ],
    jobs: ledger.jobs,
    receipts: ledger.receipts,
    expenses: ledger.expenses,
    nextNumber: ledger.nextNumber,
  );
}

String? _blank(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}
