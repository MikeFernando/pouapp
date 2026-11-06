/// Whole sacks that describe bulk potatoes stored on a pallet.
class SackCount {
  const SackCount({required this.kilograms, required this.count});

  final int kilograms;
  final int count;
}

/// Splits a warehouse balance into 25 kg and 50 kg sacks.
///
/// Grams that do not fill a 25 kg sack stay out of the list.
List<SackCount> warehouseSacks(int grams) {
  if (grams <= 0) return const [];
  final kilograms = grams ~/ 1000;
  final sacks50 = kilograms ~/ 50;
  final sacks25 = (kilograms % 50) ~/ 25;
  return [
    if (sacks25 > 0) SackCount(kilograms: 25, count: sacks25),
    if (sacks50 > 0) SackCount(kilograms: 50, count: sacks50),
  ];
}

/// Grams that remain after the 25 kg and 50 kg sacks are counted.
int looseBulkGrams(int grams) {
  if (grams <= 0) return 0;
  final kilograms = grams ~/ 1000;
  return (kilograms % 25) * 1000 + grams % 1000;
}

String sackLabel(SackCount sack) {
  final noun = sack.count == 1 ? 'saco' : 'sacos';
  return '${sack.count} $noun de ${sack.kilograms} kg';
}
