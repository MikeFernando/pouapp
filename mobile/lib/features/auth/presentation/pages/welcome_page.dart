import 'package:flutter/material.dart';

import '../widgets/welcome_copy_block.dart';
import '../widgets/welcome_hero_image.dart';
import '../widgets/welcome_order_button.dart';
import '../widgets/welcome_pou_brand.dart';

/// Pre-login PouApp welcome screen matched to the product reference.
///
/// Layout uses a 215×466 reference coordinate system scaled by
/// `availableWidth / 215` via [LayoutBuilder].
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onOrderNow});

  /// Continues into the existing auth/login flow.
  final VoidCallback onOrderNow;

  static const _refWidth = 215.0;
  static const _refHeight = 466.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final s = width / _refWidth;
          final media = MediaQuery.of(context);
          final bottomInset = media.padding.bottom;
          final topInset = media.padding.top;

          final designHeight = _refHeight * s;
          final needsScroll = height < designHeight * 0.92;

          final content = _WelcomeLayout(
            scale: s,
            topInset: topInset,
            bottomInset: bottomInset,
            onOrderNow: onOrderNow,
            height: needsScroll ? designHeight : height,
          );

          if (needsScroll) {
            return ColoredBox(
              color: Colors.white,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: width,
                  height: designHeight,
                  child: content,
                ),
              ),
            );
          }

          return content;
        },
      ),
    );
  }
}

class _WelcomeLayout extends StatelessWidget {
  const _WelcomeLayout({
    required this.scale,
    required this.topInset,
    required this.bottomInset,
    required this.onOrderNow,
    required this.height,
  });

  final double scale;
  final double topInset;
  final double bottomInset;
  final VoidCallback onOrderNow;
  final double height;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    // Reference y values are from the display top (status bar is native).
    // Keep logo below the system inset when the inset exceeds y=44.
    final logoTop = (44 * s) < (topInset + 6 * s)
        ? topInset + 6 * s
        : 44 * s;
    final heroTop = 87 * s;
    final heroHeight = 180 * s;
    final titleTop = 285 * s;
    final buttonHeight = 31 * s;
    final buttonMarginH = 8 * s;

    // Prefer reference y=412; if the screen is taller, pin near the bottom.
    final buttonTopRef = 412 * s;
    final buttonTopBottomPinned =
        height - bottomInset - buttonHeight - 12 * s;
    final buttonTop = buttonTopRef < buttonTopBottomPinned
        ? buttonTopBottomPinned
        : buttonTopRef;

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: logoTop,
            left: 0,
            right: 0,
            child: Center(child: WelcomePouBrand(scale: s)),
          ),
          Positioned(
            top: heroTop,
            left: 0,
            right: 0,
            height: heroHeight,
            child: WelcomeHeroImage(height: heroHeight),
          ),
          Positioned(
            top: titleTop,
            left: 0,
            right: 0,
            child: WelcomeCopyBlock(scale: s),
          ),
          Positioned(
            top: buttonTop,
            left: buttonMarginH,
            right: buttonMarginH,
            height: buttonHeight,
            child: WelcomeOrderButton(scale: s, onPressed: onOrderNow),
          ),
        ],
      ),
    );
  }
}
