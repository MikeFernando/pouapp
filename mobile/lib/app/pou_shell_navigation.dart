import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_glyphs.dart';
import 'pou_app_colors.dart';

/// Alias kept for older call sites.
const pouBottomNavBackgroundAsset = pouLeafBackgroundAsset;

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
/// The leaf photo fills the bar and the small reveals beside the white card's
/// rounded corners. Screen colors inside [content] stay as they are.
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

  static const _cornerExtent = 36.0;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final gesture = keyboard > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;
    final barHeight = PouShellBottomBar.itemExtent + gesture;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: pouLeafChrome,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: pouLeafChrome,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: barHeight,
              height: _cornerExtent,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _cornerExtent / barHeight,
                  child: SizedBox(
                    height: barHeight,
                    width: double.infinity,
                    child: pouLeafBackdrop(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: barHeight,
              child: pouLeafBackdrop(),
            ),
            Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: cornerRadius,
                    child: ColoredBox(color: pouCanvas, child: content),
                  ),
                ),
                PouShellBottomBar(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  gestureInset: gesture,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom tab row for the authenticated shell (icons + labels only).
class PouShellBottomBar extends StatelessWidget {
  const PouShellBottomBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.gestureInset,
  });

  final List<RoundedNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// When null, reads the current media query (standalone use).
  final double? gestureInset;

  /// Height of the icon and label row, before the system gesture inset.
  static const itemExtent = 86.0;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final gesture = gestureInset ??
        (keyboard > 0 ? 0.0 : MediaQuery.viewPaddingOf(context).bottom);
    return KeyedSubtree(
      key: const Key('workspace_nav'),
      child: Padding(
        padding: EdgeInsets.only(bottom: gesture),
        child: SizedBox(
          height: itemExtent,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _PouShellNavItem(
                    destination: destinations[index],
                    selected: index == selectedIndex,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelected(index);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Old name kept as a typedef so stray imports keep compiling.
typedef RoundedBottomNavigationBar = PouShellBottomBar;

class _PouShellNavItem extends StatelessWidget {
  const _PouShellNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final RoundedNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _idle = Color(0xB3FFFFFF);

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
            const SizedBox(height: 7),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
