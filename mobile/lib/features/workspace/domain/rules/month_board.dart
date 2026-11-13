import '../entities/posted_sale.dart';
import '../entities/street_ledger.dart';

const monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String monthTitle(DateTime month) =>
    '${monthNames[month.month - 1]} ${month.year}';

/// Recorded street sales that belong to the company figures.
///
/// Demonstration orders and sales without a day stay out. The total is the
/// current lines, so a later adjustment replaces the previous amount. A
/// payment counts only through its shares.
List<PostedSale> confirmedStreetSales(StreetLedger ledger) {
  return [
    for (final order in ledger.orders)
      if (order.recorded &&
          !order.fromSeed &&
          order.occurredOn != null &&
          order.occurredOn!.isNotEmpty)
        PostedSale(
          id: order.id,
          customerId: order.customerId,
          customerName: order.customerName,
          totalCents: order.totalCents,
          allocatedCents: allocatedToOrder(ledger, order.id),
          occurredOn: order.occurredOn!,
          sale: true,
        ),
  ];
}

class MonthSnapshot {
  const MonthSnapshot({
    required this.billedCents,
    required this.receivedCents,
    required this.openCents,
    required this.receivedPercent,
    required this.salesByDay,
    required this.chartDays,
  });

  final int billedCents;
  final int receivedCents;
  final int openCents;

  /// Zero when there is no billing, so the bar never divides by zero.
  final int receivedPercent;
  final Map<int, int> salesByDay;

  /// Last day to draw. Zero when the month is still in the future.
  final int chartDays;

  bool get empty => billedCents == 0;
}

/// Billed total for the calendar month of [today], versus the previous month.
class MonthBilledDelta {
  const MonthBilledDelta({
    required this.billedCents,
    required this.deltaCents,
    required this.deltaPercent,
    required this.hasPercent,
  });

  final int billedCents;
  final int deltaCents;

  /// Rounded percent change versus the previous month. Zero when [hasPercent]
  /// is false.
  final double deltaPercent;

  /// False when the previous month had no billing, so a percent would mislead.
  final bool hasPercent;
}

/// Confirmed sales billed this month, with the change from last month.
MonthBilledDelta monthBilledDelta({
  required Iterable<PostedSale> sales,
  required DateTime today,
}) {
  final currentMonth = DateTime(today.year, today.month);
  final previousMonth = DateTime(today.year, today.month - 1);
  final current = monthSnapshot(
    sales: sales,
    month: currentMonth,
    today: today,
  );
  final previous = monthSnapshot(
    sales: sales,
    month: previousMonth,
    today: today,
  );
  final delta = current.billedCents - previous.billedCents;
  if (previous.billedCents <= 0) {
    return MonthBilledDelta(
      billedCents: current.billedCents,
      deltaCents: delta,
      deltaPercent: 0,
      hasPercent: false,
    );
  }
  final percent = (delta * 100) / previous.billedCents;
  return MonthBilledDelta(
    billedCents: current.billedCents,
    deltaCents: delta,
    deltaPercent: percent,
    hasPercent: true,
  );
}

/// Confirmed sales of [month] that have already happened by [today].
///
/// Received money is the part allocated to those sales. A receipt of another
/// month's sale, and credit that was not allocated, do not enter [receivedCents].
MonthSnapshot monthSnapshot({
  required Iterable<PostedSale> sales,
  required DateTime month,
  required DateTime today,
}) {
  final limit = DateTime(today.year, today.month, today.day);
  final byDay = <int, int>{};
  var billed = 0;
  var received = 0;
  var open = 0;
  for (final sale in sales) {
    if (!sale.sale || sale.totalCents <= 0) continue;
    final date = _day(sale.occurredOn);
    if (date == null) continue;
    if (date.year != month.year || date.month != month.month) continue;
    if (date.isAfter(limit)) continue;
    final applied = _applied(sale);
    billed += sale.totalCents;
    received += applied;
    open += sale.totalCents - applied;
    byDay[date.day] = (byDay[date.day] ?? 0) + sale.totalCents;
  }
  var percent = 0;
  if (billed > 0) {
    percent = ((received * 100) / billed).round();
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;
  }
  return MonthSnapshot(
    billedCents: billed,
    receivedCents: received,
    openCents: open,
    receivedPercent: percent,
    salesByDay: byDay,
    chartDays: _chartDays(month, limit),
  );
}

