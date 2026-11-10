import '../../../catalog/domain/rules/stock_rules.dart';
import '../entities/receivable.dart';
import '../entities/street_ledger.dart';

String pixKeyTypeLabel(PixKeyType type) {
  return switch (type) {
    PixKeyType.cpfCnpj => 'CPF/CNPJ',
    PixKeyType.phone => 'Telefone',
    PixKeyType.email => 'E-mail',
    PixKeyType.random => 'Aleatória',
  };
}

String paymentMethodLabel(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => 'Dinheiro',
    PaymentMethod.pix => 'Pix',
    PaymentMethod.card => 'Cartão',
  };
}

String chargeStatusLabel(ChargeStatus status) {
  return switch (status) {
    ChargeStatus.prepared => 'Cobrança preparada',
    ChargeStatus.whatsappOpened => 'WhatsApp aberto',
  };
}

/// Digits only, country code, no trunk zero. WhatsApp click-to-chat rejects
/// a plus sign, spaces and a leading zero.
String? whatsAppDigits(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final national = digits.replaceFirst(RegExp(r'^0+'), '');
  if (national.isEmpty) return null;
  if (national.startsWith('55') && national.length > 11) return national;
  return '55$national';
}

/// Opens the installed WhatsApp and prefills the chat. The message stays
/// on the phone until the user taps Send, so a neighborhood without signal
/// does not block the delivery.
Uri whatsAppAppUri({required String digits, String? message}) {
  final text = message?.trim();
  return Uri(
    scheme: 'whatsapp',
    host: 'send',
    queryParameters: {
      'phone': digits,
      if (text != null && text.isNotEmpty) 'text': text,
    },
  );
}

/// Official click-to-chat link. The text is only prefilled; WhatsApp does
/// not send it until the user taps Send.
/// https://faq.whatsapp.com/5913398998672934
Uri whatsAppChatUri({required String digits, required String message}) {
  return Uri.parse(
    'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
  );
}

String? pixProfileProblem(BusinessProfile profile) {
  final key = profile.pixKey?.trim() ?? '';
  final name = profile.receiverName?.trim() ?? '';
  if (profile.pixKeyType == null || key.isEmpty || name.isEmpty) {
    return 'Informe o tipo, a chave Pix e o nome do recebedor.';
  }
  return switch (profile.pixKeyType!) {
    PixKeyType.email =>
      key.contains('@') && key.contains('.')
          ? null
          : 'Informe um e-mail na chave Pix.',
    PixKeyType.phone =>
      RegExp(r'^\d{10,13}$').hasMatch(key.replaceAll(RegExp(r'\D'), ''))
          ? null
          : 'Informe o telefone da chave Pix com DDD.',
    PixKeyType.cpfCnpj =>
      RegExp(r'^\d{11}$|^\d{14}$').hasMatch(key.replaceAll(RegExp(r'\D'), ''))
          ? null
          : 'Informe o CPF ou o CNPJ da chave Pix.',
    PixKeyType.random => key.length >= 8 ? null : 'Informe a chave aleatória.',
  };
}

ReceiptPlan planReceipt({
  required int amountCents,
  required List<Receivable> selected,
  int? tenderedCents,
  required bool allowCredit,
}) {
  if (amountCents <= 0) {
    return const ReceiptPlan(
      allocations: [],
      allocatedCents: 0,
      creditCents: 0,
      error: 'Informe o valor recebido.',
    );
  }
  if (tenderedCents != null && tenderedCents < amountCents) {
    return const ReceiptPlan(
      allocations: [],
      allocatedCents: 0,
      creditCents: 0,
      error: 'O valor entregue pela cliente não cobre o pagamento.',
    );
  }
  if (selected.isEmpty) {
    return const ReceiptPlan(
      allocations: [],
      allocatedCents: 0,
      creditCents: 0,
      error: 'Escolha as dívidas que este pagamento quita.',
    );
  }
  final open = selected.fold<int>(0, (sum, item) => sum + item.openCents);
  if (amountCents > open && !allowCredit) {
    return const ReceiptPlan(
      allocations: [],
      allocatedCents: 0,
      creditCents: 0,
      error: 'O valor passa da dívida escolhida. Informe o troco ou registre o excedente como crédito.',
    );
  }
  final allocations = <PaymentShare>[];
  var remaining = amountCents;
  for (final item in selected) {
    if (remaining <= 0 || item.openCents <= 0) continue;
    final take = remaining < item.openCents ? remaining : item.openCents;
    allocations.add(PaymentShare(orderId: item.id, amountCents: take));
    remaining -= take;
  }
  final credit = allowCredit ? remaining : 0;
  return ReceiptPlan(
    allocations: allocations,
    allocatedCents: amountCents - credit,
    creditCents: credit,
    changeCents: tenderedCents == null ? null : tenderedCents - amountCents,
  );
}

/// Uses available credit on the selected debts, after the cash or Pix
/// allocation. Nothing is used when [availableCents] is zero.
List<PaymentShare> planCreditUse({
  required int availableCents,
  required List<Receivable> selected,
  required List<PaymentShare> alreadyAllocated,
}) {
  if (availableCents <= 0 || selected.isEmpty) return const [];
  var pool = availableCents;
  final shares = <PaymentShare>[];
  for (final item in selected) {
    if (pool <= 0) break;
    final taken = alreadyAllocated
        .where((share) => share.orderId == item.id)
        .fold<int>(0, (sum, share) => sum + share.amountCents);
    final open = item.openCents - taken;
    if (open <= 0) continue;
    final take = pool < open ? pool : open;
    shares.add(PaymentShare(orderId: item.id, amountCents: take));
    pool -= take;
  }
  return shares;
}

/// One due date only when every open item shares it. Different dates stay unnamed.
String? sharedDueDate(Iterable<String?> dueDates) {
  final values = dueDates.toSet();
  if (values.length != 1) return null;
  return values.single;
}

String chargeDescription({
  required bool total,
  required bool custom,
  String? receivableDescription,
}) {
  if (custom) return 'desta cobrança';
  if (total) return 'do saldo em aberto';
  return 'restante de ${receivableDescription ?? 'conta'}';
}

String? chargeAmountProblem({
  required int amountCents,
  required int openCents,
}) {
  if (openCents <= 0) return 'Não há saldo em aberto para cobrar.';
  if (amountCents <= 0) return 'Informe um valor maior que zero.';
  if (amountCents > openCents) {
    return 'A cobrança não pode passar do saldo em aberto.';
  }
  return null;
}

String chargeMessage({
  required String customerName,
  required String description,
  required int amountCents,
  required String pixKey,
  required String receiverName,
  String? dueOn,
}) {
  final due = dueOn == null ? '' : 'Vencimento: ${_day(dueOn)}\n';
  final key = pixKey.trim();
  return 'Olá, $customerName! 😊\n'
      'O valor $description é de ${formatReais(amountCents)}.\n'
      '$due\n'
      'Copie a chave Pix abaixo e cole no seu banco:\n'
      '\n'
      '$key\n'
      '\n'
      'Recebedor: $receiverName\n'
      '\n'
      'Depois de pagar, pode me enviar o comprovante por aqui. Obrigado!';
}

String _day(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}
