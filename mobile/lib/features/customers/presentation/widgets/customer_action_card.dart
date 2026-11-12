import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';

const _labelColor = Color(0xFF6B7280);
const _titleColor = Color(0xFF0E0D0F);
const _iconTileBg = Color(0xFFE7F3EC);
const _muted = Color(0xFF9CA3AF);

/// Shared white action row used by Vencimento and Enviar nota.
class CustomerActionCard extends StatelessWidget {
  const CustomerActionCard({
    super.key,
    required this.label,
    required this.title,
    required this.icon,
    this.onTap,
    this.inkWellKey,
    this.iconKey,
    this.titleKey,
    this.labelKey,
    this.labelFirst = true,
    this.enabled = true,
    this.busy = false,
    this.labelColor,
    this.iconTiled = true,
  });

  /// When true, gray [label] sits above bold [title] (Vencimento).
  /// When false, bold [title] sits above gray [label] (Enviar nota).
  final bool labelFirst;
  final String label;
  final String title;
  final Key? titleKey;
  final Key? labelKey;
  final Key? inkWellKey;
  final Key? iconKey;
  final Widget icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool busy;
  final Color? labelColor;

  /// When false, [icon] is shown without the light-green tile.
  final bool iconTiled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !busy;
    final gray = labelColor ?? (enabled ? _labelColor : _muted);
    final bold = enabled ? _titleColor : _muted;

    final topStyle = labelFirst
        ? TextStyle(fontSize: 15, color: gray, fontWeight: FontWeight.w500)
        : TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: bold);
    final bottomStyle = labelFirst
        ? TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: bold)
        : TextStyle(fontSize: 14, height: 1.3, color: gray);

    final top = labelFirst ? label : title;
    final bottom = labelFirst ? title : label;
    final topKey = labelFirst ? labelKey : titleKey;
    final bottomKey = labelFirst ? titleKey : labelKey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: inkWellKey,
          onTap: active ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          top,
                          key: topKey,
                          style: topStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bottom,
                          key: bottomKey,
                          style: bottomStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (iconTiled)
                    CustomerActionIconTile(
                      key: iconKey,
                      busy: busy,
                      child: icon,
                    )
                  else
                    SizedBox(
                      key: iconKey,
                      width: 40,
                      height: 40,
                      child: busy
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Center(child: icon),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerActionIconTile extends StatelessWidget {
  const CustomerActionIconTile({
    super.key,
    required this.child,
    this.busy = false,
  });

  final Widget child;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _iconTileBg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : SizedBox(width: 26, height: 26, child: child),
    );
  }
}

/// Calendar glyph matching the mock (tabs + outline + day dot).
class DueCalendarIcon extends StatelessWidget {
  const DueCalendarIcon({super.key, this.color = pouBrand});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _DueCalendarPainter(color),
    );
  }
}

/// Document + export arrow matching the mock.
class SendNoteFileIcon extends StatelessWidget {
  const SendNoteFileIcon({super.key, this.color = pouBrand});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _SendNoteFilePainter(color),
    );
  }
}

class _DueCalendarPainter extends CustomPainter {
  _DueCalendarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.24,
        size.width * 0.72,
        size.height * 0.62,
      ),
      const Radius.circular(3.2),
    );
    canvas.drawRRect(body, stroke);

    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.42),
      Offset(size.width * 0.86, size.height * 0.42),
      stroke,
    );

    final tab = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.10),
      Offset(size.width * 0.34, size.height * 0.30),
      tab,
    );
    canvas.drawLine(
      Offset(size.width * 0.66, size.height * 0.10),
      Offset(size.width * 0.66, size.height * 0.30),
      tab,
    );

    canvas.drawCircle(
      Offset(size.width * 0.64, size.height * 0.68),
      1.55,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DueCalendarPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SendNoteFilePainter extends CustomPainter {
  _SendNoteFilePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final page = Path()
      ..moveTo(size.width * 0.16, size.height * 0.14)
      ..lineTo(size.width * 0.50, size.height * 0.14)
      ..lineTo(size.width * 0.66, size.height * 0.30)
      ..lineTo(size.width * 0.66, size.height * 0.86)
      ..lineTo(size.width * 0.16, size.height * 0.86)
      ..close();
    canvas.drawPath(page, stroke);

    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.14),
      Offset(size.width * 0.50, size.height * 0.30),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.30),
      Offset(size.width * 0.66, size.height * 0.30),
      stroke,
    );

    canvas.drawLine(
      Offset(size.width * 0.26, size.height * 0.48),
      Offset(size.width * 0.54, size.height * 0.48),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.26, size.height * 0.62),
      Offset(size.width * 0.48, size.height * 0.62),
      stroke,
    );

    final tip = Offset(size.width * 0.90, size.height * 0.12);
    canvas.drawLine(
      Offset(size.width * 0.60, size.height * 0.40),
      tip,
      stroke,
    );
    canvas.drawLine(tip, Offset(size.width * 0.72, size.height * 0.12), stroke);
    canvas.drawLine(tip, Offset(size.width * 0.90, size.height * 0.28), stroke);
  }

  @override
  bool shouldRepaint(covariant _SendNoteFilePainter oldDelegate) =>
      oldDelegate.color != color;
}
