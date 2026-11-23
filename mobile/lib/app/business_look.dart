import 'package:flutter/widgets.dart';

/// One suggested catalog category for the signed-in business.
class PouCategorySuggestion {
  const PouCategorySuggestion({required this.id, required this.label});

  final String id;
  final String label;
}

/// Chrome for the signed-in business.
///
/// Hortifruti keeps the leaf photos. Cleaning uses the petrol water photos.
/// Marmitas uses the graphite tray photos. Pizzas uses the red crust photos.
/// Lanches uses the toasted burger photos. Bolos de pote uses the cocoa cups.
/// Every other type stays on the flat brand green.
enum PouChrome { botanical, cleaning, meals, pizzas, snacks, cakes, plain }

/// Themes the header can switch. Other business types keep [PouChrome.plain]
/// until someone picks one of these.
const pouSelectableThemes = <PouChrome>[
  PouChrome.botanical,
  PouChrome.cleaning,
  PouChrome.meals,
  PouChrome.pizzas,
  PouChrome.snacks,
  PouChrome.cakes,
];

/// Labels shared by the theme menu and the capsule's accessibility name.
String pouThemeLabel(PouChrome chrome) {
  return switch (chrome) {
    PouChrome.botanical => 'Hortifruti',
    PouChrome.cleaning => 'Produtos de limpeza',
    PouChrome.meals => 'Marmitas',
    PouChrome.pizzas => 'Pizzas',
    PouChrome.snacks => 'Lanches',
    PouChrome.cakes => 'Bolos de pote',
    PouChrome.plain => 'PouApp',
  };
}

/// Single letter shown in the home capsule.
String pouThemeLetter(PouChrome chrome) {
  return switch (chrome) {
    PouChrome.botanical => 'H',
    PouChrome.cleaning => 'L',
    PouChrome.meals => 'M',
    PouChrome.pizzas => 'P',
    PouChrome.snacks => 'X',
    PouChrome.cakes => 'B',
    PouChrome.plain => 'P',
  };
}

/// Visual choices for the signed-in business.
///
/// Absent means the botanical hortifruti chrome already used by the app.
class BusinessLook extends InheritedWidget {
  const BusinessLook({
    super.key,
    required this.chrome,
    required this.suggestions,
    required super.child,
  });

  final PouChrome chrome;
  final List<PouCategorySuggestion> suggestions;

  bool get botanical => chrome == PouChrome.botanical;

  static BusinessLook? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BusinessLook>();
  }

  static PouChrome chromeOf(BuildContext context) {
    return maybeOf(context)?.chrome ?? PouChrome.botanical;
  }

  static bool botanicalOf(BuildContext context) {
    return chromeOf(context) == PouChrome.botanical;
  }

  static List<PouCategorySuggestion> suggestionsOf(BuildContext context) {
    return maybeOf(context)?.suggestions ?? const [];
  }

  @override
  bool updateShouldNotify(BusinessLook oldWidget) {
    return chrome != oldWidget.chrome || suggestions != oldWidget.suggestions;
  }
}
