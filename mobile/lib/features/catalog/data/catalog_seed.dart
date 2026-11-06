import '../domain/entities/catalog.dart';

/// Opening balances that match the gestão board already on screen.
///
/// Inserted once in debug. Release starts empty until the operator registers
/// products. Quantities are grams for weight and whole units otherwise.
///
/// Alho, cebola and batata stay in kilograms: that is the unit after weighing
/// and packing. Banana is sold by the dozen.
const demoCatalogProducts = <DemoCatalogProduct>[
  DemoCatalogProduct(
    id: 'product-alho',
    name: 'Alho',
    unit: CatalogUnit.kilogram,
    quantity: 500000,
    minimum: 50000,
    sortIndex: 0,
    salePriceCents: 3000,
  ),
  DemoCatalogProduct(
    id: 'product-cebola',
    name: 'Cebola',
    unit: CatalogUnit.kilogram,
    quantity: 600000,
    minimum: 50000,
    sortIndex: 1,
  ),
  DemoCatalogProduct(
    id: 'product-batata',
    name: 'Batata',
    unit: CatalogUnit.kilogram,
    quantity: 800000,
    minimum: 80000,
    sortIndex: 2,
  ),
  DemoCatalogProduct(
    id: 'product-banana',
    name: 'Banana nanica',
    unit: CatalogUnit.dozen,
    quantity: 40,
    minimum: 10,
    sortIndex: 3,
  ),
  DemoCatalogProduct(
    id: 'product-tomate',
    name: 'Tomate italiano',
    unit: CatalogUnit.box,
    quantity: 14,
    minimum: 5,
    sortIndex: 4,
  ),
  DemoCatalogProduct(
    id: 'product-alface',
    name: 'Alface crespa',
    unit: CatalogUnit.piece,
    quantity: 40,
    minimum: 10,
    sortIndex: 5,
  ),
  DemoCatalogProduct(
    id: 'product-laranja',
    name: 'Laranja pera',
    unit: CatalogUnit.kilogram,
    quantity: 22000,
    minimum: 30000,
    sortIndex: 6,
  ),
  DemoCatalogProduct(
    id: 'product-mamao',
    name: 'Mamão formosa',
    unit: CatalogUnit.kilogram,
    quantity: 8000,
    minimum: 15000,
    sortIndex: 7,
  ),
  DemoCatalogProduct(
    id: 'product-limao',
    name: 'Limão tahiti',
    unit: CatalogUnit.kilogram,
    quantity: 6000,
    minimum: 10000,
    sortIndex: 8,
  ),
];

final stapleCatalogProducts = demoCatalogProducts
    .where(
      (product) =>
          product.id.startsWith('product-alho') ||
          product.id == 'product-cebola' ||
          product.id == 'product-batata',
    )
    .toList();

class DemoCatalogProduct {
  const DemoCatalogProduct({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.minimum,
    required this.sortIndex,
    this.salePriceCents = 0,
  });

  final String id;
  final String name;
  final CatalogUnit unit;
  final int quantity;
  final int minimum;
  final int sortIndex;
  final int salePriceCents;
}
