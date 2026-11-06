import 'package:equatable/equatable.dart';

import 'catalog.dart';

/// A stock operation is not a sale, a debt, income or an expense.
enum StockOperationKind { load, returnToWarehouse, loss, count }

class StockDraftLine extends Equatable {
  const StockDraftLine({required this.productId, required this.quantity});

  final String productId;

  /// Grams for kilogram products. Whole units for piece, bunch and box.
  /// For a count, this is the physical quantity found, not the difference.
  final int quantity;

  @override
  List<Object?> get props => [productId, quantity];
}

class StockDraft extends Equatable {
  const StockDraft({
    required this.id,
    required this.kind,
    required this.lines,
    this.location,
    this.reason,
  });

  final String id;
  final StockOperationKind kind;
  final StockLocationCode? location;
  final String? reason;
  final List<StockDraftLine> lines;

  @override
  List<Object?> get props => [id, kind, location, reason, lines];
}

class StockOperationLine extends Equatable {
  const StockOperationLine({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    this.previousQuantity,
    this.delta,
  });

  final String productId;
  final String productName;
  final CatalogUnit unit;

  /// Amount moved or lost, or the physical quantity counted.
  final int quantity;
  final int? previousQuantity;
  final int? delta;

  @override
  List<Object?> get props => [
    productId,
    productName,
    unit,
    quantity,
    previousQuantity,
    delta,
  ];
}

class StockOperationRecord extends Equatable {
  const StockOperationRecord({
    required this.id,
    required this.kind,
    required this.occurredOn,
    required this.recordedAt,
    required this.lines,
    this.origin,
    this.destination,
    this.location,
    this.reason,
    this.alreadyRecorded = false,
  });

  final String id;
  final StockOperationKind kind;
  final DateTime occurredOn;
  final DateTime recordedAt;
  final StockLocationCode? origin;
  final StockLocationCode? destination;
  final StockLocationCode? location;
  final String? reason;
  final List<StockOperationLine> lines;

  /// True when this id was confirmed before and stock was left unchanged.
  final bool alreadyRecorded;

  @override
  List<Object?> get props => [
    id,
    kind,
    occurredOn,
    recordedAt,
    origin,
    destination,
    location,
    reason,
    lines,
    alreadyRecorded,
  ];
}
