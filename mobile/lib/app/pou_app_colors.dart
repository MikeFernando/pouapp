import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'business_look.dart';

/// Brand chrome. Change this one value to recolor app bars, bottom nav,
/// primary buttons, FABs, and other filled actions across the app.
const pouBrand = Color(0xFF24623A);

/// Near black. Body text and icons on light surfaces.
const pouInk = Color(0xFF0E0D0F);

/// Light gray. Fields, chips, and secondary surfaces.
const pouSurface = Color(0xFFE9E8EB);

/// Off-white. Page backgrounds and text on brand fills.
const pouCanvas = Color(0xFFF6F5F7);

/// Mid green for success / secondary accents (not chrome).
const pouAccent = Color(0xFF34C759);

/// Lighter green at the top of the success gradient.
const pouAccentTop = Color(0xFF4AE06C);

/// Darker green at the bottom of the success gradient.
const pouAccentBottom = Color(0xFF2DBA52);

/// Success green gradient (receipts / positive states).
const pouAccentGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [pouAccentTop, pouAccentBottom],
);

/// Soft brand gradient for headers and primary chrome.
const pouBrandGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF2F7A4A), pouBrand],
);

/// App chrome alias — AppBars and older call sites. Points at [pouBrand].
const pouAppBlue = pouBrand;

/// Shared leaf photo used by the bottom nav and leaf AppBars.
const pouLeafBackgroundAsset = 'assets/bg-bottom-navigation.png';

/// Dark leaf tone behind rounded card reveals / system bars.
const pouLeafChrome = Color(0xFF163528);

/// Petrol blue sampled from the cleaning-business water photos.
const pouCleaning = Color(0xFF14556C);

/// Dark field of those photos, behind rounded card reveals and system bars.
const pouCleaningChrome = Color(0xFF0B3344);

/// Lighter petrol for gradients and secondary accents.
const pouCleaningLight = Color(0xFF1E7490);

/// Water photo for the cleaning bottom bar and leaf-style app bars.
const pouCleaningNavAsset = 'assets/images/cleaning-nav.jpg';

/// Water photo for the cleaning Nova Venda button (caustics on the right).
const pouCleaningSaleAsset = 'assets/images/cleaning-nova-venda.jpg';

const pouCleaningGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [pouCleaningLight, pouCleaning],
);

/// Graphite used by the marmita theme for buttons, the add button, and chrome.
const pouMeals = Color(0xFF292929);

/// Same graphite behind rounded card reveals and the system bar.
const pouMealsChrome = Color(0xFF292929);

/// Gold reserved for the active bottom tab in the marmita theme.
const pouMealsGold = Color(0xFFF3CD7D);

/// Slightly lifted graphite for secondary accents. Status colors stay separate.
const pouMealsLight = Color(0xFF3A3A3A);

/// Soft white for idle tab icons and labels on the marmita bar.
const pouMealsNavIdle = Color(0xE6FFFFFF);

/// Dark-slate marmita photo for the bottom bar.
const pouMealsNavAsset = 'assets/images/meals-nav.jpg';

/// Graphite field with the tray on the right, for the Nova Venda button.
const pouMealsSaleAsset = 'assets/images/meals-nova-venda.jpg';

/// Deep red sampled from the solid field of the pizza sale photo.
const pouPizzas = Color(0xFF8E1000);

/// Dark crust tone behind rounded card reveals and system bars.
const pouPizzasChrome = Color(0xFF510500);

/// Brighter red for gradients and secondary accents.
const pouPizzasLight = Color(0xFFB41608);

/// Pepperoni photo for the pizza bottom bar.
const pouPizzasNavAsset = 'assets/images/pizza-nav.jpg';

/// Red field with the crust on the right, for the pizza Nova Venda button.
const pouPizzasSaleAsset = 'assets/images/pizza-nova-venda.jpg';

/// Toasted amber sampled from the lanche sale photo, dark enough for white text.
const pouSnacks = Color(0xFF9A4E0C);

/// Darker bun tone behind rounded card reveals and the system bar.
const pouSnacksChrome = Color(0xFF5C2A08);

/// Brighter mustard for secondary accents.
const pouSnacksLight = Color(0xFFC47A22);

/// Burgers and fries for the lanche bottom bar.
const pouSnacksNavAsset = 'assets/images/snacks-nav.jpg';

