import '../domain/entities/catalog.dart';

/// Opening balances that match the gestão board already on screen.
///
/// Inserted once in debug. Release starts empty until the operator registers
/// products. Quantities are grams for weight and whole units otherwise.
///
/// Garlic is packed for the home basket: a 500 g pack and a 1 kg pack.
/// Cebola and batata stay in kilograms. Banana is sold by the dozen.
/// Melancia and the egg tray are sold by the unit.
const demoCatalogProducts = <DemoCatalogProduct>[
  DemoCatalogProduct(
    id: 'product-alho-500',
    name: 'Alho 500 g',
    unit: CatalogUnit.piece,
    quantity: 60,
    minimum: 12,
    sortIndex: 0,
    salePriceCents: 1600,
  ),
  DemoCatalogProduct(
    id: 'product-alho',
    name: 'Alho 1 kg',
    unit: CatalogUnit.piece,
    quantity: 40,
    minimum: 8,
    sortIndex: 1,
    salePriceCents: 3000,
  ),
  DemoCatalogProduct(
    id: 'product-cebola',
    name: 'Cebola',
    unit: CatalogUnit.kilogram,
    quantity: 600000,
    minimum: 50000,
    sortIndex: 2,
    salePriceCents: 450,
  ),
  DemoCatalogProduct(
    id: 'product-batata',
    name: 'Batata',
    unit: CatalogUnit.kilogram,
    quantity: 800000,
    minimum: 80000,
    sortIndex: 3,
    salePriceCents: 450,
  ),
  DemoCatalogProduct(
    id: 'product-banana',
    name: 'Banana nanica',
    unit: CatalogUnit.dozen,
    quantity: 40,
    minimum: 10,
    sortIndex: 4,
    salePriceCents: 590,
  ),
  DemoCatalogProduct(
    id: 'product-tomate',
    name: 'Tomate italiano',
    unit: CatalogUnit.box,
    quantity: 14,
    minimum: 5,
    sortIndex: 5,
    salePriceCents: 5900,
  ),
  DemoCatalogProduct(
    id: 'product-alface',
    name: 'Alface crespa',
    unit: CatalogUnit.piece,
    quantity: 40,
    minimum: 10,
    sortIndex: 6,
    salePriceCents: 350,
  ),
  DemoCatalogProduct(
    id: 'product-laranja',
    name: 'Laranja pera',
    unit: CatalogUnit.kilogram,
    quantity: 22000,
    minimum: 30000,
    sortIndex: 7,
    salePriceCents: 490,
  ),
  DemoCatalogProduct(
    id: 'product-mamao',
    name: 'Mamão formosa',
    unit: CatalogUnit.kilogram,
    quantity: 8000,
    minimum: 15000,
    sortIndex: 8,
    salePriceCents: 690,
  ),
  DemoCatalogProduct(
    id: 'product-limao',
    name: 'Limão tahiti',
    unit: CatalogUnit.kilogram,
    quantity: 6000,
    minimum: 10000,
    sortIndex: 9,
    salePriceCents: 690,
  ),
  DemoCatalogProduct(
    id: 'product-melancia',
    name: 'Melancia',
    unit: CatalogUnit.piece,
    quantity: 18,
    minimum: 4,
    sortIndex: 10,
    salePriceCents: 1290,
  ),
  DemoCatalogProduct(
    id: 'product-ovos',
    name: 'Bandeja de ovos',
    unit: CatalogUnit.piece,
    quantity: 30,
    minimum: 6,
    sortIndex: 11,
    salePriceCents: 1890,
  ),
];

final stapleCatalogProducts = demoCatalogProducts
    .where(
      (product) =>
          product.id == 'product-alho' ||
          product.id == 'product-cebola' ||
          product.id == 'product-batata',
    )
    .toList();

/// Packs and household items added after the first catalog import.
final packedCatalogProducts = demoCatalogProducts
    .where(
      (product) =>
          product.id == 'product-alho-500' ||
          product.id == 'product-melancia' ||
          product.id == 'product-ovos',
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