class DueTodayCustomer {
  const DueTodayCustomer({
    required this.customerId,
    required this.customerName,
    required this.dueCents,
    required this.balanceCents,
    required this.purchaseCount,
  });

  final String customerId;
  final String customerName;

  /// Open amount whose due date is today.
  final int dueCents;

  /// Open amount of every sale and balance of this customer.
  final int balanceCents;
  final int purchaseCount;
}

/// Pending amounts due on [today], grouped by customer.
///
/// The selected dashboard month does not filter this list.
List<DueTodayCustomer> duesToday({
  required Iterable<PostedSale> sales,
  required DateTime today,
}) {
  final day = isoDate(DateTime(today.year, today.month, today.day));
  final grouped = <String, List<PostedSale>>{};
  for (final sale in sales) {
    grouped.putIfAbsent(sale.customerId, () => []).add(sale);
  }
  final result = <DueTodayCustomer>[];
  for (final entry in grouped.entries) {
    final due = [
      for (final sale in entry.value)
        if (sale.dueOn == day && sale.openCents > 0) sale,
    ];
    if (due.isEmpty) continue;
    final name = entry.value
        .map((sale) => sale.customerName.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'Cliente');
    result.add(
      DueTodayCustomer(
        customerId: entry.key,
        customerName: name,
        dueCents: due.fold(0, (sum, sale) => sum + sale.openCents),
        balanceCents: entry.value.fold(0, (sum, sale) => sum + sale.openCents),
        purchaseCount: due.where((sale) => sale.sale).length,
      ),
    );
  }
  result.sort((a, b) => a.customerName.compareTo(b.customerName));
  return result;
}

class UpcomingDueCustomer {
  const UpcomingDueCustomer({
    required this.customerId,
    required this.customerName,
    required this.dueOn,
    required this.amountCents,
  });

  final String customerId;
  final String customerName;

  /// Calendar day the note or open balance is due, `yyyy-MM-dd`.
  final String dueOn;
  final int amountCents;
}

class DayReceiptCustomer {
  const DayReceiptCustomer({
    required this.customerId,
    required this.customerName,
    required this.amountCents,
    required this.done,
  });

  final String customerId;
  final String customerName;

  /// Open amount still due today, or the settled amount when [done].
  final int amountCents;
  final bool done;
}

/// Home checklist marks that also feed Financeiro (valor + produtos).
class DayChecklistSnapshot {
  const DayChecklistSnapshot({
    required this.receivedCents,
    required this.productCents,
  });

  static const empty = DayChecklistSnapshot(
    receivedCents: 0,
    productCents: {},
  );

  final int receivedCents;

  /// Product display name → cents from notes marked as received today.
  final Map<String, int> productCents;
}

/// Frozen contribution captured when the user marks a day receipt as done.
///
/// Survives note deletion so Financeiro / Recebido hoje do not shrink.
class DayChecklistFrozen {
  const DayChecklistFrozen({
    required this.receivedCents,
    required this.productCents,
  });

  final int receivedCents;
  final Map<String, int> productCents;

  factory DayChecklistFrozen.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['productCents'];
    final products = <String, int>{};
    if (rawProducts is Map) {
      for (final entry in rawProducts.entries) {
        final cents = entry.value;
        if (cents is num) products[entry.key.toString()] = cents.toInt();
      }
    }
    return DayChecklistFrozen(
      receivedCents: (json['receivedCents'] as num?)?.toInt() ?? 0,
      productCents: products,
    );
  }

  Map<String, Object?> toJson() => {
    'receivedCents': receivedCents,
    'productCents': productCents,
  };
}

/// Customers whose note or open balance is due on [today].
///
/// Fully paid items for the same day stay listed as [DayReceiptCustomer.done].
List<DayReceiptCustomer> dayReceipts({
  required Iterable<PostedSale> sales,
  Iterable<UpcomingDueCustomer> notes = const [],
  required DateTime today,
}) {
  final day = isoDate(DateTime(today.year, today.month, today.day));
  final byCustomer = <String, DayReceiptCustomer>{};

  final grouped = <String, List<PostedSale>>{};
  for (final sale in sales) {
    if (sale.dueOn != day) continue;
    grouped.putIfAbsent(sale.customerId, () => []).add(sale);
  }
  for (final entry in grouped.entries) {
    final open = entry.value.fold<int>(0, (sum, sale) => sum + sale.openCents);
    final total = entry.value.fold<int>(
      0,
      (sum, sale) => sum + sale.totalCents,
    );
    final name = entry.value
        .map((sale) => sale.customerName.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'Cliente');
    final done = open <= 0;
    byCustomer[entry.key] = DayReceiptCustomer(
      customerId: entry.key,
      customerName: name,
      amountCents: done ? total : open,
      done: done,
    );
  }

  for (final note in notes) {
    if (note.dueOn != day || note.amountCents <= 0) continue;
    if (byCustomer.containsKey(note.customerId)) continue;
    byCustomer[note.customerId] = DayReceiptCustomer(
      customerId: note.customerId,
      customerName: note.customerName.trim().isEmpty
          ? 'Cliente'
          : note.customerName.trim(),
      amountCents: note.amountCents,
      done: false,
    );
  }

  final result = byCustomer.values.toList()
    ..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.customerName.compareTo(b.customerName);
    });
  return result;
}