/// Amber field with the burger on the right, for the lanche Nova Venda button.
const pouSnacksSaleAsset = 'assets/images/snacks-nova-venda.jpg';

/// Cocoa brown sampled from the bolo de pote sale photo.
const pouCakes = Color(0xFF4D1806);

/// Darker cocoa behind rounded card reveals and the system bar.
const pouCakesChrome = Color(0xFF3A1004);

/// Lifted cocoa for secondary accents.
const pouCakesLight = Color(0xFF7A3420);

/// Dessert cups for the bolo de pote bottom bar.
const pouCakesNavAsset = 'assets/images/cakes-nav.jpg';

/// Cocoa field with the brigadeiro cup on the right, for Nova Venda.
const pouCakesSaleAsset = 'assets/images/cakes-nova-venda.jpg';

/// Botanical photo still used by every business without its own sale image.
const pouBotanicalSaleAsset = 'assets/images/nova-venda-fundo-botanico.png';

/// Dark leaf tone behind the botanical Nova Venda button.
const pouBotanicalSaleFallback = Color(0xFF062E0C);

BoxDecoration pouAccentGradientDecoration({
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
}) {
  return BoxDecoration(gradient: pouAccentGradient, borderRadius: borderRadius);
}

BoxDecoration pouBrandGradientDecoration({
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
}) {
  return BoxDecoration(gradient: pouBrandGradient, borderRadius: borderRadius);
}

/// Hortifruti keeps the leaf chrome. Other business types use flat brand green.
bool pouBotanicalChrome(BuildContext context) {
  return BusinessLook.botanicalOf(context);
}

/// Photo, fallback color, and cart for the Nova Venda button.
class PouSaleLook {
  const PouSaleLook({
    required this.asset,
    required this.fallback,
    required this.whiteCart,
    this.icon,
    this.alignment = Alignment.centerRight,
  });

  final String asset;
  final Color fallback;
  final bool whiteCart;
  final IconData? icon;
  final Alignment alignment;
}

PouSaleLook pouSaleLook(BuildContext context) {
  return switch (BusinessLook.chromeOf(context)) {
    PouChrome.cleaning => const PouSaleLook(
      asset: pouCleaningSaleAsset,
      fallback: pouCleaningChrome,
      whiteCart: true,
    ),
    PouChrome.meals => const PouSaleLook(
      asset: pouMealsSaleAsset,
      fallback: pouMeals,
      whiteCart: true,
      alignment: Alignment.centerRight,
    ),
    PouChrome.pizzas => const PouSaleLook(
      asset: pouPizzasSaleAsset,
      fallback: pouPizzas,
      whiteCart: true,
      icon: Icons.local_pizza_outlined,
      alignment: Alignment.centerLeft,
    ),
    PouChrome.snacks => const PouSaleLook(
      asset: pouSnacksSaleAsset,
      fallback: pouSnacks,
      whiteCart: true,
      icon: Icons.lunch_dining_outlined,
      alignment: Alignment.centerRight,
    ),
    PouChrome.cakes => const PouSaleLook(
      asset: pouCakesSaleAsset,
      fallback: pouCakes,
      whiteCart: true,
      icon: Icons.cake_outlined,
      alignment: Alignment.centerRight,
    ),
    PouChrome.botanical || PouChrome.plain => const PouSaleLook(
      asset: pouBotanicalSaleAsset,
      fallback: pouBotanicalSaleFallback,
      whiteCart: false,
    ),
  };
}

