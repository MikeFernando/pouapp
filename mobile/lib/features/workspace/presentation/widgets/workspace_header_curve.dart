import 'package:flutter/material.dart';

const headerCurveSide = 36.0;
const headerCurveLift = 112.0;

/// Lowest point of the shared header arc, plus a little room for the stroke.
const headerCurveHeight = headerCurveSide + headerCurveLift / 2 + 4;

double headerCurveDrop(double t) => 2 * t * (1 - t) * headerCurveLift;

class HeaderCurvePainter extends CustomPainter {
  const HeaderCurvePainter(this.color, {this.extra = 0});

  final Color color;

  /// Solid height added above the arc so it sits lower without changing
  /// the curve.
  final double extra;

  @override
  void paint(Canvas canvas, Size size) {
    final side = headerCurveSide + extra;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, side)
      ..quadraticBezierTo(
        size.width / 2,
        side + headerCurveLift,
        size.width,
        side,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant HeaderCurvePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.extra != extra;
  }
}

const streetCurveExtra = 80.0;

const streetCurveHeight = headerCurveHeight + streetCurveExtra;
