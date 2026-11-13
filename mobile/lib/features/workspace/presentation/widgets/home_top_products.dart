import 'package:flutter/material.dart';

import '../../../catalog/presentation/produce_assets.dart';
import '../operation_labels.dart';
import '../top_billed_products.dart';

/// Horizontal strip of the month's top billed products.
///
/// Scrolls on its own and repeats the row so the motion never jumps.
class HomeTopProducts extends StatefulWidget {
  const HomeTopProducts({
    super.key,
    required this.products,
    required this.valuesHidden,
  });

  final List<TopBilledProduct> products;
  final bool valuesHidden;

  @override
  State<HomeTopProducts> createState() => _HomeTopProductsState();
}

class _HomeTopProductsState extends State<HomeTopProducts>
    with SingleTickerProviderStateMixin {
  static const _gap = 10.0;
  static const _pixelsPerSecond = 32.0;

  final _sequenceKey = GlobalKey();
  late final AnimationController _controller;
  var _sequenceWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLoop());
  }

  @override
  void didUpdateWidget(covariant HomeTopProducts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products ||
        oldWidget.valuesHidden != widget.valuesHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncLoop());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncLoop() {
    if (!mounted) return;
    final box = _sequenceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final width = box.size.width;
    if (width <= 0) return;
    if ((width - _sequenceWidth).abs() < 0.5 && _controller.isAnimating) {
      return;
    }
    final millis = (width / _pixelsPerSecond * 1000).round().clamp(3000, 90000);
    setState(() => _sequenceWidth = width);
    _controller
      ..duration = Duration(milliseconds: millis)
      ..repeat();
  }

  Widget _sequence({Key? key}) {
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < widget.products.length; index++) ...[
          if (index > 0) const SizedBox(width: _gap),
          _ProductChip(
            product: widget.products[index],
            valuesHidden: widget.valuesHidden,
          ),
        ],
        const SizedBox(width: _gap),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();
    final paused = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 72,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sequence = _sequenceWidth;
            final repeats = sequence <= 0
                ? 2
                : (constraints.maxWidth / sequence).ceil() + 1;
            if (paused) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.products.length,
                separatorBuilder: (context, index) => const SizedBox(width: _gap),
                itemBuilder: (context, index) => _ProductChip(
                  product: widget.products[index],
                  valuesHidden: widget.valuesHidden,
                ),
              );
            }
            return IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final dx = sequence <= 0
                      ? 0.0
                      : -_controller.value * sequence;
                  return OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: Row(
                        children: [
                          for (var copy = 0; copy < repeats; copy++)
                            _sequence(key: copy == 0 ? _sequenceKey : null),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.product,
    required this.valuesHidden,
  });

  final TopBilledProduct product;
  final bool valuesHidden;

  @override
  Widget build(BuildContext context) {
    final asset = produceAsset(product.name);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: asset == null
                  ? const ColoredBox(
                      color: Color(0xFFF1F1F4),
                      child: SizedBox(width: 44, height: 44),
                    )
                  : Image.asset(
                      asset,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xFFF1F1F4),
                            child: SizedBox(width: 44, height: 44),
                          ),
                    ),
            ),
            const SizedBox(width: 10),
            Text(
              formatBrl(product.cents, hidden: valuesHidden),
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF0E0D0F),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
