import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/workspace/domain/entities/stock_board.dart';
import 'package:pouapp/features/workspace/presentation/operation_labels.dart';

void main() {
  test('should format money in Brazilian reais', () {
    expect(formatBrl(128450), 'R\$ 1.284,50');
    expect(formatBrl(89000), 'R\$ 890,00');
    expect(formatBrl(0), 'R\$ 0,00');
    expect(formatBrl(128450, hidden: true), 'R\$ ••••');
  });

  test('should format a quantity without mixing units', () {
    expect(formatQuantity(118, StockUnit.kilogram), '118 kg');
    expect(formatQuantity(20, StockUnit.box), '20 cx');
    expect(formatQuantity(1.5, StockUnit.piece), '1,5 un');
    expect(formatQuantity(8, StockUnit.kilogram, hidden: true), '•••• kg');
  });

  test('should describe a cache failure in Portuguese', () {
    expect(
      operationFailureMessage(const CacheFailure()),
      'Não foi possível ler o modo salvo neste aparelho.',
    );
  });
}
