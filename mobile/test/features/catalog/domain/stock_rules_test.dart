import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/catalog/domain/entities/stock_operation.dart';
import 'package:pouapp/features/catalog/domain/rules/stock_rules.dart';

void main() {
  final instant = DateTime.utc(2026, 11, 3);
  final alho = CatalogProduct(
    id: 'alho',
    name: 'Alho',
    unit: CatalogUnit.kilogram,
    active: true,
    salePriceCents: 3000,
    minimums: const {StockLocationCode.warehouse: 2000},
    createdAt: instant,
    updatedAt: instant,
  );

  test('sums stock by location without mixing grams into another place', () {
    final balances = balancesFor([
      StockMovement(
        id: '1',
        productId: 'alho',
        location: StockLocationCode.warehouse,
        quantity: 10000,
        kind: MovementKind.opening,
        occurredOn: instant,
        recordedAt: instant,
      ),
      StockMovement(
        id: '2',
        productId: 'alho',
        location: StockLocationCode.warehouse,
        quantity: -4000,
        kind: MovementKind.opening,
        occurredOn: instant,
        recordedAt: instant,
      ),
      StockMovement(
        id: '3',
        productId: 'alho',
        location: StockLocationCode.montana,
        quantity: 4000,
        kind: MovementKind.opening,
        occurredOn: instant,
        recordedAt: instant,
      ),
    ]);

    expect(balances[StockLocationCode.warehouse], 6000);
    expect(balances[StockLocationCode.montana], 4000);
    expect(balances[StockLocationCode.transit], 0);
    expect(formatBaseQuantity(CatalogUnit.kilogram, 6000), '6 kg');
    expect(formatBaseQuantity(CatalogUnit.kilogram, 500), '0,5 kg');
  });

  test('marks stock low only when a location is below its minimum', () {
    expect(isLowStock(alho, {StockLocationCode.warehouse: 1000}), isTrue);
    expect(isLowStock(alho, {StockLocationCode.warehouse: 2000}), isFalse);
    expect(
      isLowStock(
        CatalogProduct(
          id: alho.id,
          name: alho.name,
          unit: alho.unit,
          active: false,
          salePriceCents: alho.salePriceCents,
          minimums: alho.minimums,
          createdAt: alho.createdAt,
          updatedAt: alho.updatedAt,
        ),
        {StockLocationCode.warehouse: 0},
      ),
      isFalse,
    );
  });

  test('keeps weight and refuses incompatible units', () {
    expect(
      baseConsumed(
        productUnit: CatalogUnit.kilogram,
        presentationUnit: CatalogUnit.kilogram,
        quantityInBase: 500,
        packageCount: 1,
      ),
      500,
    );
    expect(
      baseConsumed(
        productUnit: CatalogUnit.piece,
        presentationUnit: CatalogUnit.kilogram,
        quantityInBase: 500,
        packageCount: 1,
      ),
      isNull,
    );
    expect(
      weightConserved(consumed: 10000, packaged: 9500, returned: 500, lost: 0),
      isTrue,
    );
    expect(
      weightConserved(consumed: 10000, packaged: 9500, returned: 0, lost: 0),
      isFalse,
    );
    expect(wouldGoNegative(1000, -1000), isFalse);
    expect(wouldGoNegative(1000, -1001), isTrue);
  });

  test('parses money in cents and weight in grams', () {
    expect(parseReaisToCents('30,00'), 3000);
    expect(parseReaisToCents('10.10'), 1010);
    expect(parseReaisToCents(''), 0);
    expect(parseReaisToCents('-1'), isNull);
    expect(parseKilogramsToGrams('1,5'), 1500);
    expect(parseKilogramsToGrams('0,125'), 125);
    expect(parseBaseQuantity(CatalogUnit.piece, '2'), 2);
    expect(parseBaseQuantity(CatalogUnit.bunch, '1,5'), isNull);
    expect(parseBaseQuantity(CatalogUnit.kilogram, '1,5'), 1500);
    expect(parseBaseQuantity(CatalogUnit.box, '2'), 2);
    expect(parseBaseQuantity(CatalogUnit.box, '2,5'), isNull);
  });

  test('transfer, loss and count stay in the product unit', () {
    final load = transferEnds(StockOperationKind.load);
    final back = transferEnds(StockOperationKind.returnToWarehouse);
    expect(load.$1, StockLocationCode.warehouse);
    expect(load.$2, StockLocationCode.montana);
    expect(load.$1 == load.$2, isFalse);
    expect(back.$1 == back.$2, isFalse);
    expect(
      stockLineProblem(
        kind: StockOperationKind.load,
        productName: 'Banana',
        active: true,
        unit: CatalogUnit.kilogram,
        quantity: 40000,
        available: 100000,
        duplicate: false,
        place: 'Depósito',
      ),
      isNull,
    );
    expect(
      stockLineProblem(
        kind: StockOperationKind.load,
        productName: 'Banana',
        active: true,
        unit: CatalogUnit.kilogram,
        quantity: 40000,
        available: 30000,
        duplicate: false,
        place: 'Depósito',
      ),
      'Banana: em Depósito há 30 kg.',
    );
    expect(
      stockLineProblem(
        kind: StockOperationKind.load,
        productName: 'Tomate',
        active: true,
        unit: CatalogUnit.box,
        quantity: 2,
        available: 2,
        duplicate: false,
        place: 'Depósito',
      ),
      isNull,
    );
    expect(
      stockOperationProblem(
        kind: StockOperationKind.loss,
        location: StockLocationCode.montana,
        reason: '   ',
      ),
      'Informe o motivo.',
    );
    expect(
      stockLineProblem(
        kind: StockOperationKind.count,
        productName: 'Banana',
        active: true,
        unit: CatalogUnit.kilogram,
        quantity: 23000,
        available: 25000,
        duplicate: false,
        place: 'Montana',
      ),
      isNull,
    );
    expect(editBaseQuantity(CatalogUnit.kilogram, 1250), '1,25');
    expect(editBaseQuantity(CatalogUnit.box, 2), '2');
  });

  test('refuses a second opening balance and a negative one', () {
    expect(
      openingViolation(
        active: true,
        quantity: 1000,
        openingAlreadyRecorded: true,
      ),
      StockRuleViolation.duplicateOpening,
    );
    expect(
      openingViolation(
        active: true,
        quantity: -1,
        openingAlreadyRecorded: false,
      ),
      StockRuleViolation.negativeQuantity,
    );
    expect(
      openingViolation(
        active: false,
        quantity: 1,
        openingAlreadyRecorded: false,
      ),
      StockRuleViolation.productInactive,
    );
  });
}
