import 'package:equatable/equatable.dart';

/// Base unit of a product. Weight is stored in grams. Counts stay integers.
enum CatalogUnit { kilogram, piece, bunch, box, dozen }

enum StockLocationCode { transit, warehouse, montana }

enum MovementKind { opening, transferOut, transferIn, loss, adjustment, sale }

enum StockRuleViolation {
  nameRequired,
  negativeQuantity,
  fractionalCount,
  incompatibleUnit,
  duplicateOpening,
  productInactive,
  deleteWithHistory,
}

class StockLocation extends Equatable {
  const StockLocation({required this.code, required this.name});

  final StockLocationCode code;
  final String name;

  @override
  List<Object?> get props => [code, name];
}

class CatalogProduct extends Equatable {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.unit,
    required this.active,
    required this.salePriceCents,
    required this.minimums,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.sku,
  });

  final String id;
  final String name;
  final String? category;
  final String? sku;
  final CatalogUnit unit;
  final bool active;
  final int salePriceCents;

  /// Minimum on-hand quantity per location, in the product base unit.
  final Map<StockLocationCode, int> minimums;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    sku,
    unit,
    active,
    salePriceCents,
    minimums,
    createdAt,
    updatedAt,
  ];
}

class StockMovement extends Equatable {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.location,
    required this.quantity,
    required this.kind,
    required this.occurredOn,
    required this.recordedAt,
    this.reason,
    this.operationId,
  });

  final String id;
  final String productId;
  final StockLocationCode location;

  /// Grams for kilogram products. Whole units for piece, bunch and box.
  /// Transfer out, loss and a count that found less stock are negative.
  final int quantity;
  final MovementKind kind;
  final DateTime occurredOn;
  final DateTime recordedAt;
  final String? reason;
  final String? operationId;

  @override
  List<Object?> get props => [
    id,
    productId,
    location,
    quantity,
    kind,
    occurredOn,
    recordedAt,
    reason,
    operationId,
  ];
}

class ProductStock extends Equatable {
  const ProductStock({
    required this.product,
    required this.balances,
    required this.low,
  });

  final CatalogProduct product;
  final Map<StockLocationCode, int> balances;
  final bool low;

  int get total =>
      balances.values.fold<int>(0, (sum, quantity) => sum + quantity);

  @override
  List<Object?> get props => [product, balances, low];
}

class CatalogSnapshot extends Equatable {
  const CatalogSnapshot({
    required this.products,
    required this.movementsToday,
    required this.updatedAt,
  });

  final List<ProductStock> products;
  final int movementsToday;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [products, movementsToday, updatedAt];
}

class ProductDraft extends Equatable {
  const ProductDraft({
    required this.name,
    required this.unit,
    required this.salePriceCents,
    required this.openingLocation,
    required this.openingQuantity,
    this.category,
    this.sku,
    this.minimumQuantity,
  });

  final String name;
  final String? category;
  final String? sku;
  final CatalogUnit unit;
  final int salePriceCents;
  final StockLocationCode openingLocation;
  final int openingQuantity;
  final int? minimumQuantity;

  @override
  List<Object?> get props => [
    name,
    category,
    sku,
    unit,
    salePriceCents,
    openingLocation,
    openingQuantity,
    minimumQuantity,
  ];
}
