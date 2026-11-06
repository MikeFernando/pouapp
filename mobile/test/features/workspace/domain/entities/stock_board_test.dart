import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/stock_board.dart';

void main() {
  const tKilograms = ReceiptLine(
    productName: 'Banana nanica',
    supplierName: 'Verde Vale',
    expectedQuantity: 120,
    receivedQuantity: 10,
    unit: StockUnit.kilogram,
    grossWeightKg: 12,
    tareWeightKg: 2,
    netWeightKg: 10,
  );
  const tBoxes = ReceiptLine(
    productName: 'Tomate italiano',
    supplierName: 'Verde Vale',
    expectedQuantity: 4,
    receivedQuantity: 4,
    unit: StockUnit.box,
  );

  test('should keep received totals separated by unit', () {
    final totals = receivedTotalsByUnit([
      tKilograms,
      tBoxes,
      const ReceiptLine(
        productName: 'Laranja pera',
        supplierName: 'Verde Vale',
        expectedQuantity: 5,
        receivedQuantity: 5,
        unit: StockUnit.kilogram,
      ),
    ]);

    expect(totals[StockUnit.kilogram], 15);
    expect(totals[StockUnit.box], 4);
    expect(totals.containsKey(StockUnit.piece), isFalse);
  });

  test('should report weight only when a weight was informed', () {
    expect(tKilograms.hasWeight, isTrue);
    expect(tBoxes.hasWeight, isFalse);
    expect(tKilograms.difference, -110);
  });
}
