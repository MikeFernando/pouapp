import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/domain/rules/note_rules.dart';

void main() {
  test('rounds a kilogram line to the nearest cent', () {
    expect(
      lineTotalCents(
        unit: CatalogUnit.kilogram,
        quantity: 1500,
        unitPriceCents: 1000,
      ),
      1500,
    );
    expect(
      lineTotalCents(
        unit: CatalogUnit.kilogram,
        quantity: 1,
        unitPriceCents: 100,
      ),
      0,
    );
    expect(
      lineTotalCents(
        unit: CatalogUnit.kilogram,
        quantity: 500,
        unitPriceCents: 1,
      ),
      1,
    );
  });

  test('keeps piece, bunch and box as whole counts', () {
    expect(
      lineTotalCents(unit: CatalogUnit.piece, quantity: 3, unitPriceCents: 200),
      600,
    );
    expect(
      lineTotalCents(unit: CatalogUnit.bunch, quantity: 2, unitPriceCents: 350),
      700,
    );
    expect(
      lineTotalCents(unit: CatalogUnit.box, quantity: 2, unitPriceCents: 400),
      800,
    );
    expect(baseQuantityFromDisplay(CatalogUnit.piece, 1.5), isNull);
    expect(baseQuantityFromDisplay(CatalogUnit.box, 2), 2);
    expect(baseQuantityFromDisplay(CatalogUnit.kilogram, 1.5), 1500);
    expect(displayQuantity(CatalogUnit.kilogram, 1500), 1.5);
  });

  test('rejects a negative amount', () {
    expect(
      () => lineTotalCents(
        unit: CatalogUnit.kilogram,
        quantity: -1,
        unitPriceCents: 100,
      ),
      throwsArgumentError,
    );
  });
}
