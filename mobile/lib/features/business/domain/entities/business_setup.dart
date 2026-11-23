import 'package:equatable/equatable.dart';

/// Stable business type. Labels shown on screen live apart from these ids.
enum BusinessKind {
  hortifruti,
  meals,
  pizzas,
  snacks,
  cakes,
  grocery,
  cleaning,
  apparel,
  mixed,
  other,
}

enum BusinessSetupStatus { pending, configured }

class BusinessCategory extends Equatable {
  const BusinessCategory({required this.id, required this.label});

  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

class BusinessSetup extends Equatable {
  const BusinessSetup({
    required this.userId,
    required this.status,
    required this.categories,
    this.kind,
  });

  final String userId;
  final BusinessSetupStatus status;
  final BusinessKind? kind;
  final List<BusinessCategory> categories;

  bool get isConfigured =>
      status == BusinessSetupStatus.configured && kind != null;

  bool get botanical => kind == BusinessKind.hortifruti;

  factory BusinessSetup.pending(String userId) {
    return BusinessSetup(
      userId: userId,
      status: BusinessSetupStatus.pending,
      categories: const [],
    );
  }

  factory BusinessSetup.configured({
    required String userId,
    required BusinessKind kind,
  }) {
    return BusinessSetup(
      userId: userId,
      status: BusinessSetupStatus.configured,
      kind: kind,
      categories: categorySuggestionsFor(kind),
    );
  }

  /// Account that already used PouApp before this step existed.
  factory BusinessSetup.legacy(String userId) {
    return BusinessSetup.configured(
      userId: userId,
      kind: BusinessKind.hortifruti,
    );
  }

  @override
  List<Object?> get props => [userId, status, kind, categories];
}

const businessKindOptions = <BusinessKind>[
  BusinessKind.hortifruti,
  BusinessKind.meals,
  BusinessKind.pizzas,
  BusinessKind.snacks,
  BusinessKind.cakes,
  BusinessKind.grocery,
  BusinessKind.cleaning,
  BusinessKind.apparel,
  BusinessKind.mixed,
  BusinessKind.other,
];

String businessKindLabel(BusinessKind kind) {
  return switch (kind) {
    BusinessKind.hortifruti => 'Hortifruti',
    BusinessKind.meals => 'Marmitas',
    BusinessKind.pizzas => 'Pizzas',
    BusinessKind.snacks => 'Lanches',
    BusinessKind.cakes => 'Bolos de pote',
    BusinessKind.grocery => 'Mercearia e cestas básicas',
    BusinessKind.cleaning => 'Produtos de limpeza',
    BusinessKind.apparel => 'Roupas e calçados',
    BusinessKind.mixed => 'Loja mista',
    BusinessKind.other => 'Outro',
  };
}

BusinessKind? businessKindFromId(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final kind in BusinessKind.values) {
    if (kind.name == id) return kind;
  }
  return null;
}

const _suggestions = <BusinessKind, List<BusinessCategory>>{
  BusinessKind.hortifruti: [
    BusinessCategory(id: 'hortifruti.frutas', label: 'Frutas'),
    BusinessCategory(id: 'hortifruti.verduras', label: 'Verduras'),
    BusinessCategory(id: 'hortifruti.legumes', label: 'Legumes'),
    BusinessCategory(id: 'hortifruti.temperos', label: 'Temperos'),
    BusinessCategory(id: 'hortifruti.ovos', label: 'Ovos'),
  ],
  BusinessKind.meals: [
    BusinessCategory(id: 'marmitas.tradicionais', label: 'Tradicionais'),
    BusinessCategory(id: 'marmitas.fitness', label: 'Fitness'),
    BusinessCategory(id: 'marmitas.vegetarianas', label: 'Vegetarianas'),
    BusinessCategory(id: 'marmitas.sobremesas', label: 'Sobremesas'),
    BusinessCategory(id: 'marmitas.bebidas', label: 'Bebidas'),
  ],
  BusinessKind.pizzas: [
    BusinessCategory(id: 'pizzas.salgadas', label: 'Salgadas'),
    BusinessCategory(id: 'pizzas.doces', label: 'Doces'),
    BusinessCategory(id: 'pizzas.especiais', label: 'Especiais'),
    BusinessCategory(id: 'pizzas.bebidas', label: 'Bebidas'),
  ],
  BusinessKind.snacks: [
    BusinessCategory(id: 'lanches.hamburgueres', label: 'Hambúrgueres'),
    BusinessCategory(id: 'lanches.cachorros', label: 'Cachorros-quentes'),
    BusinessCategory(id: 'lanches.sanduiches', label: 'Sanduíches'),
    BusinessCategory(id: 'lanches.salgados', label: 'Salgados'),
    BusinessCategory(id: 'lanches.acompanhamentos', label: 'Acompanhamentos'),
  ],
  BusinessKind.cakes: [
    BusinessCategory(id: 'bolos.classicos', label: 'Clássicos'),
    BusinessCategory(id: 'bolos.frutas', label: 'Frutas'),
    BusinessCategory(id: 'bolos.especiais', label: 'Especiais'),
  ],
  BusinessKind.grocery: [
    BusinessCategory(id: 'mercearia.arroz-feijao', label: 'Arroz e feijão'),
    BusinessCategory(id: 'mercearia.oleos', label: 'Óleos e gorduras'),
    BusinessCategory(id: 'mercearia.massas', label: 'Massas'),
    BusinessCategory(id: 'mercearia.higiene', label: 'Higiene'),
    BusinessCategory(id: 'mercearia.cestas', label: 'Cestas básicas'),
  ],
  BusinessKind.cleaning: [
    BusinessCategory(id: 'limpeza.roupas', label: 'Roupas'),
    BusinessCategory(id: 'limpeza.casa', label: 'Casa'),
    BusinessCategory(id: 'limpeza.loucas', label: 'Louças'),
    BusinessCategory(id: 'limpeza.desinfetantes', label: 'Desinfetantes'),
  ],
  BusinessKind.apparel: [
    BusinessCategory(id: 'roupas.femininas', label: 'Roupas femininas'),
    BusinessCategory(id: 'roupas.masculinas', label: 'Roupas masculinas'),
    BusinessCategory(id: 'roupas.infantis', label: 'Roupas infantis'),
    BusinessCategory(id: 'roupas.calcados', label: 'Calçados'),
    BusinessCategory(id: 'roupas.acessorios', label: 'Acessórios'),
  ],
  BusinessKind.mixed: [
    BusinessCategory(id: 'mista.hortifruti', label: 'Hortifruti'),
    BusinessCategory(id: 'mista.mercearia', label: 'Mercearia'),
    BusinessCategory(id: 'mista.limpeza', label: 'Limpeza'),
    BusinessCategory(id: 'mista.outros', label: 'Outros'),
  ],
  BusinessKind.other: [BusinessCategory(id: 'outro.geral', label: 'Geral')],
};

List<BusinessCategory> categorySuggestionsFor(BusinessKind kind) {
  return List<BusinessCategory>.of(_suggestions[kind] ?? const []);
}
