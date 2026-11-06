import '../../workspace/presentation/operation_labels.dart';
import '../domain/entities/freight_ledger.dart';

String freightDirectionLabel(FreightDirection direction) {
  return switch (direction) {
    FreightDirection.outbound => 'Ida para Curitiba',
    FreightDirection.inbound => 'Volta para Apiaí',
    FreightDirection.local => 'Local em Apiaí',
  };
}

String freightStatusLabel(FreightStatus status) {
  return switch (status) {
    FreightStatus.draft => 'Rascunho',
    FreightStatus.scheduled => 'Agendado',
    FreightStatus.collected => 'Coletado',
    FreightStatus.delivered => 'Entregue',
    FreightStatus.cancelled => 'Cancelado',
  };
}

String freightTripStatusLabel(FreightTripStatus status) {
  return switch (status) {
    FreightTripStatus.planned => 'Planejada',
    FreightTripStatus.underway => 'Em andamento',
    FreightTripStatus.completed => 'Concluída',
    FreightTripStatus.cancelled => 'Cancelada',
  };
}

String freightPaymentLabel(FreightPaymentStanding standing) {
  return switch (standing) {
    FreightPaymentStanding.open => 'Em aberto',
    FreightPaymentStanding.partial => 'Parcialmente pago',
    FreightPaymentStanding.paid => 'Pago',
  };
}

String freightPayMethodLabel(FreightPayMethod method) {
  return switch (method) {
    FreightPayMethod.pix => 'Pix',
    FreightPayMethod.cash => 'Dinheiro',
    FreightPayMethod.card => 'Cartão',
  };
}

String freightMonthLabel(DateTime day) {
  const months = [
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
  return '${months[day.month - 1]} de ${day.year}';
}

String freightIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String freightMoney(int cents) => formatBrl(cents);

String freightDayLabel(String iso) {
  if (iso.length < 10) return iso;
  return formatDay(DateTime.parse(iso));
}

int? parseFreightCents(String raw) {
  var text = raw.replaceAll('R\$', '').replaceAll(' ', '');
  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  }
  final value = double.tryParse(text);
  if (value == null) return null;
  return (value * 100).round();
}
