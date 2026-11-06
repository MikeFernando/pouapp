import '../entities/voice_command.dart';
import '../voice_text.dart';
import 'voice_dates.dart';

const _blocked = [
  'pagamento',
  'pagar',
  'receba',
  'receber',
  'recebi',
  'confirma a entrega',
  'confirmar a entrega',
  'confirme a entrega',
  'confirma entrega',
  'confirmar entrega',
  'confirme entrega',
  'estorna',
  'estornar',
  'estorno',
  'whatsapp',
  'mensagem',
  'pix',
];

const _addVerbs = [
  'adicione',
  'adicionar',
  'adiciona',
  'coloque',
  'colocar',
  'coloca',
  'ponha',
  'inclua',
  'incluir',
  'bota',
  'anote',
  'anota',
  'anotar',
  'mais',
];

const _changeVerbs = [
  'mude',
  'mudar',
  'muda',
  'altere',
  'alterar',
  'altera',
  'troque',
  'trocar',
  'troca',
  'corrija',
  'corrigir',
];

VoiceCommand interpretVoice(String transcript) {
  var text = foldVoice(transcript);
  if (text.startsWith('e ')) text = text.substring(2).trim();
  if (text.isEmpty) {
    return VoiceCommand(
      intent: VoiceIntent.unclear,
      transcript: transcript,
      reply: 'Não consegui ouvir. Tente novamente.',
    );
  }
  if (text == 'confirmar entrega' ||
      text == 'confirmar a entrega' ||
      text == 'confirma a entrega' ||
      text == 'confirme a entrega' ||
      text == 'confirma entrega' ||
      text == 'confirme entrega') {
    return VoiceCommand(
      intent: VoiceIntent.reviewDelivery,
      transcript: transcript,
    );
  }
  final promised = _promisedPix(text);
  if (promised) {
    return VoiceCommand(
      intent: VoiceIntent.arrangePayment,
      transcript: transcript,
      settlement: 'promised',
      reply: 'O Pix ainda não entrou. Nada foi recebido.',
    );
  }
  if (readSpokenDate(text) != null ||
      RegExp(r'\bvencimento\b').hasMatch(text)) {
    return VoiceCommand(
      intent: VoiceIntent.setDueDate,
      transcript: transcript,
      looseText: text,
    );
  }
  final payment = _payment(transcript, text);
  if (payment != null) return payment;
  for (final word in _blocked) {
    if (text.contains(word)) {
      return VoiceCommand(
        intent: VoiceIntent.unsupported,
        transcript: transcript,
        reply: 'Estorno, mensagem e pagamento de dívida antiga continuam na tela. Nada foi alterado.',
      );
    }
  }
  final consult = _consultCustomer(text);
  if (consult != null) {
    return VoiceCommand(
      intent: VoiceIntent.consultAccount,
      transcript: transcript,
      customerQuery: consult,
    );
  }
  final change = _change(transcript, text);
  if (change != null) return change;
  if (_addVerbs.any((verb) => text == verb || text.startsWith('$verb '))) {
    return _add(transcript, text);
  }
  final loose = _loose(transcript, text);
  if (loose != null) return loose;
  if (_takeAmount(text).quantity != null) return _add(transcript, text);
  return VoiceCommand(
    intent: VoiceIntent.unclear,
    transcript: transcript,
    reply:
        'Não entendi. Posso anotar um produto na nota ou consultar a dívida.',
  );
}

VoiceCommand _add(String transcript, String text) {
  var rest = text;
  for (final verb in _addVerbs) {
    if (rest == verb || rest.startsWith('$verb ')) {
      rest = rest.substring(verb.length).trim();
      break;
    }
  }
  String? customer;
  for (final marker in [
    ' na nota da ',
    ' na nota de ',
    ' na nota do ',
    ' para a ',
    ' para o ',
    ' para ',
    ' pra ',
  ]) {
    final at = rest.lastIndexOf(marker);
    if (at >= 0) {
      customer = rest.substring(at + marker.length).trim();
      rest = rest.substring(0, at).trim();
      break;
    }
  }
  rest = _withoutVisit(rest);
  if (rest.startsWith('tambem ')) rest = rest.substring(7).trim();
  if (_visitCue(customer)) customer = null;
  final pieces = _splitItems(rest);
  if (pieces.length > 1) {
    return VoiceCommand(
      intent: VoiceIntent.addDraftItem,
      transcript: transcript,
      customerQuery: customer,
      items: [for (final piece in pieces) _item(piece)],
    );
  }
  final price = _extractPrice(rest);
  rest = price.rest;
  final amount = _takeAmount(rest);
  rest = amount.rest;
  if (rest.startsWith('de ')) rest = rest.substring(3).trim();
  final product = _singular(rest.trim());
  if (product.isEmpty && (customer == null || customer.isEmpty)) {
    return VoiceCommand(
      intent: VoiceIntent.unclear,
      transcript: transcript,
      reply: 'Diga o produto e a cliente. Por exemplo: um quilo de abacaxi para Adriele.',
    );
  }
  return VoiceCommand(
    intent: VoiceIntent.addDraftItem,
    transcript: transcript,
    customerQuery: customer,
    productQuery: product.isEmpty ? null : product,
    quantity: amount.quantity,
    unit: amount.unit,
    priceCents: price.cents,
    priceBasis:
        price.basis ??
        (price.cents != null && amount.quantity != null
            ? VoicePriceBasis.total
            : null),
  );
}

