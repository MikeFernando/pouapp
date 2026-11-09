import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_glyphs.dart';
import 'pou_app_colors.dart';

/// One destination of [RoundedNavigationScaffold].
class RoundedNavigationDestination {
  const RoundedNavigationDestination({
    required this.glyph,
    required this.label,
  });

  final NavGlyphKind glyph;
  final String label;
}

/// Page surface with rounded lower corners, sitting on the navigation bar.
///
/// The scaffold background is the bar color, so the curve reveals that same
/// surface. Screen colors inside [content] stay as they are.
class RoundedNavigationScaffold extends StatelessWidget {
  const RoundedNavigationScaffold({
    super.key,
    required this.content,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final Widget content;
  final List<RoundedNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const cornerRadius = BorderRadius.only(
    bottomLeft: Radius.circular(36),
    bottomRight: Radius.circular(36),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: pouInk,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: pouInk,
        body: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: cornerRadius,
                child: ColoredBox(color: pouCanvas, child: content),
              ),
            ),
            RoundedBottomNavigationBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class RoundedBottomNavigationBar extends StatelessWidget {
  const RoundedBottomNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<RoundedNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Height of the icon and label row, before the system gesture inset.
  static const itemExtent = 80.0;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final gesture = keyboard > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;
    return ColoredBox(
      key: const Key('workspace_nav'),
      color: pouInk,
      child: Padding(
        padding: EdgeInsets.only(bottom: gesture),
        child: SizedBox(
          height: itemExtent,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _NavigationItem(
                    destination: destinations[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final RoundedNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _idle = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : _idle;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NavGlyph(kind: destination.glyph, color: color, filled: selected),
            const SizedBox(height: 6),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
