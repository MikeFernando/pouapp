import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../catalog/presentation/produce_assets.dart';
import '../../domain/entities/posted_sale.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';

const _page = Color(0xFFFBFBFD);
const _muted = Color(0xFF8E8E93);
const _idle = Color(0xFFA7A7AD);
const _cardFill = Color(0xFFF6F6F7);
const _neutral = Color(0xFFD0D0D6);
const _neutralInk = Color(0xFF8E8E93);

enum _HueFamily {
  yellow,
  green,
  red,
  purple,
  orange,
  brown,
  pink,
  blue,
  white,
  other,
}

/// Product → hue family from the produce's main color.
/// Longer keys first so "batata doce" / "repolho roxo" win over shorter ones.
const _merchandiseFamilies = <String, _HueFamily>{
  // Compound names
  'batata doce': _HueFamily.orange,
  'repolho roxo': _HueFamily.purple,
  'couve flor': _HueFamily.white,
  'couve-flor': _HueFamily.white,
  'tomate cereja': _HueFamily.red,
  // Yellow
  'banana': _HueFamily.yellow,
  'abacaxi': _HueFamily.yellow,
  'carambola': _HueFamily.yellow,
  'limao': _HueFamily.yellow,
  'milho': _HueFamily.yellow,
  'maracuja': _HueFamily.yellow,
  'melao': _HueFamily.yellow,
  'mandioquinha': _HueFamily.yellow,
  // White / cream
  'ovo': _HueFamily.white,
  'nabo': _HueFamily.white,
  'alho': _HueFamily.purple,
  'coco': _HueFamily.brown,
  // Green
  'alface': _HueFamily.green,
  'abacate': _HueFamily.green,
  'pepino': _HueFamily.green,
  'couve': _HueFamily.green,
  'brocolis': _HueFamily.green,
  'chuchu': _HueFamily.green,
  'kiwi': _HueFamily.green,
  'agriao': _HueFamily.green,
  'acelga': _HueFamily.green,
  'chicoria': _HueFamily.green,
  'espinafre': _HueFamily.green,
  'rucula': _HueFamily.green,
  'repolho': _HueFamily.green,
  'salsa': _HueFamily.green,
  'coentro': _HueFamily.green,
  'manjericao': _HueFamily.green,
  'hortela': _HueFamily.green,
  'cebolinha': _HueFamily.green,
  'abobrinha': _HueFamily.green,
  'quiabo': _HueFamily.green,
  'vagem': _HueFamily.green,
  'maxixe': _HueFamily.green,
  'pera': _HueFamily.green,
  // Red
  'acerola': _HueFamily.red,
  'tomate': _HueFamily.red,
  'morango': _HueFamily.red,
  'pimentao': _HueFamily.red,
  'pimenta': _HueFamily.red,
  'maca': _HueFamily.red,
  'rabanete': _HueFamily.red,
  'melancia': _HueFamily.red,
  // Purple
  'uva': _HueFamily.purple,
  'berinjela': _HueFamily.purple,
  'ameixa': _HueFamily.purple,
  'amora': _HueFamily.purple,
  'figo': _HueFamily.purple,
  'jabuticaba': _HueFamily.purple,
  'jilo': _HueFamily.purple,
  // Orange
  'laranja': _HueFamily.orange,
  'cenoura': _HueFamily.orange,
  'mamao': _HueFamily.orange,
  'manga': _HueFamily.orange,
  'caqui': _HueFamily.orange,
  'tangerina': _HueFamily.orange,
  'caju': _HueFamily.orange,
  'abobora': _HueFamily.orange,
  'pessego': _HueFamily.orange,
  // Brown / earthy
  'cebola': _HueFamily.brown,
  'inhame': _HueFamily.brown,
  'mandioca': _HueFamily.brown,
  'batata': _HueFamily.brown,
  // Pink
  'beterraba': _HueFamily.pink,
  'pitaya': _HueFamily.pink,
  'goiaba': _HueFamily.pink,
};

/// Base HSL for each family (hue, saturation). Lightness is varied per sibling.
const _familyHsl = <_HueFamily, (double, double)>{
  _HueFamily.yellow: (48, 0.92),
  _HueFamily.green: (128, 0.55),
  _HueFamily.red: (4, 0.78),
  _HueFamily.purple: (275, 0.48),
  _HueFamily.orange: (28, 0.95),
  _HueFamily.brown: (32, 0.42),
  _HueFamily.pink: (330, 0.62),
  _HueFamily.blue: (214, 0.72),
  _HueFamily.white: (40, 0.08),
  // Unmapped products: soft gray, never a misleading fruit color.
  _HueFamily.other: (220, 0.06),
};

