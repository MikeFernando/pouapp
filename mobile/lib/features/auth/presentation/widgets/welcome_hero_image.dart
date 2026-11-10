import 'package:flutter/material.dart';

/// Grocery bag composition for the welcome screen.
///
/// Uses [assetPath] (1536×1024, transparent). The image is taller than the
/// side margins imply, so it is sized to the band height and allowed to
/// overflow horizontally — tomatoes/carrots clip at the screen edges while
/// the bag base stays visible.
class WelcomeHeroImage extends StatelessWidget {
  const WelcomeHeroImage({
    super.key,
    required this.height,
  });

  final double height;

  static const assetPath = 'assets/images/grocery_hero.png';

  /// Intrinsic aspect of `grocery_hero.png` (1536×1024).
  static const _aspect = 1536 / 1024;

  @override
  Widget build(BuildContext context) {
    final imageHeight = height;
    final imageWidth = imageHeight * _aspect;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          minWidth: imageWidth,
          maxWidth: imageWidth,
          minHeight: imageHeight,
          maxHeight: imageHeight,
          child: Image.asset(
            assetPath,
            width: imageWidth,
            height: imageHeight,
            fit: BoxFit.fitHeight,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
