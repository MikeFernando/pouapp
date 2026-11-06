import 'dart:convert';

import '../../domain/entities/freight_ledger.dart';

String encodeFreightLedger(FreightLedger ledger) {
  return jsonEncode({
    'nextNumber': ledger.nextNumber,
    'trips': ledger.trips.map(_trip).toList(),
    'jobs': ledger.jobs.map(_job).toList(),
    'receipts': ledger.receipts.map(_receipt).toList(),
    'expenses': ledger.expenses.map(_expense).toList(),
  });
}

FreightLedger decodeFreightLedger(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  return FreightLedger(
    nextNumber: map['nextNumber'] as int? ?? 1,
    trips: [
      for (final item in map['trips'] as List<dynamic>? ?? const [])
        _readTrip(item as Map<String, dynamic>),
    ],
    jobs: [
      for (final item in map['jobs'] as List<dynamic>? ?? const [])
        _readJob(item as Map<String, dynamic>),
    ],
    receipts: [
      for (final item in map['receipts'] as List<dynamic>? ?? const [])
        _readReceipt(item as Map<String, dynamic>),
    ],
    expenses: [
      for (final item in map['expenses'] as List<dynamic>? ?? const [])
        _readExpense(item as Map<String, dynamic>),
    ],
  );
}

Map<String, dynamic> _trip(FreightTrip trip) {
  return {
    'id': trip.id,
    'name': trip.name,
    'origin': trip.origin,
    'destination': trip.destination,
    'departOn': trip.departOn,
    'returnOn': trip.returnOn,
    'status': trip.status.name,
    'spaceNote': trip.spaceNote,
  };
}

Map<String, dynamic> _job(FreightJob job) {
  return {
    'id': job.id,
    'customerId': job.customerId,
    'customerName': job.customerName,
    'tripId': job.tripId,
    'direction': job.direction.name,
    'description': job.description,
    'quantity': job.quantity,
    'unit': job.unit,
    'pickup': job.pickup,
    'dropoff': job.dropoff,
    'pickupContact': job.pickupContact,
    'dropoffContact': job.dropoffContact,
    'plannedOn': job.plannedOn,
    'priceCents': job.priceCents,
    'dueOn': job.dueOn,
    'notes': job.notes,
    'status': job.status.name,
    'sortOrder': job.sortOrder,
    'cancelReason': job.cancelReason,
    'marks': [
      for (final mark in job.marks)
        {'action': mark.action, 'at': mark.at, 'note': mark.note},
    ],
  };
}

Map<String, dynamic> _receipt(FreightReceipt receipt) {
  return {
    'id': receipt.id,
    'jobId': receipt.jobId,
    'amountCents': receipt.amountCents,
    'paidOn': receipt.paidOn,
    'method': receipt.method.name,
    'note': receipt.note,
    'voided': receipt.voided,
  };
}

Map<String, dynamic> _expense(FreightExpense expense) {
  return {
    'id': expense.id,
    'tripId': expense.tripId,
    'jobId': expense.jobId,
    'description': expense.description,
    'amountCents': expense.amountCents,
    'paidOn': expense.paidOn,
    'paid': expense.paid,
  };
}

FreightTrip _readTrip(Map<String, dynamic> map) {
  return FreightTrip(
    id: map['id'] as String,
    name: map['name'] as String,
    origin: map['origin'] as String? ?? 'Apiaí',
    destination: map['destination'] as String? ?? 'Curitiba',
    departOn: map['departOn'] as String,
    returnOn: map['returnOn'] as String,
    status: FreightTripStatus.values.byName(map['status'] as String),
    spaceNote: map['spaceNote'] as String?,
  );
}

FreightJob _readJob(Map<String, dynamic> map) {
  return FreightJob(
    id: map['id'] as String,
    customerId: map['customerId'] as String,
    customerName: map['customerName'] as String,
    tripId: map['tripId'] as String?,
    direction: FreightDirection.values.byName(map['direction'] as String),
    description: map['description'] as String? ?? '',
    quantity: map['quantity'] as String?,
    unit: map['unit'] as String?,
    pickup: map['pickup'] as String? ?? '',
    dropoff: map['dropoff'] as String? ?? '',
    pickupContact: map['pickupContact'] as String?,
    dropoffContact: map['dropoffContact'] as String?,
    plannedOn: map['plannedOn'] as String? ?? '',
    priceCents: map['priceCents'] as int? ?? 0,
    dueOn: map['dueOn'] as String?,
    notes: map['notes'] as String?,
    status: FreightStatus.values.byName(map['status'] as String),
    sortOrder: map['sortOrder'] as int? ?? 0,
    cancelReason: map['cancelReason'] as String?,
    marks: [
      for (final item in map['marks'] as List<dynamic>? ?? const [])
        FreightMark(
          action: (item as Map<String, dynamic>)['action'] as String,
          at: item['at'] as String,
          note: item['note'] as String?,
        ),
    ],
  );
}

FreightReceipt _readReceipt(Map<String, dynamic> map) {
  return FreightReceipt(
    id: map['id'] as String,
    jobId: map['jobId'] as String,
    amountCents: map['amountCents'] as int,
    paidOn: map['paidOn'] as String,
    method: FreightPayMethod.values.byName(map['method'] as String),
    note: map['note'] as String?,
    voided: map['voided'] as bool? ?? false,
  );
}

FreightExpense _readExpense(Map<String, dynamic> map) {
  return FreightExpense(
    id: map['id'] as String,
    tripId: map['tripId'] as String?,
    jobId: map['jobId'] as String?,
    description: map['description'] as String,
    amountCents: map['amountCents'] as int,
    paidOn: map['paidOn'] as String,
    paid: map['paid'] as bool? ?? true,
  );
}
