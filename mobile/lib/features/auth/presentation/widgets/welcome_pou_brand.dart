import 'package:flutter/material.dart';

/// PouApp wordmark for the pre-login welcome screen.
class WelcomePouBrand extends StatelessWidget {
  const WelcomePouBrand({super.key, required this.scale});

  /// Conversion factor from the 215-unit reference width.
  final double scale;

  static const logoAsset = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final markSize = 22 * s;
    final gap = 5 * s;
    final nameSize = 14 * s;

    return SizedBox(
      height: markSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo já vem com fundo transparente e cantos arredondados —
          // sem ClipRRect/cover para não inventar borda preta.
          Image.asset(
            logoAsset,
            width: markSize,
            height: markSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            isAntiAlias: true,
          ),
          SizedBox(width: gap),
          Text(
            'PouApp',
            style: TextStyle(
              color: Colors.black,
              fontSize: nameSize,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.3 * s,
            ),
          ),
        ],
      ),
    );
  }
}
