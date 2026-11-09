import 'package:flutter/material.dart';

import 'pou_app_colors.dart';

enum NavGlyphKind { home, products, customers, finance }

/// Thin geometric marks for the shell navigation.
class NavGlyph extends StatelessWidget {
  const NavGlyph({
    super.key,
    required this.kind,
    required this.color,
    this.filled = false,
  });

  final NavGlyphKind kind;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(24),
      painter: _NavGlyphPainter(kind: kind, color: color, filled: filled),
    );
  }
}

class _NavGlyphPainter extends CustomPainter {
  const _NavGlyphPainter({
    required this.kind,
    required this.color,
    required this.filled,
  });

  final NavGlyphKind kind;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final seam = Paint()
      ..color = pouInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final scale = size.width / 24;
    canvas
      ..save()
      ..scale(scale);
    switch (kind) {
      case NavGlyphKind.home:
        _home(canvas, paint);
      case NavGlyphKind.products:
        _products(canvas, paint, stroke, seam);
      case NavGlyphKind.customers:
        _customers(canvas, paint);
      case NavGlyphKind.finance:
        _finance(canvas, paint);
    }
    canvas.restore();
  }

  void _home(Canvas canvas, Paint paint) {
    final shell = Path()
      ..moveTo(12, 3.2)
      ..lineTo(21, 10.6)
      ..lineTo(18.6, 10.6)
      ..lineTo(18.6, 18.6)
      ..quadraticBezierTo(18.6, 21, 16.2, 21)
      ..lineTo(7.8, 21)
      ..quadraticBezierTo(5.4, 21, 5.4, 18.6)
      ..lineTo(5.4, 10.6)
      ..lineTo(3, 10.6)
      ..close();
    canvas.drawPath(shell, paint);
  }

  void _products(Canvas canvas, Paint paint, Paint stroke, Paint seam) {
    final box = Path()
      ..moveTo(12, 3.1)
      ..lineTo(20.4, 7.5)
      ..lineTo(20.4, 16.3)
      ..lineTo(12, 20.8)
      ..lineTo(3.6, 16.3)
      ..lineTo(3.6, 7.5)
      ..close();
    canvas.drawPath(box, paint);
    final edge = filled ? seam : stroke;
    canvas.drawLine(const Offset(12, 3.1), const Offset(12, 12.1), edge);
    canvas.drawLine(const Offset(3.6, 7.5), const Offset(12, 12.1), edge);
    canvas.drawLine(const Offset(20.4, 7.5), const Offset(12, 12.1), edge);
    canvas.drawLine(const Offset(12, 12.1), const Offset(12, 20.8), edge);
  }

  void _customers(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(7.6, 7.4), 2.45, paint);
    final rear = Path()
      ..moveTo(3.1, 15.8)
      ..quadraticBezierTo(3.1, 11.8, 7.6, 11.8)
      ..quadraticBezierTo(12.1, 11.8, 12.1, 15.8)
      ..lineTo(12.1, 17)
      ..lineTo(3.1, 17)
      ..close();
    canvas.drawPath(rear, paint);
    canvas.drawCircle(const Offset(15.8, 10.2), 2.85, paint);
    final front = Path()
      ..moveTo(9.2, 21.3)
      ..quadraticBezierTo(9.2, 15.2, 15.8, 15.2)
      ..quadraticBezierTo(22.4, 15.2, 22.4, 21.3)
      ..close();
    canvas.drawPath(front, paint);
  }

  void _finance(Canvas canvas, Paint paint) {
    final wallet = Path()
      ..moveTo(6.8, 2.6)
      ..lineTo(17.4, 2.6)
      ..quadraticBezierTo(21.6, 2.6, 21.6, 6.4)
      ..lineTo(21.6, 9.5)
      ..lineTo(17.2, 9.5)
      ..quadraticBezierTo(15.4, 9.5, 15.4, 12)
      ..quadraticBezierTo(15.4, 14.5, 17.2, 14.5)
      ..lineTo(21.6, 14.5)
      ..lineTo(21.6, 17.6)
      ..quadraticBezierTo(21.6, 21.4, 17.4, 21.4)
      ..lineTo(6.8, 21.4)
      ..quadraticBezierTo(2.4, 21.4, 2.4, 17.6)
      ..lineTo(2.4, 6.4)
      ..quadraticBezierTo(2.4, 2.6, 6.8, 2.6)
      ..close();
    canvas.drawPath(wallet, paint);
  }

  @override
  bool shouldRepaint(covariant _NavGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.color != color ||
        oldDelegate.filled != filled;
  }
}
