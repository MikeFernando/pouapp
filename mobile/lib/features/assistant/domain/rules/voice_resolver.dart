import '../../../catalog/domain/entities/catalog.dart';
import '../entities/voice_command.dart';
import '../voice_text.dart';

class VoiceResolution {
  const VoiceResolution({
    this.customer,
    this.customers = const [],
    this.product,
    this.products = const [],
    this.quantity,
    this.message,
    this.assumedOne = false,
    this.needsPriceBasis = false,
    this.needsUnit = false,
  });

  final VoicePerson? customer;
  final List<VoicePerson> customers;
  final VoiceGoods? product;
  final List<VoiceGoods> products;

  /// Base quantity: grams for kilograms, whole count otherwise.
  final int? quantity;
  final String? message;

  /// One unit was used because the phrase named a price and no quantity.
  final bool assumedOne;

  /// A spoken price on a kilogram product still needs per-kilo or total.
  final bool needsPriceBasis;
  final bool needsUnit;

  bool get readyToAdd =>
      customer != null &&
      product != null &&
      quantity != null &&
      message == null &&
      !needsPriceBasis;

  bool get readyToReprice =>
      customer != null &&
      product != null &&
      message == null &&
      !needsPriceBasis;
}

VoiceResolution resolveVoice({
  required VoiceCommand command,
  required List<VoicePerson> people,
  required List<VoiceGoods> goods,
  required List<VoiceAlias> aliases,
}) {
  final customers = _people(command, people, aliases);
  final customer = customers.length == 1 ? customers.single : null;
  if (command.intent == VoiceIntent.consultAccount) {
    if (customer == null) {
      return VoiceResolution(
        customers: customers,
        message: customers.isEmpty
            ? _missingCustomer(command.customerQuery, aliases)
            : 'Encontrei mais de uma cliente. Qual delas?',
      );
    }
    return VoiceResolution(customer: customer);
  }
  final priced =
      command.intent == VoiceIntent.addDraftItem ||
      command.intent == VoiceIntent.repriceDraftItem;
  if (!priced) {
    return const VoiceResolution();
  }
  final products = _goods(command, goods);
  final product = products.length == 1 ? products.single : null;
  if (customer == null || product == null) {
    return VoiceResolution(
      customer: customer,
      customers: customers,
      product: product,
      products: products,
      message: _missingPiece(
        command: command,
        customers: customers,
        products: products,
        aliases: aliases,
      ),
    );
  }
  if (command.intent == VoiceIntent.repriceDraftItem) {
    if (command.priceCents == null) {
      return VoiceResolution(
        customer: customer,
        product: product,
        message: 'Qual o preço de ${product.name}?',
      );
    }
    if (product.unit == CatalogUnit.kilogram && command.priceBasis == null) {
      return VoiceResolution(
        customer: customer,
        product: product,
        needsPriceBasis: true,
        message:
            '${_reaisLabel(command.priceCents!)} de ${product.name} é o preço do quilo ou o total?',
      );
    }
    return VoiceResolution(customer: customer, product: product);
  }
  final quantity = _quantity(command, product);
  if (quantity.message != null) {
    final askingUnit =
        command.quantity != null &&
        command.unit == null &&
        product.unit == CatalogUnit.kilogram &&
        command.priceCents == null;
    final askingPrice =
        product.unit == CatalogUnit.kilogram &&
        command.priceCents != null &&
        command.priceBasis == null;
    return VoiceResolution(
      customer: customer,
      product: product,
      needsPriceBasis: askingPrice,
      needsUnit: askingUnit,
      message: quantity.message,
    );
  }
  if (command.priceCents != null &&
      product.unit == CatalogUnit.kilogram &&
      command.priceBasis == null) {
    return VoiceResolution(
      customer: customer,
      product: product,
      quantity: quantity.amount,
      needsPriceBasis: true,
      message:
          '${_reaisLabel(command.priceCents!)} de ${product.name} é o preço do quilo ou o total?',
    );
  }
  return VoiceResolution(
    customer: customer,
    product: product,
    quantity: quantity.amount,
    assumedOne: quantity.assumed,
  );
}

List<VoicePerson> _people(
  VoiceCommand command,
  List<VoicePerson> people,
  List<VoiceAlias> aliases,
) {
  if (command.customerId != null) {
    return [
      for (final person in people)
        if (person.id == command.customerId) person,
    ];
  }
  final query = foldVoice(command.customerQuery ?? '');
  if (query.isEmpty) return const [];
  final alias = aliases.where(
    (item) =>
        item.kind == VoiceAliasKind.customer && foldVoice(item.alias) == query,
  );
  if (alias.length == 1) {
    return [
      for (final person in people)
        if (person.id == alias.single.target) person,
    ];
  }
  final split = _place(query, people, aliases);
  return [
    for (final person in people)
      if (_personMatches(person, split.name, split.neighborhood)) person,
  ];
}

