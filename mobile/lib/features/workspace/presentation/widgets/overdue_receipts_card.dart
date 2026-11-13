import 'package:flutter/material.dart';

import '../../domain/rules/month_board.dart';
import '../operation_labels.dart';
import '../theme/workspace_colors.dart';

/// Home card for overdue receivables: collapsed stack preview or expanded list.
class OverdueReceiptsCard extends StatefulWidget {
  const OverdueReceiptsCard({
    super.key,
    required this.dues,
    required this.valuesHidden,
    required this.onOpenCustomer,
    this.expanded,
    this.onExpandedChanged,
  });

  final List<UpcomingDueCustomer> dues;
  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<OverdueReceiptsCard> createState() => _OverdueReceiptsCardState();
}

class _OverdueReceiptsCardState extends State<OverdueReceiptsCard> {
  static const _radius = 16.0;
  static const _ink = Color(0xFF0E0D0F);
  static const _muted = Color(0xFF6B7280);
  static const _divider = Color(0xFFE9E8EB);
  static const _danger = Color(0xFF9B1C1C);
  static const _pillBg = Color(0xFFF0F0F2);
  static const _layerMid = Color(0xFFFCFCFD);
  static const _layerBack = Color(0xFFF7F8FA);

  var _localExpanded = false;

  bool get _ownsExpanded => widget.onExpandedChanged == null;

  bool get _expanded =>
      _ownsExpanded ? _localExpanded : (widget.expanded ?? false);

  bool get _canExpand => widget.dues.length >= 2;

  bool get _showStack => _canExpand && !_expanded;

  @override
  void didUpdateWidget(covariant OverdueReceiptsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canExpand && _expanded) {
      if (_ownsExpanded) {
        _localExpanded = false;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onExpandedChanged?.call(false);
        });
      }
    }
  }

  void _toggleExpanded() {
    if (!_canExpand) return;
    final next = !_expanded;
    final notify = widget.onExpandedChanged;
    if (notify != null) {
      notify(next);
      return;
    }
    setState(() => _localExpanded = next);
  }

  @override
  Widget build(BuildContext context) {
    final showStack = _showStack;
    final count = widget.dues.length;
    final badgeLabel = count == 1 ? '1 cliente' : '$count clientes';

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
              badgeLabel: badgeLabel,
              hasOverdue: count > 0,
              canExpand: _canExpand,
              expanded: _expanded,
              onToggle: _toggleExpanded,
            ),
            _Body(
              dues: widget.dues,
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

const _stackRefWidth = 240.0;
const _stackInset1 = 10.0;
const _stackInset2 = 20.0;
const _stackDepth1 = 10.0;
const _stackDepth2 = 21.0;

class _Header extends StatelessWidget {
  const _Header({
    required this.badgeLabel,
    required this.hasOverdue,
    required this.canExpand,
    required this.expanded,
    required this.onToggle,
  });

  final String badgeLabel;
  final bool hasOverdue;
  final bool canExpand;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // Same soft gray pill as “Recebimentos do dia”; only the label color
    // signals overdue vs empty.
    const badgeBg = _OverdueReceiptsCardState._pillBg;
    final badgeFg = hasOverdue
        ? _OverdueReceiptsCardState._danger
        : _OverdueReceiptsCardState._muted;

    final row = Row(
      children: [
        const Expanded(
          child: Text(
            'Vencidos',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: workspaceFontPrimary,
              fontWeight: FontWeight.w700,
              color: _OverdueReceiptsCardState._ink,
            ),
          ),
        ),
        const SizedBox(width: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              badgeLabel,
              key: const Key('overdue_count'),
              style: TextStyle(
                fontSize: workspaceFontSecondary,
                fontWeight: FontWeight.w700,
                color: badgeFg,
              ),
            ),
          ),
        ),
        if (canExpand) ...[
          const SizedBox(width: 4),
          Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            key: const Key('overdue_chevron'),
            color: _OverdueReceiptsCardState._ink,
            size: 22,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
      child: canExpand
          ? InkWell(
              key: const Key('overdue_header'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: row,
            )
          : row,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.dues,
    required this.valuesHidden,
    required this.expanded,
    required this.canExpand,
    required this.onOpenCustomer,
    required this.onExpand,
  });

  final List<UpcomingDueCustomer> dues;
  final bool valuesHidden;
  final bool expanded;
  final bool canExpand;
  final ValueChanged<String> onOpenCustomer;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    if (dues.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          'Nenhum cliente em atraso.',
          style: TextStyle(
            fontSize: workspaceFontSecondary,
            color: _OverdueReceiptsCardState._muted,
          ),
        ),
      );
    }

    final visible = (!canExpand || expanded) ? dues : dues.sublist(0, 1);
    final hidden = canExpand && !expanded ? dues.length - 1 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          const Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: _OverdueReceiptsCardState._divider,
          ),
          _OverdueTile(
            due: visible[index],
            valuesHidden: valuesHidden,
            onOpenCustomer: () => onOpenCustomer(visible[index].customerId),
          ),
        ],
        if (hidden > 0)
          InkWell(
            key: const Key('overdue_more'),
            onTap: onExpand,
            child: Padding(
              // Align with the customer name (pad 16 + date 34 + gap 12).
              padding: const EdgeInsets.fromLTRB(62, 0, 16, 14),
              child: Text(
                hidden == 1 ? '+1 cliente' : '+$hidden clientes',
                style: const TextStyle(
                  fontSize: workspaceFontSecondary,
                  fontWeight: FontWeight.w500,
                  color: _OverdueReceiptsCardState._muted,
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

class _OverdueTile extends StatelessWidget {
  const _OverdueTile({
    required this.due,
    required this.valuesHidden,
    required this.onOpenCustomer,
  });

  final UpcomingDueCustomer due;
  final bool valuesHidden;
  final VoidCallback onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final parts = overdueDateParts(due.dueOn);
    return Material(
      color: Colors.white,
      child: InkWell(
        key: Key('overdue_${due.customerId}'),
        onTap: onOpenCustomer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      parts.day,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: _OverdueReceiptsCardState._danger,
                      ),
                    ),
                    Text(
                      parts.month,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        letterSpacing: 0.3,
                        color: _OverdueReceiptsCardState._danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  due.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: workspaceFontPrimary,
                    fontWeight: FontWeight.w700,
                    color: _OverdueReceiptsCardState._ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatBrl(due.amountCents, hidden: valuesHidden),
                key: Key('overdue_amount_${due.customerId}'),
                style: const TextStyle(
                  fontSize: workspaceFontPrimary,
                  fontWeight: FontWeight.w700,
                  color: _OverdueReceiptsCardState._ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _overdueMonths = [
  'JAN',
  'FEV',
  'MAR',
  'ABR',
  'MAI',
  'JUN',
  'JUL',
  'AGO',
  'SET',
  'OUT',
  'NOV',
  'DEZ',
];

({String day, String month}) overdueDateParts(String dueOn) {
  final parts = dueOn.split('-');
  if (parts.length != 3) return (day: '--', month: '---');
  final day = int.tryParse(parts[2]);
  final month = int.tryParse(parts[1]);
  if (day == null || month == null || month < 1 || month > 12) {
    return (day: '--', month: '---');
  }
  return (
    day: day.toString().padLeft(2, '0'),
    month: _overdueMonths[month - 1],
  );
}