VisitProgress dayReceiptProgress(Iterable<DayReceiptCustomer> items) {
  final total = items.length;
  final done = items.where((item) => item.done).length;
  return VisitProgress(done: done, total: total);
}

/// Open balances and note dues ordered by the nearest due date.
///
/// Overdue items stay first. Customers without a due date stay out.
List<UpcomingDueCustomer> upcomingDueCustomers({
  required Iterable<PostedSale> sales,
  Iterable<UpcomingDueCustomer> notes = const [],
  required DateTime today,
}) {
  final byCustomer = <String, UpcomingDueCustomer>{};

  void consider(UpcomingDueCustomer next) {
    if (next.amountCents <= 0 || next.dueOn.trim().isEmpty) return;
    if (_day(next.dueOn) == null) return;
    final current = byCustomer[next.customerId];
    if (current == null || next.dueOn.compareTo(current.dueOn) < 0) {
      byCustomer[next.customerId] = next;
    }
  }

  final grouped = <String, List<PostedSale>>{};
  for (final sale in sales) {
    if (sale.openCents <= 0 || sale.dueOn == null) continue;
    grouped.putIfAbsent(sale.customerId, () => []).add(sale);
  }
  for (final entry in grouped.entries) {
    final openWithDue = [
      for (final sale in entry.value)
        if (sale.dueOn != null && sale.openCents > 0) sale,
    ]..sort((a, b) => a.dueOn!.compareTo(b.dueOn!));
    if (openWithDue.isEmpty) continue;
    final earliest = openWithDue.first.dueOn!;
    final onDay = [
      for (final sale in openWithDue)
        if (sale.dueOn == earliest) sale,
    ];
    final name = entry.value
        .map((sale) => sale.customerName.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'Cliente');
    consider(
      UpcomingDueCustomer(
        customerId: entry.key,
        customerName: name,
        dueOn: earliest,
        amountCents: onDay.fold(0, (sum, sale) => sum + sale.openCents),
      ),
    );
  }

  for (final note in notes) {
    consider(note);
  }

  final result = byCustomer.values.toList()
    ..sort((a, b) {
      final byDate = a.dueOn.compareTo(b.dueOn);
      if (byDate != 0) return byDate;
      return a.customerName.compareTo(b.customerName);
    });
  return result;
}

/// Relative due label for the home board, e.g. "Vence amanhã".
String upcomingDueLabel(String dueOn, DateTime today) {
  final due = _day(dueOn);
  if (due == null) return 'Sem vencimento';
  final start = DateTime(today.year, today.month, today.day);
  final days = due.difference(start).inDays;
  if (days == 0) return 'Vence hoje';
  if (days == 1) return 'Vence amanhã';
  if (days == -1) return 'Venceu ontem';
  if (days < -1) {
    final day = due.day.toString().padLeft(2, '0');
    final month = due.month.toString().padLeft(2, '0');
    return 'Venceu $day/$month';
  }
  if (days <= 7) return 'Vence em $days dias';
  final day = due.day.toString().padLeft(2, '0');
  final month = due.month.toString().padLeft(2, '0');
  return 'Vence $day/$month';
}

int _applied(PostedSale sale) {
  final allocated = sale.allocatedCents < 0 ? 0 : sale.allocatedCents;
  return allocated > sale.totalCents ? sale.totalCents : allocated;
}

DateTime? _day(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

int _chartDays(DateTime month, DateTime today) {
  final start = DateTime(month.year, month.month);
  final current = DateTime(today.year, today.month);
  if (start.isAfter(current)) return 0;
  final last = DateTime(month.year, month.month + 1, 0).day;
  if (start == current && today.day < last) return today.day;
  return last;
}
