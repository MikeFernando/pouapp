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

const _sliceColors = <Color>[
  Color(0xFF3479F8),
  Color(0xFFF44E4E),
  Color(0xFF37C652),
  Color(0xFF725BDD),
  Color(0xFFFFA800),
];

/// Measured clockwise from the upper-left of the reference ring.
const _structuralWeights = <double>[67, 26, 41, 82, 131];
const _gapDegrees = 11.0;
const _startDegrees = -138.0;

enum _Span { week, month, year }

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

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
        final figures = _figures(sales);
        final ranked = _rankedMerchandise(
          state.operation?.street.orders ?? const <SaleOrder>[],
          _span,
          now,
        );
        final arcs = _arcs(_merchandiseSlices(ranked));
        final categories = _categories(ranked);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: pouInk,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarContrastEnforced: false,
          ),
          child: ColoredBox(
            color: _page,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final diameter = constraints.maxWidth * 0.70;
                final ringHeight = diameter + 52;
                return Column(
                  children: [
                    SafeArea(
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
                          const SizedBox(height: 2),
                          _Filters(
                            span: _span,
                            onChanged: (span) => setState(() => _span = span),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _Sheet(categories: categories)),
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
  final top = ranked.take(4).toList();
  if (top.isEmpty) {
    return [
      for (var index = 0; index < 4; index++)
        _Category(
          name: '—',
          cents: 0,
          percent: null,
          color: _neutral,
          asset: null,
          placeholder: true,
        ),
    ];
  }
  return [
    for (var index = 0; index < top.length; index++)
      _Category(
        name: top[index].name,
        cents: top[index].cents,
        percent: _share(top[index].cents, total),
        color: _sliceColors[index],
        asset: produceAsset(top[index].name),
        placeholder: false,
      ),
  ];
}

class _Slice {
  const _Slice({required this.cents, required this.color});

  final int cents;
  final Color color;
}

List<_Slice> _merchandiseSlices(List<_ProductRank> ranked) {
  if (ranked.isEmpty) return const [];
  final top = ranked.take(4).toList();
  final slices = <_Slice>[
    for (var index = 0; index < top.length; index++)
      _Slice(cents: top[index].cents, color: _sliceColors[index]),
  ];
  final rest = ranked.skip(4).fold<int>(0, (sum, product) => sum + product.cents);
  if (rest > 0) {
    slices.add(_Slice(cents: rest, color: _neutral));
  }
  return slices;
}

class _Arc {
  const _Arc({
    required this.sweepDegrees,
    required this.color,
    required this.label,
    required this.neutral,
  });

  final double sweepDegrees;
  final Color color;
  final String label;
  final bool neutral;
}

List<double> _structuralSweeps() {
  final weight = _structuralWeights.fold<double>(0, (sum, value) => sum + value);
  final available = 360 - _gapDegrees * _structuralWeights.length;
  return [
    for (final value in _structuralWeights) available * value / weight,
  ];
}

List<_Arc> _arcs(List<_Slice> slices) {
  final structural = _structuralSweeps();
  if (slices.isEmpty) {
    return [
      for (final sweep in structural)
        const _Arc(
          sweepDegrees: 0,
          color: _neutral,
          label: '—',
          neutral: true,
        ).copyWithSweep(sweep),
    ];
  }
  const stub = 8.0;
  final missing = 5 - slices.length;
  final available = 360 - _gapDegrees * 5 - stub * missing;
  final total = slices.fold<int>(0, (sum, slice) => sum + slice.cents);
  final arcs = <_Arc>[
    for (final slice in slices)
      _Arc(
        sweepDegrees: total == 0 ? 0 : available * slice.cents / total,
        color: slice.color,
        label: total == 0 ? '—' : '${_share(slice.cents, total) ?? 0}%',
        neutral: false,
      ),
    for (var index = 0; index < missing; index++)
      const _Arc(
        sweepDegrees: stub,
        color: _neutral,
        label: '—',
        neutral: true,
      ),
  ];
  return arcs;
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
              Positioned(
                left: draw.label.dx,
                top: draw.label.dy,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: _PercentPill(draw: draw),
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
    final reach = radius + stroke / 2 + 16;
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

class _PercentPill extends StatelessWidget {
  const _PercentPill({required this.draw});

  final _Draw draw;

  @override
  Widget build(BuildContext context) {
    final neutral = draw.arc.neutral;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: neutral
            ? const Color(0xFFF1F1F4)
            : draw.arc.color.withValues(alpha: 0.16),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          draw.arc.label,
          style: TextStyle(
            color: neutral ? _neutralInk : const Color(0xFF3A3A3C),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
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
                  color: _Span.values[index] == span ? pouInk : _idle,
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
  const _Sheet({required this.categories});

  final List<_Category> categories;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              'Categorias financeiras',
              style: TextStyle(
                color: pouInk,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _CategoryGrid(
                    categories: categories,
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.maxWidth,
    required this.maxHeight,
  });

  final List<_Category> categories;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    final usableHeight = math.max(0.0, maxHeight - 72);
    final cardWidth = (maxWidth - gap) / 2;
    final preferredHeight = cardWidth * 0.664;
    final cardHeight = preferredHeight * 2 + gap > usableHeight && usableHeight > gap
        ? (usableHeight - gap) / 2
        : preferredHeight;
    final gridWidth = maxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: gridWidth,
        child: Wrap(
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
        ),
      ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
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
                ),
                const SizedBox(width: 6),
                Text(
                  percent,
                  style: const TextStyle(
                    color: Color(0xFF8B8B90),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
              ],
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
            const Spacer(),
            _MerchandiseMark(category: category),
          ],
        ),
      ),
    );
  }
}

class _MerchandiseMark extends StatelessWidget {
  const _MerchandiseMark({required this.category});

  final _Category category;

  @override
  Widget build(BuildContext context) {
    final asset = category.asset;
    final letter = category.placeholder || category.name.trim().isEmpty
        ? ''
        : category.name.trim()[0].toUpperCase();
    return ClipOval(
      child: asset == null
          ? ColoredBox(
              color: category.placeholder ? _neutral : category.color,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          : Image.asset(asset, width: 34, height: 34, fit: BoxFit.cover),
    );
  }
}

extension on _Arc {
  _Arc copyWithSweep(double sweepDegrees) {
    return _Arc(
      sweepDegrees: sweepDegrees,
      color: color,
      label: label,
      neutral: neutral,
    );
  }
}