/// Capsule colors for the home theme selector.
class PouThemeChip {
  const PouThemeChip({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

PouThemeChip pouThemeChip(PouChrome chrome) {
  return switch (chrome) {
    PouChrome.botanical || PouChrome.plain => const PouThemeChip(
      background: Color(0xFFD7F3E3),
      foreground: pouBrand,
    ),
    PouChrome.cleaning => const PouThemeChip(
      background: Color(0xFFD4F1F7),
      foreground: pouCleaning,
    ),
    PouChrome.meals => const PouThemeChip(
      background: Color(0xFFF6E7C3),
      foreground: pouMeals,
    ),
    PouChrome.pizzas => const PouThemeChip(
      background: Color(0xFFF8D6D4),
      foreground: pouPizzas,
    ),
    PouChrome.snacks => const PouThemeChip(
      background: Color(0xFFF8E6C8),
      foreground: pouSnacks,
    ),
    PouChrome.cakes => const PouThemeChip(
      background: Color(0xFFF6E0D6),
      foreground: pouCakes,
    ),
  };
}

/// Primary actions. Cleaning is petrol, marmitas is graphite, pizzas is red,
/// lanches is toasted amber, bolos de pote is cocoa.
Color pouThemeBrand(BuildContext context) {
  return switch (BusinessLook.chromeOf(context)) {
    PouChrome.cleaning => pouCleaning,
    PouChrome.meals => pouMeals,
    PouChrome.pizzas => pouPizzas,
    PouChrome.snacks => pouSnacks,
    PouChrome.cakes => pouCakes,
    PouChrome.botanical || PouChrome.plain => pouBrand,
  };
}

Color pouChromeColor(BuildContext context) {
  return switch (BusinessLook.chromeOf(context)) {
    PouChrome.botanical => pouLeafChrome,
    PouChrome.cleaning => pouCleaningChrome,
    PouChrome.meals => pouMealsChrome,
    PouChrome.pizzas => pouPizzasChrome,
    PouChrome.snacks => pouSnacksChrome,
    PouChrome.cakes => pouCakesChrome,
    PouChrome.plain => pouBrand,
  };
}

Widget pouChromeFill(BuildContext context) {
  return switch (BusinessLook.chromeOf(context)) {
    PouChrome.botanical => pouLeafBackdrop(),
    PouChrome.cleaning => pouCleaningBackdrop(),
    PouChrome.meals => pouMealsBackdrop(),
    PouChrome.pizzas => pouPizzasBackdrop(),
    PouChrome.snacks => pouSnacksBackdrop(),
    PouChrome.cakes => pouCakesBackdrop(),
    PouChrome.plain => const ColoredBox(color: pouBrand),
  };
}

/// Theme override for a business with its own brand color.
ThemeData pouBrandedTheme(
  ThemeData base, {
  required Color brand,
  required Color secondary,
}) {
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: brand,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: brand,
      foregroundColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: brand.withValues(alpha: 0.38),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: brand,
      foregroundColor: Colors.white,
    ),
  );
}

/// Theme override for a cleaning business.
ThemeData cleaningTheme(ThemeData base) {
  return pouBrandedTheme(base, brand: pouCleaning, secondary: pouCleaningLight);
}

/// Theme override for a marmita business.
ThemeData mealsTheme(ThemeData base) {
  return pouBrandedTheme(base, brand: pouMeals, secondary: pouMealsLight);
}

/// Theme override for a pizza business.
ThemeData pizzasTheme(ThemeData base) {
  return pouBrandedTheme(base, brand: pouPizzas, secondary: pouPizzasLight);
}

/// Theme override for a lanche business.
ThemeData snacksTheme(ThemeData base) {
  return pouBrandedTheme(base, brand: pouSnacks, secondary: pouSnacksLight);
}

/// Theme override for a bolo de pote business.
ThemeData cakesTheme(ThemeData base) {
  return pouBrandedTheme(base, brand: pouCakes, secondary: pouCakesLight);
}

/// Full-bleed pepperoni photo for the pizza bottom bar.
Widget pouPizzasBackdrop({Alignment alignment = Alignment.center}) {
  return Image.asset(
    pouPizzasNavAsset,
    fit: BoxFit.cover,
    alignment: alignment,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
    gaplessPlayback: true,
  );
}

/// Burgers and fries across the lanche bar, shaded so the labels stay readable.
Widget pouSnacksBackdrop({Alignment alignment = Alignment.center}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        pouSnacksNavAsset,
        fit: BoxFit.cover,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        gaplessPlayback: true,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x665C2A08), Color(0xD05C2A08)],
          ),
        ),
      ),
    ],
  );
}

/// Dessert cups across the bolo de pote bar, shaded so the labels stay readable.
Widget pouCakesBackdrop({Alignment alignment = Alignment.center}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        pouCakesNavAsset,
        fit: BoxFit.cover,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        gaplessPlayback: true,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x994D1806), Color(0xE64D1806)],
          ),
        ),
      ),
    ],
  );
}

