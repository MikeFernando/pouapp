import '../../../../core/error/failures.dart';
import '../domain/entities/sales_board.dart';
import '../domain/entities/stock_board.dart';
import '../domain/entities/street_ledger.dart';
import '../domain/failures/street_failure.dart';

String operationFailureMessage(Failure failure) {
  return switch (failure) {
    CacheFailure() => 'Não foi possível ler o modo salvo neste aparelho.',
    StreetChangeFailure(:final message) => message,
    _ => 'Não foi possível carregar a operação. Tente novamente.',
  };
}

const indicatorUnavailable = 'Ainda não disponível';

/// Money from a real query. A missing rule stays unnamed as zero.
String formatOptionalBrl(int? cents, {bool hidden = false}) {
  if (cents == null) return indicatorUnavailable;
  return formatBrl(cents, hidden: hidden);
}

String formatBrl(int cents, {bool hidden = false}) {
  if (hidden) return 'R\$ ••••';
  final negative = cents < 0;
  final value = cents.abs();
  final whole = value ~/ 100;
  final fraction = (value % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    if (index > 0 && remaining % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}R\$ $buffer,$fraction';
}

String formatDay(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String stockUnitLabel(StockUnit unit) {
  return switch (unit) {
    StockUnit.kilogram => 'kg',
    StockUnit.box => 'cx',
    StockUnit.piece => 'un',
    StockUnit.bunch => 'maço',
    StockUnit.dozen => 'dúzia',
  };
}

String formatQuantity(double quantity, StockUnit unit, {bool hidden = false}) {
  if (hidden) return '•••• ${stockUnitLabel(unit)}';
  if (unit == StockUnit.dozen) {
    final whole = quantity.round();
    final label = whole == 1 ? 'dúzia' : 'dúzias';
    return '$whole $label';
  }
  final text = quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(1).replaceAll('.', ',');
  return '$text ${stockUnitLabel(unit)}';
}

String deliveryStatusLabel(DeliveryStatus status) {
  return switch (status) {
    DeliveryStatus.pending => 'Pendente',
    DeliveryStatus.onTheWay => 'A caminho',
    DeliveryStatus.atCustomer => 'No cliente',
  };
}

String paymentStatusLabel(PaymentStatus status) {
  return switch (status) {
    PaymentStatus.pending => 'Pagamento pendente',
    PaymentStatus.received => 'Recebido',
  };
}

String saleUnitLabel(SaleUnit unit) {
  return switch (unit) {
    SaleUnit.kilogram => 'kg',
    SaleUnit.piece => 'un',
    SaleUnit.bunch => 'maço',
  };
}

String formatSaleQuantity(double quantity, SaleUnit unit) {
  final text = quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(1).replaceAll('.', ',');
  final label = saleUnitLabel(unit);
  final plural = unit == SaleUnit.bunch && quantity != 1 ? 'maços' : label;
  return '$text $plural';
}

String visitReasonLabel(VisitReason reason) {
  return switch (reason) {
    VisitReason.sale => 'Venda',
    VisitReason.delivery => 'Entrega',
    VisitReason.collection => 'Recebimento',
  };
}

String visitStatusLabel(VisitStatus status) {
  return switch (status) {
    VisitStatus.pending => 'Pendente',
    VisitStatus.inService => 'Em atendimento',
    VisitStatus.completed => 'Concluída',
    VisitStatus.missed => 'Não atendida',
  };
}

String paymentMethodLabel(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => 'Dinheiro',
    PaymentMethod.pix => 'Pix',
    PaymentMethod.card => 'Cartão',
  };
}

String receiptStatusLabel(ReceiptStatus status) {
  return switch (status) {
    ReceiptStatus.waiting => 'Aguardando',
    ReceiptStatus.checking => 'Em conferência',
    ReceiptStatus.done => 'Concluído',
  };
}
