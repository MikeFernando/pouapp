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
