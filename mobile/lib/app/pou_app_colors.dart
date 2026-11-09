import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Near black. Icons and text on light surfaces.
const pouInk = Color(0xFF0E0D0F);

/// Light gray. Fields, chips, and secondary surfaces.
const pouSurface = Color(0xFFE9E8EB);

/// Off-white. Page backgrounds and text on the green accent.
const pouCanvas = Color(0xFFF6F5F7);

/// Mid green for icons, outlines, and solid accents.
const pouAccent = Color(0xFF34C759);

/// Lighter green at the top of the brand gradient.
const pouAccentTop = Color(0xFF4AE06C);

/// Darker green at the bottom of the brand gradient.
const pouAccentBottom = Color(0xFF2DBA52);

/// Brand green used by headers, primary buttons, and the FAB.
const pouAccentGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [pouAccentTop, pouAccentBottom],
);

/// Dark brand alias kept for older call sites; prefer [pouAccentGradient].
const pouAppBlue = pouInk;

BoxDecoration pouAccentGradientDecoration({
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
}) {
  return BoxDecoration(gradient: pouAccentGradient, borderRadius: borderRadius);
}

/// App bar filled with the brand green gradient.
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
        decoration: BoxDecoration(gradient: pouAccentGradient),
      ),
    ),
  );
}

ButtonStyle pouAppPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: pouInk,
    foregroundColor: Colors.white,
    disabledBackgroundColor: pouInk.withValues(alpha: 0.38),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
  );
}

/// Primary filled action in ink black.
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
            color: pouInk.withValues(alpha: _enabled ? 1 : 0.38),
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

/// Floating action button filled with ink black.
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
    final button = Material(
      color: pouInk,
      elevation: 4,
      shadowColor: pouInk.withValues(alpha: 0.28),
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
    final tagged = heroTag == null ? button : Hero(tag: heroTag!, child: button);
    if (tooltip == null) return tagged;
    return Tooltip(message: tooltip!, child: tagged);
  }
}
