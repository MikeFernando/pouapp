import '../entities/catalog.dart';
import '../entities/stock_operation.dart';

const stockLocations = <StockLocation>[
  StockLocation(code: StockLocationCode.transit, name: 'Em transporte'),
  StockLocation(code: StockLocationCode.warehouse, name: 'Depósito'),
  StockLocation(code: StockLocationCode.montana, name: 'Montana'),
];

String locationName(StockLocationCode code) {
  return stockLocations.firstWhere((location) => location.code == code).name;
}

Map<StockLocationCode, int> balancesFor(Iterable<StockMovement> movements) {
  final totals = {for (final location in StockLocationCode.values) location: 0};
  for (final movement in movements) {
    totals[movement.location] = totals[movement.location]! + movement.quantity;
  }
  return totals;
}

/// Below the configured minimum. Equal to the minimum is not low.
bool isLowStock(CatalogProduct product, Map<StockLocationCode, int> balances) {
  if (!product.active) return false;
  for (final entry in product.minimums.entries) {
    final onHand = balances[entry.key] ?? 0;
    if (onHand < entry.value) return true;
  }
  return false;
}

bool wouldGoNegative(int current, int delta) => current + delta < 0;

/// Weight in, packages, leftover and loss must describe the same grams.
bool weightConserved({
  required int consumed,
  required int packaged,
  required int returned,
  required int lost,
}) {
  return consumed == packaged + returned + lost;
}

/// One package consumes its real base quantity. A 500 g pack is 500 g.
///
/// Returns null when the presentation unit cannot be applied to the product.
int? baseConsumed({
  required CatalogUnit productUnit,
  required CatalogUnit presentationUnit,
  required int quantityInBase,
  required int packageCount,
}) {
  if (productUnit != presentationUnit) return null;
  if (quantityInBase <= 0 || packageCount < 0) return null;
  return quantityInBase * packageCount;
}

(StockLocationCode, StockLocationCode) transferEnds(StockOperationKind kind) {
  return switch (kind) {
    StockOperationKind.load => (
      StockLocationCode.warehouse,
      StockLocationCode.montana,
    ),
    StockOperationKind.returnToWarehouse => (
      StockLocationCode.montana,
      StockLocationCode.warehouse,
    ),
    StockOperationKind.loss || StockOperationKind.count => throw ArgumentError(
      'Perda e conferência não são transferência.',
    ),
  };
}

String movementKindLabel(MovementKind kind) {
  return switch (kind) {
    MovementKind.opening => 'Saldo inicial',
    MovementKind.transferOut => 'Saída',
    MovementKind.transferIn => 'Entrada',
    MovementKind.loss => 'Perda',
    MovementKind.adjustment => 'Ajuste de contagem',
    MovementKind.sale => 'Venda',
  };
}

String stockOperationTitle(StockOperationKind kind) {
  return switch (kind) {
    StockOperationKind.load => 'Carregar Montana',
    StockOperationKind.returnToWarehouse => 'Retornar ao depósito',
    StockOperationKind.loss => 'Registrar perda',
    StockOperationKind.count => 'Conferir estoque',
  };
}

String? stockOperationProblem({
  required StockOperationKind kind,
  StockLocationCode? location,
  String? reason,
}) {
  if (kind == StockOperationKind.load ||
      kind == StockOperationKind.returnToWarehouse) {
    final ends = transferEnds(kind);
    if (ends.$1 == ends.$2) {
      return 'Origem e destino precisam ser diferentes.';
    }
    return null;
  }
  if (location == null) return 'Informe o local.';
  if (reason == null || reason.trim().isEmpty) return 'Informe o motivo.';
  return null;
}

String? stockLineProblem({
  required StockOperationKind kind,
  required String productName,
  required bool active,
  required CatalogUnit unit,
  required int quantity,
  required int available,
  required bool duplicate,
  required String place,
}) {
  if (duplicate) return '$productName está repetido nesta movimentação.';
  if (!active) return '$productName está inativo.';
  if (kind == StockOperationKind.count) {
    if (quantity < 0) return 'A quantidade contada não pode ser negativa.';
    return null;
  }
  if (quantity <= 0) return 'Informe uma quantidade maior que zero.';
  if (available < quantity) {
    return '$productName: em $place há ${formatBaseQuantity(unit, available)}.';
  }
  return null;
}

