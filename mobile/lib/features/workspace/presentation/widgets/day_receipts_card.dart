import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/month_board.dart';
import '../operation_labels.dart';
import '../theme/workspace_colors.dart';

/// Home card for today's receivables: collapsed preview, expanded list, or empty.
class DayReceiptsCard extends StatefulWidget {
  const DayReceiptsCard({
    super.key,
    this.titleKey,
    required this.progress,
    required this.receipts,
    required this.valuesHidden,
    required this.onOpenCustomer,
  });

  final Key? titleKey;
  final VisitProgress progress;
  final List<DayReceiptCustomer> receipts;
  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;

  @override
  State<DayReceiptsCard> createState() => _DayReceiptsCardState();
}

class _DayReceiptsCardState extends State<DayReceiptsCard> {
  static const _radius = 16.0;
  static const _ink = Color(0xFF0E0D0F);
  static const _muted = Color(0xFF6B7280);
  static const _divider = Color(0xFFE9E8EB);
  static const _pillBg = Color(0xFFF0F0F2);

  /// Stack surfaces: pure white → cool grey → slightly deeper grey.
  static const _layerMid = Color(0xFFFCFCFD);
  static const _layerBack = Color(0xFFF7F8FA);

  var _expanded = false;

  bool get _canExpand => widget.receipts.length >= 2;

  bool get _showStack => _canExpand && !_expanded;

  @override
  void didUpdateWidget(covariant DayReceiptsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canExpand && _expanded) {
      _expanded = false;
    }
  }

  void _toggleExpanded() {
    if (!_canExpand) return;
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colors = workspaceColorsOf(context);
    final fraction = widget.progress.total == 0
        ? 0.0
        : widget.progress.done / widget.progress.total;
    final showStack = _showStack;

    final cardBody = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              titleKey: widget.titleKey,
              progressLabel:
                  '${widget.progress.done} de ${widget.progress.total}',
              accent: colors.accent,
              canExpand: _canExpand,
              expanded: _expanded,
              onToggle: _toggleExpanded,
              fraction: fraction,
            ),
            _Body(
              receipts: widget.receipts,
              valuesHidden: widget.valuesHidden,
              expanded: _expanded,
              canExpand: _canExpand,
              onOpenCustomer: widget.onOpenCustomer,
              onExpand: _toggleExpanded,
            ),
          ],
        ),
      ),
    );

    if (!showStack) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0E0D0F),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: cardBody,
      );
    }

    // iOS-style stack: paint back → mid → front. Depth/insets unchanged;
    // separation comes from tint + short downward shadows at each junction.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / _stackRefWidth;
        final inset1 = _stackInset1 * scale;
        final inset2 = _stackInset2 * scale;
        final depth1 = _stackDepth1 * scale;
        final depth2 = _stackDepth2 * scale;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: inset2,
              right: inset2,
              top: 0,
              bottom: 0,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: _layerBack,
                  borderRadius: BorderRadius.all(Radius.circular(_radius)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x140E0D0F),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: inset1,
              right: inset1,
              top: 0,
              bottom: depth2 - depth1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: _layerMid,
                  borderRadius: BorderRadius.all(Radius.circular(_radius)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x140E0D0F),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: depth2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0E0D0F),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: cardBody,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Reference proportions from the Fatima capture (main card ≈ 240px wide).
const _stackRefWidth = 240.0;
const _stackInset1 = 10.0;
const _stackInset2 = 20.0;
const _stackDepth1 = 10.0;
const _stackDepth2 = 21.0;

class _Header extends StatelessWidget {
  const _Header({
    required this.titleKey,
    required this.progressLabel,
    required this.accent,
    required this.canExpand,
    required this.expanded,
    required this.onToggle,
    required this.fraction,
  });

  final Key? titleKey;
  final String progressLabel;
  final Color accent;
  final bool canExpand;
  final bool expanded;
  final VoidCallback onToggle;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: Text(
            'Recebimentos do dia',
            key: titleKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: workspaceFontPrimary,
              fontWeight: FontWeight.w700,
              color: _DayReceiptsCardState._ink,
            ),
          ),
        ),
        const SizedBox(width: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _DayReceiptsCardState._pillBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              progressLabel,
              key: const Key('route_progress'),
              style: TextStyle(
                fontSize: workspaceFontSecondary,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ),
        if (canExpand) ...[
          const SizedBox(width: 4),
          Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            key: const Key('day_receipts_chevron'),
            color: _DayReceiptsCardState._ink,
            size: 22,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canExpand)
            InkWell(
              key: const Key('day_receipts_header'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: row,
            )
          else
            row,
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: const Color(0xFFEEF2F6),
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.receipts,
    required this.valuesHidden,
    required this.expanded,
    required this.canExpand,
    required this.onOpenCustomer,
    required this.onExpand,
  });

  final List<DayReceiptCustomer> receipts;
  final bool valuesHidden;
  final bool expanded;
  final bool canExpand;
  final ValueChanged<String> onOpenCustomer;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          'Nenhum recebimento com vencimento hoje.',
          style: TextStyle(
            fontSize: workspaceFontSecondary,
            color: _DayReceiptsCardState._muted,
          ),
        ),
      );
    }

    final visible = (!canExpand || expanded)
        ? receipts
        : receipts.sublist(0, 1);
    final hidden = canExpand && !expanded ? receipts.length - 1 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0)
            const Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: _DayReceiptsCardState._divider,
            ),
          _DayReceiptTile(
            receipt: visible[index],
            valuesHidden: valuesHidden,
            onOpenCustomer: () => onOpenCustomer(visible[index].customerId),
          ),
        ],
        if (hidden > 0)
          InkWell(
            key: const Key('day_receipts_more'),
            onTap: onExpand,
            child: Padding(
              // Align with the customer name (circle 22 + gap 12 + pad 16).
              padding: const EdgeInsets.fromLTRB(50, 0, 16, 14),
              child: Text(
                hidden == 1
                    ? '+1 recebimento'
                    : '+$hidden recebimentos',
                style: const TextStyle(
                  fontSize: workspaceFontSecondary,
                  fontWeight: FontWeight.w500,
                  color: _DayReceiptsCardState._muted,
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 4),
      ],
    );
  }
}

class _DayReceiptTile extends StatelessWidget {
  const _DayReceiptTile({
    required this.receipt,
    required this.valuesHidden,
    required this.onOpenCustomer,
  });

  final DayReceiptCustomer receipt;
  final bool valuesHidden;
  final VoidCallback onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final done = receipt.done;
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _VisitCheck(done: done, onTap: done ? null : onOpenCustomer),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                key: Key('day_receipt_${receipt.customerId}'),
                onTap: onOpenCustomer,
                child: Text(
                  receipt.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: workspaceFontPrimary,
                    fontWeight: FontWeight.w700,
                    color: done
                        ? const Color(0xFF8B97C2)
                        : _DayReceiptsCardState._ink,
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: const Color(0xFF8B97C2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatBrl(receipt.amountCents, hidden: valuesHidden),
              key: Key('day_receipt_amount_${receipt.customerId}'),
              style: TextStyle(
                fontSize: workspaceFontPrimary,
                fontWeight: FontWeight.w700,
                color: done
                    ? const Color(0xFF8B97C2)
                    : _DayReceiptsCardState._ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitCheck extends StatelessWidget {
  const _VisitCheck({required this.done, this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: done
          ? const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE7EDFF),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 22,
                height: 22,
                child: Icon(Icons.check, size: 15, color: pouAccent),
              ),
            )
          : Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: pouAccent, width: 1.6),
              ),
            ),
    );
  }
}
