import '../../../catalog/domain/entities/catalog.dart';

/// Line total in cents.
///
/// Weight uses grams and the price of one kilogram. The only rounding is
/// half-up to the nearest cent: `(grams * centsPerKg + 500) ~/ 1000`.
/// Piece, bunch and box multiply the whole count by the unit price.
int lineTotalCents({
  required CatalogUnit unit,
  required int quantity,
  required int unitPriceCents,
}) {
  if (quantity < 0 || unitPriceCents < 0) {
    throw ArgumentError('Quantidade e preço não podem ser negativos.');
  }
  if (unit == CatalogUnit.kilogram) {
    return (quantity * unitPriceCents + 500) ~/ 1000;
  }
  return quantity * unitPriceCents;
}

/// Quantity shown on the note. Kilograms come from grams; other units are counts.
double displayQuantity(CatalogUnit unit, int quantity) {
  if (unit == CatalogUnit.kilogram) return quantity / 1000;
  return quantity.toDouble();
}

/// Converts the quantity chosen on the note into the stored base quantity.
///
/// A fractional piece, bunch or box is rejected. A box is never turned into
/// kilograms.
int? baseQuantityFromDisplay(CatalogUnit unit, double display) {
  if (display <= 0 || display.isNaN || display.isInfinite) return null;
  if (unit == CatalogUnit.kilogram) {
    final grams = (display * 1000).round();
    return grams > 0 ? grams : null;
  }
  if ((display - display.roundToDouble()).abs() > 0.000001) return null;
  final count = display.round();
  return count > 0 ? count : null;
}