String editBaseQuantity(CatalogUnit unit, int quantity) {
  if (unit != CatalogUnit.kilogram) return '$quantity';
  final negative = quantity < 0;
  final grams = quantity.abs();
  final whole = grams ~/ 1000;
  final rest = grams % 1000;
  if (rest == 0) return '${negative ? '-' : ''}$whole';
  final fraction = rest
      .toString()
      .padLeft(3, '0')
      .replaceAll(RegExp(r'0+$'), '');
  return '${negative ? '-' : ''}$whole,$fraction';
}

StockRuleViolation? openingViolation({
  required bool active,
  required int quantity,
  required bool openingAlreadyRecorded,
  int? minimum,
}) {
  if (!active) return StockRuleViolation.productInactive;
  if (quantity < 0 || (minimum != null && minimum < 0)) {
    return StockRuleViolation.negativeQuantity;
  }
  if (openingAlreadyRecorded) return StockRuleViolation.duplicateOpening;
  return null;
}

/// Reais typed by the user become integer cents. Empty means zero.
int? parseReaisToCents(String raw) {
  var text = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (text.isEmpty) return 0;
  if (text.startsWith('-')) return null;
  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  }
  final parts = text.split('.');
  if (parts.length > 2) return null;
  final wholeText = parts.first.isEmpty ? '0' : parts.first;
  final whole = int.tryParse(wholeText);
  if (whole == null) return null;
  if (parts.length == 1) return whole * 100;
  final fraction = parts[1];
  if (fraction.isEmpty ||
      fraction.length > 2 ||
      int.tryParse(fraction) == null) {
    return null;
  }
  final cents = int.parse(fraction.padRight(2, '0'));
  return whole * 100 + cents;
}

/// Kilograms typed by the user become integer grams.
int? parseKilogramsToGrams(String raw) {
  var text = raw.trim().replaceAll(' ', '');
  if (text.isEmpty) return 0;
  if (text.startsWith('-')) return null;
  text = text.replaceAll(',', '.');
  final parts = text.split('.');
  if (parts.length > 2) return null;
  final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first);
  if (whole == null) return null;
  if (parts.length == 1) return whole * 1000;
  final fraction = parts[1];
  if (fraction.isEmpty || int.tryParse(fraction) == null) return null;
  if (fraction.length <= 3) {
    return whole * 1000 + int.parse(fraction.padRight(3, '0'));
  }
  final head = int.parse(fraction.substring(0, 3));
  final roundUp = int.parse(fraction[3]) >= 5;
  final grams = head + (roundUp ? 1 : 0);
  return whole * 1000 + grams;
}

int? parseBaseQuantity(CatalogUnit unit, String raw) {
  if (unit == CatalogUnit.kilogram) return parseKilogramsToGrams(raw);
  final text = raw.trim();
  if (text.isEmpty) return 0;
  if (text.contains(',') || text.contains('.') || text.startsWith('-')) {
    return null;
  }
  return int.tryParse(text);
}

String formatBaseQuantity(CatalogUnit unit, int quantity) {
  final label = switch (unit) {
    CatalogUnit.kilogram => 'kg',
    CatalogUnit.piece => 'un',
    CatalogUnit.bunch => 'maço',
    CatalogUnit.box => 'cx',
    CatalogUnit.dozen => quantity.abs() == 1 ? 'dúzia' : 'dúzias',
  };
  if (unit != CatalogUnit.kilogram) return '$quantity $label';
  final negative = quantity < 0;
  final grams = quantity.abs();
  final whole = grams ~/ 1000;
  final rest = grams % 1000;
  if (rest == 0) return '${negative ? '-' : ''}$whole $label';
  final fraction = rest
      .toString()
      .padLeft(3, '0')
      .replaceAll(RegExp(r'0+$'), '');
  return '${negative ? '-' : ''}$whole,$fraction $label';
}

String formatReais(int cents) {
  final negative = cents < 0;
  final value = cents.abs();
  final whole = value ~/ 100;
  final fraction = (value % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    if (index > 0 && remaining % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}R\$ $buffer,$fraction';
}
