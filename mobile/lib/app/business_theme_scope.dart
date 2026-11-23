import 'package:flutter/material.dart';

import '../features/auth/presentation/widgets/session_loading_view.dart';
import '../features/business/data/datasources/business_theme_store.dart';
import '../features/catalog/domain/repositories/catalog_repository.dart';
import '../injection_container.dart';
import 'business_look.dart';
import 'pou_app_colors.dart';

/// Holds the visual theme for the signed-in business.
///
/// The registered business type stays the fallback until a header choice is
/// saved. Customers and sales stay. The starter product list follows the
/// visible theme, and products added by hand stay on the phone.
class BusinessThemeScope extends StatefulWidget {
  const BusinessThemeScope({
    super.key,
    required this.userId,
    required this.fallback,
    required this.suggestions,
    required this.child,
    this.store,
  });

  final String userId;
  final PouChrome fallback;
  final List<PouCategorySuggestion> suggestions;
  final Widget child;
  final BusinessThemeStore? store;

  static BusinessThemeScopeState of(BuildContext context) {
    final state = context.findAncestorStateOfType<BusinessThemeScopeState>();
    assert(state != null, 'BusinessThemeScope is missing above this widget');
    return state!;
  }

  @override
  State<BusinessThemeScope> createState() => BusinessThemeScopeState();
}

class BusinessThemeScopeState extends State<BusinessThemeScope> {
  late PouChrome _chrome;
  var _ready = false;

  PouChrome get chrome => _chrome;

  @override
  void initState() {
    super.initState();
    _chrome = _storedOrFallback();
    if (sl.isRegistered<CatalogRepository>()) {
      _prepare();
    } else {
      _ready = true;
    }
  }

  @override
  void didUpdateWidget(covariant BusinessThemeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.fallback != widget.fallback) {
      _chrome = _storedOrFallback();
      if (sl.isRegistered<CatalogRepository>()) {
        _ready = false;
        _prepare();
      }
    }
  }

  Future<void> _prepare() async {
    final chrome = _chrome;
    await _alignCatalog(chrome);
    if (!mounted || chrome != _chrome) return;
    setState(() => _ready = true);
  }

  Future<void> select(PouChrome chrome) async {
    if (!pouSelectableThemes.contains(chrome)) return;
    await _store()?.save(widget.userId, chrome);
    await _alignCatalog(chrome);
    if (!mounted || _chrome == chrome) return;
    setState(() => _chrome = chrome);
  }

  Future<void> _alignCatalog(PouChrome chrome) async {
    if (!sl.isRegistered<CatalogRepository>()) return;
    final catalog = sl<CatalogRepository>();
    switch (chrome) {
      case PouChrome.meals:
        await catalog.useMealsCatalog();
      case PouChrome.pizzas:
        await catalog.usePizzasCatalog();
      case PouChrome.snacks:
        await catalog.useSnacksCatalog();
      case PouChrome.cakes:
        await catalog.useCakesCatalog();
      case PouChrome.cleaning:
        await catalog.useCleaningCatalog();
      case PouChrome.botanical:
        await catalog.useProduceCatalog();
      case PouChrome.plain:
        break;
    }
  }

  BusinessThemeStore? _store() {
    return widget.store ??
        (sl.isRegistered<BusinessThemeStore>()
            ? sl<BusinessThemeStore>()
            : null);
  }

  PouChrome _storedOrFallback() {
    final stored = _store()?.read(widget.userId);
    if (stored != null && pouSelectableThemes.contains(stored)) return stored;
    return widget.fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SessionLoadingView();
    return BusinessLook(
      chrome: _chrome,
      suggestions: widget.suggestions,
      child: _themed(context, _chrome, widget.child),
    );
  }

  Widget _themed(BuildContext context, PouChrome chrome, Widget child) {
    final theme = switch (chrome) {
      PouChrome.cleaning => cleaningTheme(Theme.of(context)),
      PouChrome.meals => mealsTheme(Theme.of(context)),
      PouChrome.pizzas => pizzasTheme(Theme.of(context)),
      PouChrome.snacks => snacksTheme(Theme.of(context)),
      PouChrome.cakes => cakesTheme(Theme.of(context)),
      PouChrome.botanical || PouChrome.plain => null,
    };
    if (theme == null) return child;
    return Theme(data: theme, child: child);
  }
}