String _normalizeProduceKey(String name) {
  final lower = name.trim().toLowerCase();
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final code in lower.runes) {
    final char = String.fromCharCode(code);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}

_HueFamily _familyFor(String name) {
  final key = _normalizeProduceKey(name);
  for (final entry in _merchandiseFamilies.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return _HueFamily.other;
}

Color _shadeInFamily(_HueFamily family, int indexInFamily, int familyCount) {
  final base = _familyHsl[family] ?? (210.0, 0.35);
  // One product: mid tone. Several: light → deep so slices stay readable.
  final t = familyCount <= 1 ? 0.5 : indexInFamily / (familyCount - 1);
  if (family == _HueFamily.white) {
    // Eggshell off-white so the ring stays visible on the page.
    final lightness = 0.90 - (t * 0.10);
    final saturation = (base.$2 + (0.05 * t)).clamp(0.05, 0.16);
    return HSLColor.fromAHSL(1, base.$1, saturation, lightness).toColor();
  }
  final lightness = 0.72 - (t * 0.34);
  final saturation = (base.$2 + (0.08 * (0.5 - t))).clamp(0.25, 1.0);
  return HSLColor.fromAHSL(1, base.$1, saturation, lightness).toColor();
}

/// Colors for [ranked] products: siblings in the same hue get distinct tones.
Map<String, Color> _merchandiseColors(List<_ProductRank> ranked) {
  final families = <String, _HueFamily>{
    for (final row in ranked) row.name: _familyFor(row.name),
  };
  final counts = <_HueFamily, int>{};
  final indexes = <String, int>{};
  for (final row in ranked) {
    final family = families[row.name]!;
    indexes[row.name] = counts[family] ?? 0;
    counts[family] = (counts[family] ?? 0) + 1;
  }
  return {
    for (final row in ranked)
      row.name: _shadeInFamily(
        families[row.name]!,
        indexes[row.name]!,
        counts[families[row.name]!]!,
      ),
  };
}

/// Measured clockwise from the upper-left of the reference ring.
const _gapDegrees = 16.0;
const _chartSlots = 8;
const _startDegrees = -138.0;

enum _Span { week, month, year }

class FinancePage extends StatefulWidget {
  const FinancePage({
    super.key,
    this.checklistProductCents = const {},
    this.checklistReceivedCents = 0,
  });

  /// Products from home day-checklist marks (notes marked as received).
  final Map<String, int> checklistProductCents;
  final int checklistReceivedCents;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  _Span _span = _Span.month;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompanyOperationBloc, CompanyOperationState>(
      builder: (context, state) {
        final now = DateTime.now();
        final sales = [
          for (final sale
              in state.operation?.postedSales ?? const <PostedSale>[])
            if (_inside(sale, _span, now)) sale,
        ];
        final ranked = _mergeProductRanks(
          _rankedMerchandise(
            state.operation?.street.orders ?? const <SaleOrder>[],
            _span,
            now,
          ),
          widget.checklistProductCents,
        );
        final baseFigures = _figures(sales);
        final checklistCents = widget.checklistReceivedCents > 0
            ? widget.checklistReceivedCents
            : widget.checklistProductCents.values.fold<int>(
                0,
                (sum, cents) => sum + cents,
              );
        final figures = _Figures(
          billed: baseFigures.billed + checklistCents,
          received: baseFigures.received + checklistCents,
          open: baseFigures.open,
        );
        final arcs = _arcs(_merchandiseSlices(ranked));
        final categories = _categories(ranked);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: pouBrand,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarContrastEnforced: false,
          ),
          child: ColoredBox(
            color: _page,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final diameter = constraints.maxWidth * 0.68;
                final ringHeight = diameter + 52;
                final topInset = MediaQuery.paddingOf(context).top;
                final headerExtent = topInset + ringHeight + 18;
                final minSheet =
                    ((constraints.maxHeight - headerExtent) /
                            constraints.maxHeight)
                        .clamp(0.40, 0.54);
                final maxSheet =
                    ((constraints.maxHeight - topInset - 12) /
                            constraints.maxHeight)
                        .clamp(0.88, 0.96);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            SizedBox(
                              height: ringHeight,
                              width: constraints.maxWidth,
                              child: _Ring(
                                arcs: arcs,
                                caption: _caption(_span, now),
                                totalCents: figures.billed,
                                diameter: diameter,
                              ),
                            ),
                            _Filters(
                              span: _span,
                              onChanged: (span) =>
                                  setState(() => _span = span),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: minSheet,
                      minChildSize: minSheet,
                      maxChildSize: maxSheet,
                      snap: true,
                      snapSizes: [minSheet, maxSheet],
                      builder: (context, scrollController) {
                        return _Sheet(
                          scrollController: scrollController,
                          categories: categories,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

bool _inside(PostedSale sale, _Span span, DateTime now) {
  if (!sale.sale || sale.totalCents <= 0) return false;
  final date = _day(sale.occurredOn);
  if (date == null) return false;
  final today = DateTime(now.year, now.month, now.day);
  if (date.isAfter(today)) return false;
  return switch (span) {
    _Span.week => !date.isBefore(_weekStart(today)),
    _Span.month => date.year == today.year && date.month == today.month,
    _Span.year => date.year == today.year,
  };
}

DateTime _weekStart(DateTime today) {
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
}

DateTime? _day(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

String _caption(_Span span, DateTime now) {
  return switch (span) {
    _Span.week => 'Faturado nesta semana',
    _Span.month => 'Faturado em ${monthNames[now.month - 1].toLowerCase()}',
    _Span.year => 'Faturado em ${now.year}',
  };
}

class _Figures {
  const _Figures({
    required this.billed,
    required this.received,
    required this.open,
  });

  final int billed;
  final int received;
  final int open;
}

_Figures _figures(List<PostedSale> sales) {
  var billed = 0;
  var received = 0;
  var open = 0;
  for (final sale in sales) {
    final applied = sale.allocatedCents < 0
        ? 0
        : math.min(sale.allocatedCents, sale.totalCents);
    final due = sale.totalCents - applied;
    billed += sale.totalCents;
    received += applied;
    open += due < 0 ? 0 : due;
  }
  return _Figures(billed: billed, received: received, open: open);
}

class _ProductRank {
  const _ProductRank({required this.name, required this.cents});

  final String name;
  final int cents;
}

class _Category {
  const _Category({
    required this.name,
    required this.cents,
    required this.percent,
    required this.color,
    required this.asset,
    required this.placeholder,
  });

  final String name;
  final int cents;

  /// Null when the share cannot be divided. The card still keeps the slot.
  final int? percent;
  final Color color;
  final String? asset;
  final bool placeholder;
}

int? _share(int part, int whole) {
  if (whole <= 0) return null;
  final percent = ((part * 100) / whole).round();
  if (percent < 0) return 0;
  if (percent > 100) return 100;
  return percent;
}

List<_ProductRank> _mergeProductRanks(
  List<_ProductRank> base,
  Map<String, int> extra,
) {
  if (extra.isEmpty) return base;
  final totals = <String, int>{
    for (final row in base) row.name: row.cents,
  };
  for (final entry in extra.entries) {
    final name = entry.key.trim();
    if (name.isEmpty || entry.value <= 0) continue;
    totals[name] = (totals[name] ?? 0) + entry.value;
  }
  final ranked = totals.entries.toList()
    ..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      return byValue != 0 ? byValue : a.key.compareTo(b.key);
    });
  return [
    for (final row in ranked) _ProductRank(name: row.key, cents: row.value),
  ];
}

List<_ProductRank> _rankedMerchandise(
  List<SaleOrder> orders,
  _Span span,
  DateTime now,
) {
  final totals = <String, int>{};
  for (final order in orders) {
    if (!order.recorded || order.fromSeed) continue;
    final occurredOn = order.occurredOn;
    if (occurredOn == null || occurredOn.isEmpty) continue;
    final date = _day(occurredOn);
    if (date == null) continue;
    final today = DateTime(now.year, now.month, now.day);
    if (date.isAfter(today)) continue;
    final inSpan = switch (span) {
      _Span.week => !date.isBefore(_weekStart(today)),
      _Span.month => date.year == today.year && date.month == today.month,
      _Span.year => date.year == today.year,
    };
    if (!inSpan) continue;
    for (final line in order.lines) {
      final name = line.productName.trim();
      if (name.isEmpty || line.totalCents <= 0) continue;
      totals[name] = (totals[name] ?? 0) + line.totalCents;
    }
  }
  final ranked = totals.entries.toList()
    ..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      return byValue != 0 ? byValue : a.key.compareTo(b.key);
    });
  return [
    for (final row in ranked) _ProductRank(name: row.key, cents: row.value),
  ];
}

List<_Category> _categories(List<_ProductRank> ranked) {
  final total = ranked.fold<int>(0, (sum, product) => sum + product.cents);
  final top = ranked.take(_chartSlots).toList();
  if (top.isEmpty) return const [];
  final colors = _merchandiseColors(ranked);
  return [
    for (final product in top)
      _Category(
        name: product.name,
        cents: product.cents,
        percent: _share(product.cents, total),
        color: colors[product.name] ?? _neutral,
        asset: produceAsset(product.name),
        placeholder: false,
      ),
  ];
}

class _Slice {
  const _Slice({
    required this.cents,
    required this.color,
    this.asset,
  });

  final int cents;
  final Color color;
  final String? asset;
}

List<_Slice> _merchandiseSlices(List<_ProductRank> ranked) {
  if (ranked.isEmpty) return const [];
  final top = ranked.take(_chartSlots).toList();
  final colors = _merchandiseColors(ranked);
  return [
    for (final product in top)
      _Slice(
        cents: product.cents,
        color: colors[product.name] ?? _neutral,
        asset: produceAsset(product.name),
      ),
  ];
}

class _Arc {
  const _Arc({
    required this.sweepDegrees,
    required this.color,
    required this.label,
    required this.neutral,
    this.asset,
  });

  final double sweepDegrees;
  final Color color;
  final String label;
  final bool neutral;
  final String? asset;
}

List<_Arc> _emptyArcs() {
  const count = _chartSlots;
  final sweep = (360 - _gapDegrees * count) / count;
  return [
    for (var index = 0; index < count; index++)
      _Arc(
        sweepDegrees: sweep,
        color: _neutral,
        label: '',
        neutral: true,
      ),
  ];
}

List<_Arc> _arcs(List<_Slice> slices) {
  if (slices.isEmpty) return _emptyArcs();
  final total = slices.fold<int>(0, (sum, slice) => sum + slice.cents);
  if (total <= 0) return _emptyArcs();
  final available = 360 - _gapDegrees * slices.length;
  return [
    for (final slice in slices)
      _Arc(
        sweepDegrees: available * slice.cents / total,
        color: slice.color,
        label: '${_share(slice.cents, total) ?? 0}%',
        neutral: false,
        asset: slice.asset,
      ),
  ];
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.arcs,
    required this.caption,
    required this.totalCents,
    required this.diameter,
  });

  final List<_Arc> arcs;
  final String caption;
  final int totalCents;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final geometry = _layout(size, diameter, arcs);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: size,
              painter: _RingPainter(geometry: geometry),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        caption,
                        key: const Key('finance_title'),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: _muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatBrl(totalCents),
                    key: const Key('finance_billed'),
                    style: const TextStyle(
                      color: pouInk,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            for (final draw in geometry.draws)
              if (draw.arc.label.isNotEmpty)
                Positioned(
                  left: draw.label.dx,
                  top: draw.label.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: _PercentPill(
                      label: draw.arc.label,
                      asset: draw.arc.asset,
                      tint: draw.arc.color,
                      neutral: draw.arc.neutral,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _Draw {
  const _Draw({
    required this.start,
    required this.sweep,
    required this.arc,
    required this.label,
  });

  final double start;
  final double sweep;
  final _Arc arc;
  final Offset label;
}

class _Layout {
  const _Layout({
    required this.center,
    required this.radius,
    required this.stroke,
    required this.draws,
  });

  final Offset center;
  final double radius;
  final double stroke;
  final List<_Draw> draws;
}

_Layout _layout(Size size, double diameter, List<_Arc> arcs) {
  final stroke = diameter * 0.085;
  final center = Offset(size.width / 2, size.height / 2);
  final radius = (diameter - stroke) / 2;
  final gap = _gapDegrees * math.pi / 180;
  final draws = <_Draw>[];
  var angle = _startDegrees * math.pi / 180;
  for (final arc in arcs) {
    final sweep = arc.sweepDegrees * math.pi / 180;
    final mid = angle + sweep / 2;
    final reach = radius + stroke / 2 + 22;
    draws.add(
      _Draw(
        start: angle,
        sweep: sweep,
        arc: arc,
        label: Offset(
          center.dx + reach * math.cos(mid),
          center.dy + reach * math.sin(mid),
        ),
      ),
    );
    angle += sweep + gap;
  }
  return _Layout(
    center: center,
    radius: radius,
    stroke: stroke,
    draws: draws,
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.geometry});

  final _Layout geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: geometry.center,
      radius: geometry.radius,
    );
    for (final draw in geometry.draws) {
      if (draw.sweep <= 0) continue;
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.stroke
        ..strokeCap = StrokeCap.round
        ..color = draw.arc.color.withValues(alpha: draw.arc.neutral ? 0.10 : 0.16)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          geometry.stroke * (draw.arc.neutral ? 0.18 : 0.28),
        );
      final solid = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.stroke
        ..strokeCap = StrokeCap.round
        ..color = draw.arc.color;
      canvas.drawArc(rect, draw.start, draw.sweep, false, glow);
      canvas.drawArc(rect, draw.start, draw.sweep, false, solid);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => true;
}

Color _pillFill(Color tint) {
  return Color.lerp(Colors.white, tint, 0.22) ?? tint.withValues(alpha: 0.18);
}

class _PercentPill extends StatelessWidget {
  const _PercentPill({
    required this.label,
    this.asset,
    this.tint,
    this.neutral = false,
  });

  final String label;
  final String? asset;
  final Color? tint;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final fill = neutral || tint == null
        ? const Color(0xFFF1F1F4)
        : _pillFill(tint!);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          asset == null ? 8 : 4,
          3,
          8,
          3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset != null) ...[
              ClipOval(
                child: Image.asset(
                  asset!,
                  width: 18,
                  height: 18,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(width: 18, height: 18),
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: neutral ? _neutralInk : const Color(0xFF3A3A3C),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.span, required this.onChanged});

  final _Span span;
  final ValueChanged<_Span> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Semana', 'Mês', 'Ano'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < _Span.values.length; index++) ...[
          if (index > 0) const SizedBox(width: 20),
          GestureDetector(
            onTap: () => onChanged(_Span.values[index]),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: _Span.values[index] == span ? pouBrand : _idle,
                  fontSize: 15,
                  fontWeight: _Span.values[index] == span
                      ? FontWeight.w700
                      : FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.scrollController,
    required this.categories,
  });

  final ScrollController scrollController;
  final List<_Category> categories;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(32));
    // Top padding keeps the upward shadow inside the clipped sheet bounds.
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0E0D0F),
              blurRadius: 14,
              offset: Offset(0, -5),
              spreadRadius: -1,
            ),
            BoxShadow(
              color: Color(0x0F0E0D0F),
              blurRadius: 4,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.white,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
              children: [
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE4E4E8),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    child: SizedBox(width: 40, height: 5),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Categorias',
                  style: TextStyle(
                    color: pouInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                if (categories.isEmpty)
                  const Text(
                    'Nenhuma venda no período.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  _CategoryGrid(categories: categories),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<_Category> categories;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - gap) / 2;
        final cardHeight = cardWidth * 0.664;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final category in categories)
              SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: _CategoryCard(category: category),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final _Category category;

  @override
  Widget build(BuildContext context) {
    final percent = category.percent == null ? '—' : '${category.percent}%';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ~42% of inner width keeps long R$ values readable on narrow cards.
            final photoSize = (constraints.maxWidth * 0.36).clamp(48.0, 68.0);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _CategoryPhoto(
                    category: category,
                    size: photoSize,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  right: photoSize * 0.45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatBrl(category.cents),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: pouInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _PercentPill(
                    label: percent,
                    tint: category.color,
                    neutral: category.placeholder,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryPhoto extends StatelessWidget {
  const _CategoryPhoto({
    required this.category,
    required this.size,
  });

  final _Category category;
  final double size;

  static const _zoom = 1.10;

  @override
  Widget build(BuildContext context) {
    final asset = category.placeholder ? null : category.asset;
    final letter = category.placeholder || category.name.trim().isEmpty
        ? ''
        : category.name.trim()[0].toUpperCase();
    if (asset == null) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: category.placeholder ? _neutral : category.color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Transform.scale(
          scale: _zoom,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
