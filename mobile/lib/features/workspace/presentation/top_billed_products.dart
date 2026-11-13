import '../domain/entities/street_ledger.dart';

class TopBilledProduct {
  const TopBilledProduct({required this.name, required this.cents});

  final String name;
  final int cents;
}

/// Top products billed this calendar month, same set the finance chart uses.
List<TopBilledProduct> topBilledProducts({
  required List<SaleOrder> orders,
  Map<String, int> checklistProductCents = const {},
  DateTime? now,
  int limit = 10,
}) {
  final today = now ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  final totals = <String, int>{};

  for (final order in orders) {
    if (!order.recorded || order.fromSeed) continue;
    final occurredOn = order.occurredOn;
    if (occurredOn == null || occurredOn.isEmpty) continue;
    final date = _day(occurredOn);
    if (date == null || date.isAfter(day)) continue;
    if (date.year != day.year || date.month != day.month) continue;
    for (final line in order.lines) {
      final name = line.productName.trim();
      if (name.isEmpty || line.totalCents <= 0) continue;
      totals[name] = (totals[name] ?? 0) + line.totalCents;
    }
  }

  for (final entry in checklistProductCents.entries) {
    final name = entry.key.trim();
    if (name.isEmpty || entry.value <= 0) continue;
    totals[name] = (totals[name] ?? 0) + entry.value;
  }

  final ranked = totals.entries.toList()
    ..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      return byValue != 0 ? byValue : a.key.compareTo(b.key);
    });
  return [
    for (final row in ranked.take(limit))
      TopBilledProduct(name: row.key, cents: row.value),
  ];
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