bool _promisedPix(String text) {
  if (!text.contains('pix')) return false;
  if (RegExp(r'\b(conferi|recebi|paguei|pagou|entrou|caiu)\b').hasMatch(text)) {
    return false;
  }
  return RegExp(r'\b(vou|vai|manda|mandar|enviar|envio)\b').hasMatch(text);
}

VoiceCommand? _payment(String transcript, String text) {
  final fiado =
      text.contains('fiado') ||
      text.contains('fica a prazo') ||
      text.contains('ficar a prazo');
  final received = RegExp(r'\b(recebi|pagou|paguei|conferi)\b').hasMatch(text);
  if (!fiado && !received) return null;
  if (fiado && !received) {
    return VoiceCommand(
      intent: VoiceIntent.arrangePayment,
      transcript: transcript,
      settlement: 'fiado',
    );
  }
  final gave = RegExp(r'\b(?:me deu|ela me deu|entregou|me entregou)\b')
      .firstMatch(text);
  int? tendered;
  var amountText = text;
  if (gave != null) {
    tendered = _extractPrice(text.substring(gave.end)).cents;
    amountText = text.substring(0, gave.start);
  }
  final amount = _extractPrice(amountText).cents;
  final payAll = RegExp(r'\b(tudo|a compra inteira)\b').hasMatch(text);
  String? settlement;
  if (text.contains('dinheiro')) settlement = 'cash';
  if (text.contains('pix')) settlement = 'pix';
  final missingMethod = settlement == null;
  final missingAmount = amount == null && !payAll && tendered == null;
  return VoiceCommand(
    intent: VoiceIntent.arrangePayment,
    transcript: transcript,
    settlement: settlement,
    priceCents: amount,
    tenderedCents: tendered,
    payAll: payAll,
    includePriorDebt: text.contains('divida anterior'),
    gap: missingMethod || missingAmount ? VoiceGap.payment : VoiceGap.none,
  );
}

