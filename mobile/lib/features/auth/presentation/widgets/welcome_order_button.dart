import 'package:flutter/material.dart';

/// Primary CTA for the PouApp welcome screen.
class WelcomeOrderButton extends StatelessWidget {
  const WelcomeOrderButton({
    super.key,
    required this.scale,
    required this.onPressed,
  });

  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final height = 31 * s;
    final radius = 7 * s;
    final fontSize = 9 * s;
    final gap = 8 * s;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          key: const Key('welcome_order_now'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Login',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                SizedBox(width: gap),
                Text(
                  '↑',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize * 1.2,
                    fontWeight: FontWeight.w300,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