/// Marmita photo across the bottom bar, with a soft graphite shade for the labels.
Widget pouMealsBackdrop({Alignment alignment = Alignment.center}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        pouMealsNavAsset,
        fit: BoxFit.cover,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        gaplessPlayback: true,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x40292929), Color(0xB3292929)],
          ),
        ),
      ),
    ],
  );
}

/// Active tab is gold only on Marmitas. Other themes keep white.
Color pouNavForeground(BuildContext context, {required bool selected}) {
  if (BusinessLook.chromeOf(context) == PouChrome.meals) {
    return selected ? pouMealsGold : pouMealsNavIdle;
  }
  return selected ? Colors.white : const Color(0xB3FFFFFF);
}

/// Full-bleed water photo for the cleaning bottom bar.
///
/// The source is a short panorama with the ripple band along the top, so a
/// short bar aligns there instead of the empty middle.
Widget pouCleaningBackdrop({Alignment alignment = Alignment.topCenter}) {
  return Image.asset(
    pouCleaningNavAsset,
    fit: BoxFit.cover,
    alignment: alignment,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
    gaplessPlayback: true,
  );
}

/// Full-bleed leaf photo (same asset as the bottom navigation bar).
Widget pouLeafBackdrop({Alignment alignment = Alignment.center}) {
  return Image.asset(
    pouLeafBackgroundAsset,
    fit: BoxFit.cover,
    alignment: alignment,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
    gaplessPlayback: true,
  );
}

/// App bar filled with the brand color.
PreferredSizeWidget pouGradientAppBar({
  Key? key,
  Widget? title,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  double? titleSpacing,
  PreferredSizeWidget? bottom,
  TextStyle? titleTextStyle,
}) {
  return AppBar(
    key: key,
    title: title,
    actions: actions,
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading,
    titleSpacing: titleSpacing,
    bottom: bottom,
    backgroundColor: Colors.transparent,
    foregroundColor: pouCanvas,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    titleTextStyle:
        titleTextStyle ??
        const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: pouCanvas,
        ),
    flexibleSpace: const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: pouBrandGradient),
      ),
    ),
  );
}

/// App bar filled with the same leaf photo as the bottom navigation bar.
PreferredSizeWidget pouLeafAppBar({
  Key? key,
  Widget? title,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  double? titleSpacing,
  PreferredSizeWidget? bottom,
  TextStyle? titleTextStyle,
}) {
  return AppBar(
    key: key,
    title: title,
    actions: actions,
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading,
    titleSpacing: titleSpacing,
    bottom: bottom,
    backgroundColor: Colors.transparent,
    foregroundColor: pouCanvas,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    titleTextStyle:
        titleTextStyle ??
        const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: pouCanvas,
        ),
    flexibleSpace: Builder(
      builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SizedBox.expand(child: pouChromeFill(context)),
      ),
    ),
  );
}

ButtonStyle pouAppPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: pouBrand,
    foregroundColor: Colors.white,
    disabledBackgroundColor: pouBrand.withValues(alpha: 0.38),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
  );
}

/// Primary filled action in brand color.
class PouGradientButton extends StatelessWidget {
  const PouGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.minimumSize = const Size.fromHeight(48),
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.foregroundColor = Colors.white,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Size minimumSize;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color foregroundColor;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final brand = pouThemeBrand(context);
    final labelStyle = DefaultTextStyle.merge(
      style: TextStyle(
        color: foregroundColor.withValues(alpha: _enabled ? 1 : 0.38),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          color: foregroundColor.withValues(alpha: _enabled ? 1 : 0.38),
        ),
        child: child,
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: brand.withValues(alpha: _enabled ? 1 : 0.38),
            borderRadius: borderRadius,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minimumSize.width,
              minHeight: minimumSize.height,
            ),
            child: Padding(
              padding: padding,
              child: Center(child: labelStyle),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating action button filled with brand color.
class PouGradientFab extends StatelessWidget {
  const PouGradientFab({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final brand = pouThemeBrand(context);
    final button = Material(
      color: brand,
      elevation: 4,
      shadowColor: brand.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white, size: 24),
              child: child,
            ),
          ),
        ),
      ),
    );
    final tagged = heroTag == null
        ? button
        : Hero(tag: heroTag!, child: button);
    if (tooltip == null) return tagged;
    return Tooltip(message: tooltip!, child: tagged);
  }
}