VoiceCommand? _change(String transcript, String text) {
  String? verb;
  for (final candidate in _changeVerbs) {
    if (text == candidate || text.startsWith('$candidate ')) {
      verb = candidate;
      break;
    }
  }
  if (verb == null) return null;
  final price = _extractPrice(text);
  var rest = price.rest;
  if (rest == verb || rest.startsWith('$verb ')) {
    rest = rest.substring(verb.length).trim();
  }
  for (final article in ['a ', 'o ', 'as ', 'os ']) {
    if (rest.startsWith(article)) {
      rest = rest.substring(article.length).trim();
      break;
    }
  }
  rest = rest.replaceAll(RegExp(r'\bpara\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
  rest = _withoutVisit(rest);
  String? customer;
  for (final marker in [' da ', ' do ', ' de ']) {
    final at = rest.lastIndexOf(marker);
    if (at <= 0) continue;
    customer = rest.substring(at + marker.length).trim();
    rest = rest.substring(0, at).trim();
    break;
  }
  if (_visitCue(customer)) customer = null;
  return VoiceCommand(
    intent: VoiceIntent.repriceDraftItem,
    transcript: transcript,
    customerQuery: customer == null || customer.isEmpty ? null : customer,
    looseText: rest.isEmpty ? null : rest,
    priceCents: price.cents,
    priceBasis: price.basis,
  );
}

VoiceCommand? _loose(String transcript, String text) {
  final price = _extractPrice(text);
  if (price.cents == null) return null;
  var rest = _withoutVisit(price.rest);
  if (rest.startsWith('cliente ')) rest = rest.substring(8).trim();
  if (rest.isEmpty) {
    return VoiceCommand(
      intent: VoiceIntent.unclear,
      transcript: transcript,
      reply: 'Diga o produto e a cliente. Por exemplo: cliente Adriele, melancia quinze reais.',
    );
  }
  return VoiceCommand(
    intent: VoiceIntent.addDraftItem,
    transcript: transcript,
    looseText: rest,
    priceCents: price.cents,
    priceBasis: price.basis,
  );
}

({int? cents, VoicePriceBasis? basis, String rest}) _extractPrice(String text) {
  final match = _priceExpression.firstMatch(text);
  if (match == null) return (cents: null, basis: null, rest: text);
  final cents = _priceCents(match);
  var rest = '${text.substring(0, match.start)} ${text.substring(match.end)}'
      .trim();
  rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
  return (cents: cents, basis: _priceBasis(text), rest: rest);
}

final _priceExpression = RegExp(
  r'(?:(?:\bpor\b|\ba\b)\s+)?(?:r\$\s*)?(\d+(?:[.,]\d{1,2})?)\s+(?:reais|real)\b'
  r'|'
  r'(?:(?:\bpor\b|\ba\b)\s+)?'
  r'(cem|(?:vinte|trinta|quarenta|cinquenta|sessenta|setenta|oitenta|noventa)'
  r'(?:\s+e\s+(?:um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove))?|'
  r'um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze|'
  r'treze|quatorze|catorze|quinze|dezesseis|dezessete|dezoito|dezenove)'
  r'\s+(?:reais|real)\b',
);

int _priceCents(RegExpMatch match) {
  final digits = match.group(1);
  if (digits != null) {
    final value = double.parse(digits.replaceAll(',', '.'));
    return (value * 100).round();
  }
  return _wordsToReais(match.group(2)!) * 100;
}

int _wordsToReais(String words) {
  const ones = {
    'um': 1,
    'uma': 1,
    'dois': 2,
    'duas': 2,
    'tres': 3,
    'quatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'oito': 8,
    'nove': 9,
    'dez': 10,
    'onze': 11,
    'doze': 12,
    'treze': 13,
    'quatorze': 14,
    'catorze': 14,
    'quinze': 15,
    'dezesseis': 16,
    'dezessete': 17,
    'dezoito': 18,
    'dezenove': 19,
  };
  const tens = {
    'vinte': 20,
    'trinta': 30,
    'quarenta': 40,
    'cinquenta': 50,
    'sessenta': 60,
    'setenta': 70,
    'oitenta': 80,
    'noventa': 90,
    'cem': 100,
  };
  final parts = words.split(' e ');
  if (parts.length == 2) {
    return (tens[parts[0]] ?? 0) + (ones[parts[1]] ?? 0);
  }
  return ones[words] ?? tens[words] ?? 0;
}

VoicePriceBasis? _priceBasis(String text) {
  if (RegExp(r'\b(?:no total|o total|pelo total|preco total)\b')
      .hasMatch(text)) {
    return VoicePriceBasis.total;
  }
  if (RegExp(
    r'\b(?:por quilo|o quilo|por kg|o kg|cada quilo|cada kg|preco do quilo|preco por quilo)\b',
  ).hasMatch(text)) {
    return VoicePriceBasis.perUnit;
  }
  return null;
}

const _visitPhrases = [
  'nesse cliente',
  'nesta cliente',
  'neste cliente',
  'nessa cliente',
  'desse cliente',
  'desta cliente',
  'deste cliente',
  'dessa cliente',
  'esse cliente',
  'essa cliente',
  'este cliente',
  'esta cliente',
  'o cliente',
  'a cliente',
  'ele',
  'ela',
  'nessa nota',
  'nesta nota',
  'desta nota',
  'dessa nota',
  'essa nota',
  'esta nota',
  'a nota',
];

String _withoutVisit(String text) {
  var value = ' $text ';
  for (final phrase in _visitPhrases) {
    value = value.replaceAll(' $phrase ', ' ');
  }
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _visitCue(String? value) {
  if (value == null || value.isEmpty) return false;
  return _visitPhrases.contains(value);
}

String? _consultCustomer(String text) {
  const prefixes = [
    'qual a divida da ',
    'qual a divida de ',
    'qual o saldo da ',
    'qual o saldo de ',
    'consulta a conta da ',
    'consultar a conta da ',
    'ver a conta da ',
    'quanto a ',
    'quanto o ',
    'quanto ',
  ];
  for (final prefix in prefixes) {
    if (!text.startsWith(prefix)) continue;
    var customer = text.substring(prefix.length).trim();
    for (final suffix in [' me deve', ' deve', ' esta devendo']) {
      if (customer.endsWith(suffix)) {
        customer = customer
            .substring(0, customer.length - suffix.length)
            .trim();
      }
    }
    if (customer.startsWith('a ')) customer = customer.substring(2);
    if (customer.startsWith('o ')) customer = customer.substring(2);
    return customer.isEmpty ? null : customer;
  }
  return null;
}

({double? quantity, VoiceUnit? unit, String rest}) _takeAmount(String input) {
  var rest = input;
  double? quantity;
  final number = RegExp(
    r'^(?:(\d+(?:[.,]\d+)?)|(um|uma|dois|duas|tres|quatro|cinco|meio))\b',
  ).firstMatch(rest);
  if (number != null) {
    quantity = _number(number.group(1) ?? number.group(2)!);
    rest = rest.substring(number.end).trim();
  }
  VoiceUnit? unit;
  final unitMatch = RegExp(
    r'^(quilo|quilos|kg|quilograma|quilogramas|unidade|unidades|un|maca|macos|maco|caixa|caixas|duzia|duzias)\b',
  ).firstMatch(rest);
  if (unitMatch != null) {
    unit = _unit(unitMatch.group(1)!);
    rest = rest.substring(unitMatch.end).trim();
  }
  return (quantity: quantity, unit: unit, rest: rest);
}

double _number(String raw) {
  return switch (raw) {
    'um' || 'uma' => 1,
    'dois' || 'duas' => 2,
    'tres' => 3,
    'quatro' => 4,
    'cinco' => 5,
    'meio' => 0.5,
    _ => double.parse(raw.replaceAll(',', '.')),
  };
}

VoiceUnit _unit(String raw) {
  return switch (raw) {
    'unidade' || 'unidades' || 'un' => VoiceUnit.piece,
    'maca' || 'macos' || 'maco' => VoiceUnit.bunch,
    'caixa' || 'caixas' => VoiceUnit.box,
    'duzia' || 'duzias' => VoiceUnit.dozen,
    _ => VoiceUnit.kilogram,
  };
}

const _tens = {
  'vinte',
  'trinta',
  'quarenta',
  'cinquenta',
  'sessenta',
  'setenta',
  'oitenta',
  'noventa',
};

List<String> _splitItems(String text) {
  final parts = <String>[];
  var start = 0;
  for (final match in RegExp(r'\s+e\s+').allMatches(text)) {
    final before = text.substring(start, match.start).trim();
    final word = before.split(' ').last;
    if (_tens.contains(word)) continue;
    if (before.isNotEmpty) parts.add(before);
    start = match.end;
  }
  final tail = text.substring(start).trim();
  if (tail.isNotEmpty) parts.add(tail);
  return parts;
}

VoiceItem _item(String part) {
  final price = _extractPrice(part);
  var rest = price.rest;
  final amount = _takeAmount(rest);
  rest = amount.rest;
  if (rest.startsWith('de ')) rest = rest.substring(3).trim();
  final product = _singular(rest.trim());
  return VoiceItem(
    productQuery: product.isEmpty ? null : product,
    quantity: amount.quantity,
    unit: amount.unit,
    priceCents: price.cents,
    priceBasis:
        price.basis ??
        (price.cents != null && amount.quantity != null
            ? VoicePriceBasis.total
            : null),
  );
}

String _singular(String value) {
  final words = value.split(' ');
  if (words.isEmpty) return value;
  final last = words.last;
  if (last.length > 4 && last.endsWith('s') && !last.endsWith('ss')) {
    words[words.length - 1] = last.substring(0, last.length - 1);
  }
  return words.join(' ');
}

/// Fills the missing piece of [pending] without dropping what was understood.
///
/// A new add, debt question or unsupported phrase replaces the pending command.
VoiceCommand continueVoiceCommand(VoiceCommand pending, String reply) {
  final folded = foldVoice(reply);
  if (folded == 'cancelar' || folded == 'cancela') {
    return VoiceCommand(
      intent: VoiceIntent.unclear,
      transcript: reply,
      reply: 'Cancelado.',
    );
  }
  if (pending.intent == VoiceIntent.reviewDelivery) {
    if (folded == 'confirmar' || folded == 'confirma' || folded == 'confirmo') {
      return pending.copyWith(accepted: true, gap: VoiceGap.none);
    }
    if (folded == 'corrigir' || folded == 'corrija') {
      return VoiceCommand(
        intent: VoiceIntent.unclear,
        transcript: reply,
        reply: 'O que quer corrigir?',
        customerId: pending.customerId,
      );
    }
    final freshReview = interpretVoice(reply);
    if (freshReview.intent == VoiceIntent.unclear) return pending;
    return freshReview;
  }
  if (folded == 'trocar de cliente' || folded == 'corrigir') {
    return pending.copyWith(
      clearCustomerId: true,
      clearCustomerQuery: true,
      clearReview: true,
      gap: VoiceGap.customer,
    );
  }
  if (pending.gap == VoiceGap.due &&
      (folded == 'sim' || folded == 'isso' || folded == 'pode') &&
      pending.dueOn != null) {
    return pending.copyWith(gap: VoiceGap.none);
  }
  final fresh = interpretVoice(reply);
  if (fresh.intent == VoiceIntent.setDueDate ||
      fresh.intent == VoiceIntent.arrangePayment ||
      fresh.intent == VoiceIntent.reviewDelivery) {
    return fresh;
  }
  if (pending.items.any((item) => item.gap != VoiceGap.none) &&
      fresh.intent != VoiceIntent.addDraftItem &&
      fresh.intent != VoiceIntent.repriceDraftItem &&
      fresh.intent != VoiceIntent.consultAccount &&
      fresh.intent != VoiceIntent.unsupported) {
    return _fillItem(pending, folded);
  }
  if (pending.gap == VoiceGap.none ||
      fresh.intent == VoiceIntent.addDraftItem ||
      fresh.intent == VoiceIntent.repriceDraftItem ||
      fresh.intent == VoiceIntent.consultAccount ||
      fresh.intent == VoiceIntent.unsupported) {
    return fresh;
  }
  final text = foldVoice(reply);
  return switch (pending.gap) {
    VoiceGap.customer => pending.copyWith(
      customerQuery: text,
      clearCustomerId: true,
      gap: VoiceGap.none,
    ),
    VoiceGap.product => pending.copyWith(
      productQuery: text,
      clearProductId: true,
      gap: VoiceGap.none,
    ),
    VoiceGap.quantity || VoiceGap.unit => _withQuantity(pending, text),
    VoiceGap.price => _withPrice(pending, text),
    VoiceGap.due => interpretVoice(text),
    VoiceGap.payment => _withPayment(pending, text),
    VoiceGap.none => fresh,
  };
}

VoiceCommand _withPayment(VoiceCommand pending, String text) {
  var settlement = pending.settlement;
  if (text.contains('dinheiro')) settlement = 'cash';
  if (text.contains('pix') && !_promisedPix(text)) settlement = 'pix';
  if (_promisedPix(text)) {
    return VoiceCommand(
      intent: VoiceIntent.arrangePayment,
      transcript: text,
      settlement: 'promised',
      reply: 'O Pix ainda não entrou. Nada foi recebido.',
    );
  }
  final price = _extractPrice(text);
  final amount = price.cents ?? pending.priceCents;
  final ready = settlement != null && (amount != null || pending.payAll);
  return pending.copyWith(
    settlement: settlement,
    priceCents: amount,
    gap: ready ? VoiceGap.none : VoiceGap.payment,
  );
}

VoiceCommand _fillItem(VoiceCommand pending, String text) {
  final index = pending.items.indexWhere((item) => item.gap != VoiceGap.none);
  final at = index < 0 ? pending.items.length - 1 : index;
  final amount = _takeAmount(text);
  final current = pending.items[at];
  final filled = current.copyWith(
    quantity: amount.quantity ?? current.quantity,
    unit: amount.unit,
    clearUnit: amount.unit == null && amount.quantity != null,
    gap: VoiceGap.none,
  );
  final items = [...pending.items];
  items[at] = filled;
  return pending.copyWith(items: items, gap: VoiceGap.none);
}

VoiceCommand _withPrice(VoiceCommand pending, String text) {
  final price = _extractPrice(text);
  final basis = price.basis ?? _priceBasis(text);
  final source = price.cents == null ? text : price.rest;
  final amount = _takeAmount(source);
  return pending.copyWith(
    priceCents: price.cents,
    priceBasis: basis,
    quantity: amount.quantity,
    unit: amount.unit,
    clearUnit: amount.unit == null && amount.quantity != null,
    gap: VoiceGap.none,
  );
}

VoiceCommand _withQuantity(VoiceCommand pending, String text) {
  final amount = _takeAmount(text);
  if (amount.quantity == null && amount.unit == null) return pending;
  return pending.copyWith(
    quantity: amount.quantity,
    unit: amount.unit,
    clearUnit: amount.unit == null,
    gap: VoiceGap.none,
  );
}
