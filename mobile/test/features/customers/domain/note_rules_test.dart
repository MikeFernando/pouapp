import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';
import 'package:pouapp/features/customers/domain/rules/note_rules.dart';

void main() {
  test('increments quantity when the same product is added again', () {
    const existing = [
      NoteLine(
        id: '1',
        productId: 'abobora',
        name: 'Abóbora',
        unit: CatalogUnit.piece,
        quantity: 1,
        unitPriceCents: 390,
      ),
      NoteLine(
        id: '2',
        productId: 'abobrinha',
        name: 'Abobrinha',
        unit: CatalogUnit.piece,
        quantity: 1,
        unitPriceCents: 490,
      ),
    ];

    final merged = appendOrIncrementNoteLine(
      existing: existing,
      incoming: const NoteLineDraft(
        productId: 'abobora',
        name: 'Abóbora',
        unit: CatalogUnit.piece,
        quantity: 2,
        unitPriceCents: 400,
      ),
    );

    expect(merged, hasLength(2));
    expect(merged[0].id, '1');
    expect(merged[0].quantity, 3);
    expect(merged[0].unitPriceCents, 390);
    expect(merged[1].quantity, 1);
  });

  test('appends when the product is not on the note yet', () {
    const existing = [
      NoteLine(
        id: '1',
        productId: 'abobrinha',
        name: 'Abobrinha',
        unit: CatalogUnit.piece,
        quantity: 1,
        unitPriceCents: 490,
      ),
    ];

    final merged = appendOrIncrementNoteLine(
      existing: existing,
      incoming: const NoteLineDraft(
        productId: 'abobora',
        name: 'Abóbora',
        unit: CatalogUnit.piece,
        quantity: 1,
        unitPriceCents: 390,
      ),
    );

    expect(merged, hasLength(2));
    expect(merged[1].productId, 'abobora');
    expect(merged[1].quantity, 1);
  });

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
