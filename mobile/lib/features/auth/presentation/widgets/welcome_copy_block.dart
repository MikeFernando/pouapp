import 'package:flutter/material.dart';

/// Title + subtitle block for the PouApp welcome screen.
class WelcomeCopyBlock extends StatelessWidget {
  const WelcomeCopyBlock({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'GESTÃO\nEMPRESARIAL\nHORT FRUIT',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 22 * s,
            fontWeight: FontWeight.w900,
            height: 1.03,
            letterSpacing: -0.65 * s,
          ),
        ),
        SizedBox(height: 12 * s),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 200 * s),
          child: Text(
            'Clientes, vendas e recebimentos\nem um só lugar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF666666),
              fontSize: 9 * s,
              fontWeight: FontWeight.w400,
              height: 1.4,
              letterSpacing: -0.05 * s,
            ),
          ),
        ),
      ],
    );
  }
}
