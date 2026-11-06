import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:pouapp/features/workspace/domain/rules/company_indicators.dart';

void main() {
  test('labels match the date each total actually uses', () {
    const sale = SaleLine(
      productName: 'Alface crespa',
      quantity: 2,
      unit: SaleUnit.bunch,
      unitPriceCents: 350,
    );
    const demonstration = SaleLine(
      productName: 'Banana nanica',
      quantity: 10,
      unit: SaleUnit.kilogram,
      unitPriceCents: 1864,
    );
    const ledger = StreetLedger(
      orders: [
        SaleOrder(
          id: 'order-1044',
          code: '1044',
          customerId: 'customer-1',
          customerName: 'Marina Costa',
          lines: [sale],
          recorded: true,
          delivered: false,
        ),
        SaleOrder(
          id: 'order-1042',
          code: '1042',
          customerId: 'customer-1',
          customerName: 'Marina Costa',
          lines: [demonstration],
          recorded: true,
          delivered: false,
          fromSeed: true,
        ),
      ],
      payments: [
        CustomerPayment(
          id: 'pay-real-october',
          customerId: 'customer-1',
          amountCents: 5000,
          paidOn: '2026-10-20',
          method: PaymentMethod.pix,
        ),
        CustomerPayment(
          id: 'pay-seed',
          customerId: 'customer-1',
          amountCents: 7200,
          paidOn: '2026-10-20',
          method: PaymentMethod.cash,
          fromSeed: true,
        ),
        CustomerPayment(
          id: 'pay-real-november',
          customerId: 'customer-1',
          amountCents: 2000,
          paidOn: '2026-11-03',
          method: PaymentMethod.cash,
        ),
      ],
    );

    final indicators = CompanyIndicators.fromLedger(ledger);

    expect(indicators.soldCents, 700);
    expect(CompanyIndicators.soldLabel, 'Vendido registrado');
    expect(CompanyIndicators.soldScope, 'Todos os registros');
    expect(indicators.receivedCents, 7000);
    expect(CompanyIndicators.receivedLabel, 'Recebido registrado');
    expect(CompanyIndicators.receivedScope, 'Todos os pagamentos');

    final october = DateTime(2026, 10);
    final november = DateTime(2026, 11);
    expect(receiptsCentsInMonth(ledger, october), 5000);
    expect(receiptsInMonthLabel(october), 'Recebimentos em Outubro de 2026');
    expect(receiptsByDay(ledger, october), {20: 5000});
    expect(receiptsCentsInMonth(ledger, november), 2000);
    expect(receiptsInMonthLabel(november), 'Recebimentos em Novembro de 2026');
    expect(receiptsCentsInMonth(ledger, DateTime(2026, 12)), 0);
  });
}