({String name, String? neighborhood}) _place(
  String query,
  List<VoicePerson> people,
  List<VoiceAlias> aliases,
) {
  final alias = _neighborhood(query, aliases);
  if (alias.neighborhood != null) return alias;
  for (final marker in [' do ', ' da ', ' de ', ' no ']) {
    final at = query.lastIndexOf(marker);
    if (at <= 0) continue;
    final name = query.substring(0, at).trim();
    final place = query.substring(at + marker.length).trim();
    if (name.isEmpty || place.isEmpty) continue;
    final known = people.any(
      (person) => _sameNeighborhood(person.neighborhood, place),
    );
    if (!known) continue;
    return (name: name, neighborhood: place);
  }
  return (name: query, neighborhood: null);
}

({String name, String? neighborhood}) _neighborhood(
  String query,
  List<VoiceAlias> aliases,
) {
  final parts = query.split(' ').where((part) => part.isNotEmpty).toList();
  if (parts.length < 2) return (name: query, neighborhood: null);
  final alias = aliases.where(
    (item) =>
        item.kind == VoiceAliasKind.neighborhood &&
        foldVoice(item.alias) == parts.last,
  );
  if (alias.length != 1) return (name: query, neighborhood: null);
  return (
    name: parts.sublist(0, parts.length - 1).join(' '),
    neighborhood: alias.single.target,
  );
}

bool _personMatches(VoicePerson person, String name, String? neighborhood) {
  final tokens = name.split(' ').where((part) => part.isNotEmpty);
  if (tokens.isEmpty) return false;
  if (!tokens.every((token) => voiceTokenHits(person.name, token))) {
    return false;
  }
  if (neighborhood == null) return true;
  return _sameNeighborhood(person.neighborhood, neighborhood);
}

bool _sameNeighborhood(String? neighborhood, String wanted) {
  final hood = foldVoice(neighborhood ?? '');
  final target = foldVoice(wanted);
  if (hood.isEmpty || target.isEmpty) return false;
  return hood == target || hood.contains(target);
}

List<VoiceGoods> _goods(VoiceCommand command, List<VoiceGoods> goods) {
  if (command.productId != null) {
    return [
      for (final item in goods)
        if (item.id == command.productId && item.active) item,
    ];
  }
  final query = foldVoice(command.productQuery ?? '');
  if (query.isEmpty) return const [];
  final tokens = query.split(' ');
  return [
    for (final item in goods)
      if (item.active &&
          tokens.every((token) => voiceTokenHits(item.name, token)))
        item,
  ];
}

({int? amount, String? message, bool assumed}) _quantity(
  VoiceCommand command,
  VoiceGoods product,
) {
  final spoken = command.unit;
  final display = command.quantity;
  if (display == null && spoken == null && command.priceCents != null) {
    if (product.unit == CatalogUnit.kilogram) {
      final message = command.priceBasis == null
          ? '${product.name} é por quilo. Quantos quilos, e ${_reaisLabel(command.priceCents!)} é o preço do quilo ou o total?'
          : 'Quantos quilos de ${product.name}?';
      return (amount: null, assumed: false, message: message);
    }
    return (amount: 1, message: null, assumed: true);
  }
  if (display != null &&
      spoken == null &&
      command.priceCents != null &&
      product.unit != CatalogUnit.kilogram) {
    return _wholeCount(display, product);
  }
  if (display != null &&
      spoken == null &&
      command.priceCents == null &&
      product.unit == CatalogUnit.kilogram) {
    final whole = display.round();
    final units = switch (whole) {
      1 => 'uma unidade',
      2 => 'duas unidades',
      _ => '$whole unidades',
    };
    final kilos = switch (whole) {
      1 => 'um quilo',
      2 => 'dois quilos',
      _ => '$whole quilos',
    };
    return (
      amount: null,
      assumed: false,
      message: '${product.name}: $units ou $kilos?',
    );
  }
  if (display == null || spoken == null) {
    return (
      amount: null,
      assumed: false,
      message: 'Qual a quantidade e a unidade de ${product.name}?',
    );
  }
  if (display <= 0) {
    return (
      amount: null,
      assumed: false,
      message: 'A quantidade precisa ser maior que zero.',
    );
  }
  final expected = switch (product.unit) {
    CatalogUnit.kilogram => VoiceUnit.kilogram,
    CatalogUnit.piece => VoiceUnit.piece,
    CatalogUnit.bunch => VoiceUnit.bunch,
    CatalogUnit.box => VoiceUnit.box,
    CatalogUnit.dozen => VoiceUnit.dozen,
  };
  if (spoken == VoiceUnit.piece && product.unit == CatalogUnit.kilogram) {
    return _wholeCount(display, product);
  }
  if (spoken != expected) {
    return (
      amount: null,
      assumed: false,
      message:
          '${product.name} é vendido por ${_unitLabel(product.unit)}. Diga a quantidade nessa unidade.',
    );
  }
  if (product.unit == CatalogUnit.kilogram) {
    final grams = (display * 1000).round();
    if (grams <= 0) {
      return (
        amount: null,
        assumed: false,
        message: 'A quantidade precisa ser maior que zero.',
      );
    }
    return (amount: grams, message: null, assumed: false);
  }
  return _wholeCount(display, product);
}

