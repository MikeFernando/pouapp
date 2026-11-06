import '../entities/street_ledger.dart';

/// Company money that can be named from the street ledger.
///
/// A sale has no date of its own. Its total is every recorded sale that is
/// not a demonstration. A payment keeps [CustomerPayment.paidOn]. The company
/// receipt total is every such payment; a month total uses only that date.
class CompanyIndicators {
  const CompanyIndicators({
    required this.soldCents,
    required this.receivedCents,
  });

  static const soldLabel = 'Vendido registrado';
  static const soldScope = 'Todos os registros';
  static const receivedLabel = 'Recebido registrado';
  static const receivedScope = 'Todos os pagamentos';

  /// Recorded street sales, excluding demonstration orders.
  final int soldCents;

  /// Recorded street payments, excluding demonstration payments.
  /// A payment is not itself a sale.
  final int receivedCents;

  factory CompanyIndicators.fromLedger(
    StreetLedger ledger, {
    Iterable<CustomerPayment> accountPayments = const [],
  }) {
    final sold = ledger.orders
        .where((order) => order.recorded && !order.fromSeed)
        .fold<int>(0, (sum, order) => sum + order.totalCents);
    final received = ledger.payments
        .where((payment) => !payment.fromSeed)
        .fold<int>(0, (sum, payment) => sum + payment.amountCents);
    final accounts = accountPayments
        .where((payment) => !payment.fromSeed)
        .fold<int>(0, (sum, payment) => sum + payment.amountCents);
    return CompanyIndicators(
      soldCents: sold,
      receivedCents: received + accounts,
    );
  }
}

/// Non-demonstration receipts grouped by calendar day of [CustomerPayment.paidOn].
Map<int, int> receiptsByDay(
  StreetLedger ledger,
  DateTime month, {
  Iterable<CustomerPayment> more = const [],
}) {
  final totals = <int, int>{};
  final payments = [
    ...ledger.payments.where((payment) => !payment.fromSeed),
    ...more.where((payment) => !payment.fromSeed),
  ];
  for (final payment in payments) {
    final date = dateFromIso(payment.paidOn);
    if (date.year != month.year || date.month != month.month) continue;
    totals[date.day] = (totals[date.day] ?? 0) + payment.amountCents;
  }
  return totals;
}

int receiptsCentsInMonth(StreetLedger ledger, DateTime month) {
  return receiptsByDay(
    ledger,
    month,
  ).values.fold<int>(0, (sum, value) => sum + value);
}

String monthHeading(DateTime month) {
  const names = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return '${names[month.month - 1]} de ${month.year}';
}

String receiptsInMonthLabel(DateTime month) =>
    'Recebimentos em ${monthHeading(month)}';
