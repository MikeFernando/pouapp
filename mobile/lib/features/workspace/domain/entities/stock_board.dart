import 'package:equatable/equatable.dart';

enum StockUnit { kilogram, box, piece, bunch, dozen }

enum ReceiptStatus { waiting, checking, done }

class StockSummary extends Equatable {
  const StockSummary({
    required this.pendingReceipts,
    required this.lowStockProducts,
    required this.movementsToday,
  });

  final int pendingReceipts;
  final int lowStockProducts;
  final int movementsToday;

  @override
  List<Object?> get props => [
    pendingReceipts,
    lowStockProducts,
    movementsToday,
  ];
}

class ReceiptLine extends Equatable {
  const ReceiptLine({
    required this.productName,
    required this.supplierName,
    required this.expectedQuantity,
    required this.receivedQuantity,
    required this.unit,
    this.grossWeightKg,
    this.tareWeightKg,
    this.netWeightKg,
    this.notes,
  });

  final String productName;
  final String supplierName;
  final double expectedQuantity;
  final double receivedQuantity;
  final StockUnit unit;
  final double? grossWeightKg;
  final double? tareWeightKg;
  final double? netWeightKg;
  final String? notes;

  bool get hasWeight =>
      grossWeightKg != null || tareWeightKg != null || netWeightKg != null;

  double get difference => receivedQuantity - expectedQuantity;

  @override
  List<Object?> get props => [
    productName,
    supplierName,
    expectedQuantity,
    receivedQuantity,
    unit,
    grossWeightKg,
    tareWeightKg,
    netWeightKg,
    notes,
  ];
}

class StockReceipt extends Equatable {
  const StockReceipt({
    required this.id,
    required this.supplierName,
    required this.receivedOn,
    required this.status,
    required this.lines,
  });

  final String id;
  final String supplierName;
  final DateTime receivedOn;
  final ReceiptStatus status;
  final List<ReceiptLine> lines;

  @override
  List<Object?> get props => [id, supplierName, receivedOn, status, lines];
}

class StockProduct extends Equatable {
  const StockProduct({
    required this.id,
    required this.name,
    required this.unit,
    required this.available,
    required this.low,
    this.montana = 0,
  });

  final String id;
  final String name;
  final StockUnit unit;
  final double available;

  /// Quantity currently on the Montana, in the same display unit as [available].
  final double montana;
  final bool low;

  @override
  List<Object?> get props => [id, name, unit, available, low, montana];
}

class StockBoard extends Equatable {
  const StockBoard({
    required this.summary,
    required this.receipts,
    required this.products,
  });

  final StockSummary summary;
  final List<StockReceipt> receipts;
  final List<StockProduct> products;

  @override
  List<Object?> get props => [summary, receipts, products];
}

/// Totals stay separated by unit. Kilograms are never added to boxes or pieces.
Map<StockUnit, double> receivedTotalsByUnit(List<ReceiptLine> lines) {
  final totals = <StockUnit, double>{};
  for (final line in lines) {
    totals[line.unit] = (totals[line.unit] ?? 0) + line.receivedQuantity;
  }
  return totals;
}

/// Lines whose received quantity differs from the expected one.
List<ReceiptLine> divergentLines(List<StockReceipt> receipts) {
  return [
    for (final receipt in receipts)
      for (final line in receipt.lines)
        if (line.difference != 0) line,
  ];
}