({int? amount, String? message, bool assumed}) _wholeCount(
  double display,
  VoiceGoods product,
) {
  if (display <= 0) {
    return (
      amount: null,
      assumed: false,
      message: 'A quantidade precisa ser maior que zero.',
    );
  }
  if ((display - display.roundToDouble()).abs() > 0.000001) {
    return (
      amount: null,
      assumed: false,
      message: '${product.name} não aceita quantidade fracionada.',
    );
  }
  return (amount: display.round(), message: null, assumed: false);
}

String _reaisLabel(int cents) {
  if (cents < 0 || cents % 100 != 0) return 'esse valor';
  final reais = cents ~/ 100;
  final words = _reaisWords(reais);
  if (words == null) return 'R\$ ${reais.toString()}';
  return reais == 1 ? '$words real' : '$words reais';
}

String? _reaisWords(int reais) {
  const ones = [
    'zero',
    'um',
    'dois',
    'três',
    'quatro',
    'cinco',
    'seis',
    'sete',
    'oito',
    'nove',
    'dez',
    'onze',
    'doze',
    'treze',
    'quatorze',
    'quinze',
    'dezesseis',
    'dezessete',
    'dezoito',
    'dezenove',
  ];
  const tens = [
    '',
    '',
    'vinte',
    'trinta',
    'quarenta',
    'cinquenta',
    'sessenta',
    'setenta',
    'oitenta',
    'noventa',
  ];
  if (reais < 0 || reais > 100) return null;
  if (reais < ones.length) return ones[reais];
  if (reais == 100) return 'cem';
  final ten = tens[reais ~/ 10];
  final one = reais % 10;
  if (one == 0) return ten;
  return '$ten e ${ones[one]}';
}

String _unitLabel(CatalogUnit unit) {
  return switch (unit) {
    CatalogUnit.kilogram => 'quilograma',
    CatalogUnit.piece => 'unidade',
    CatalogUnit.bunch => 'maço',
    CatalogUnit.box => 'caixa',
    CatalogUnit.dozen => 'dúzia',
  };
}

String _missingCustomer(String? query, List<VoiceAlias> aliases) {
  final text = foldVoice(query ?? '');
  final parts = text.split(' ').where((part) => part.isNotEmpty).toList();
  if (parts.length >= 2) {
    final known = aliases.any(
      (item) =>
          item.kind == VoiceAliasKind.neighborhood &&
          foldVoice(item.alias) == parts.last,
    );
    if (!known && parts.last.length <= 3) {
      return 'Não encontrei essa cliente. ${parts.last.toUpperCase()} não é uma abreviação cadastrada.';
    }
  }
  return 'Não encontrei essa cliente.';
}

String _missingPiece({
  required VoiceCommand command,
  required List<VoicePerson> customers,
  required List<VoiceGoods> products,
  required List<VoiceAlias> aliases,
}) {
  if ((command.customerQuery ?? '').isEmpty) {
    return 'Para qual cliente é esse produto?';
  }
  if (customers.isEmpty) {
    return _missingCustomer(command.customerQuery, aliases);
  }
  if (customers.length > 1) return 'Encontrei mais de uma cliente. Qual delas?';
  if ((command.productQuery ?? '').isEmpty) {
    return 'Qual produto entra na nota?';
  }
  if (products.isEmpty) return 'Não encontrei esse produto.';
  return 'Encontrei mais de um produto. Qual deles?';
}
