import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../customers/domain/entities/customer_note.dart';
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
    this.servedCustomerIds = const {},
    this.frozenByCustomer = const {},
    this.onToggleServed,
    this.expanded,
    this.onExpandedChanged,
    this.noteLinesByCustomer = const {},
    this.onChecklistChanged,
  });

  final Key? titleKey;
  final VisitProgress progress;
  final List<DayReceiptCustomer> receipts;
  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;

  /// Checklist marks owned by the parent (survive home reload / navigation).
  final Set<String> servedCustomerIds;

  /// Values frozen at mark-time — keep Financeiro after the note is deleted.
  final Map<String, DayChecklistFrozen> frozenByCustomer;

  /// When marking served, [entry] is the frozen contribution; when unmarking, null.
  final void Function(String customerId, DayChecklistFrozen? entry)?
      onToggleServed;

  /// Expand state owned by the parent (survive home reload / navigation).
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  /// Draft note lines keyed by customer — used when marking received.
  final Map<String, List<NoteLine>> noteLinesByCustomer;

  /// Open amounts + products marked attended in the checklist (not yet paid).
  final ValueChanged<DayChecklistSnapshot>? onChecklistChanged;

  @override
  State<DayReceiptsCard> createState() => _DayReceiptsCardState();
}

class _DayReceiptsCardState extends State<DayReceiptsCard> {
  static const _radius = 16.0;
  static const _ink = Color(0xFF0E0D0F);
  static const _muted = Color(0xFF6B7280);
  static const _divider = Color(0xFFE9E8EB);
  static const _pillBg = Color(0xFFF0F0F2);
  /// Served row: green-gray, not blue-gray.
  static const _servedInk = Color(0xFF7E9086);
  static const _servedCheckBg = Color(0xFFE4F5EA);

  /// Stack surfaces: pure white → cool grey → slightly deeper grey.
  static const _layerMid = Color(0xFFFCFCFD);
  static const _layerBack = Color(0xFFF7F8FA);

  var _localExpanded = false;
  /// Local fallback when parent does not own the checklist (tests).
  final _localServedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _emitChecklistReceived();
  }

  bool get _ownsServed => widget.onToggleServed == null;

  bool get _ownsExpanded => widget.onExpandedChanged == null;

  Set<String> get _servedIds =>
      _ownsServed ? _localServedIds : widget.servedCustomerIds;

  bool get _expanded =>
      _ownsExpanded ? _localExpanded : (widget.expanded ?? false);

  bool get _canExpand => widget.receipts.length >= 2;

  bool get _showStack => _canExpand && !_expanded;

  bool _isServed(DayReceiptCustomer receipt) {
    return receipt.done || _servedIds.contains(receipt.customerId);
  }

  int get _doneCount {
    var count = 0;
    for (final receipt in widget.receipts) {
      if (_isServed(receipt)) count++;
    }
    return count;
  }

  DayChecklistFrozen _liveFreeze(DayReceiptCustomer receipt) {
    final products = <String, int>{};
    final lines = widget.noteLinesByCustomer[receipt.customerId] ?? const [];
    for (final line in lines) {
      final name = line.name.trim();
      if (name.isEmpty || line.totalCents <= 0) continue;
      products[name] = (products[name] ?? 0) + line.totalCents;
    }
    return DayChecklistFrozen(
      receivedCents: receipt.amountCents,
      productCents: products,
    );
  }

  DayChecklistSnapshot get _checklistSnapshot {
    var cents = 0;
    final products = <String, int>{};
    void add(DayChecklistFrozen entry) {
      if (entry.receivedCents <= 0) return;
      cents += entry.receivedCents;
      for (final item in entry.productCents.entries) {
        if (item.value <= 0) continue;
        products[item.key] = (products[item.key] ?? 0) + item.value;
      }
    }

    for (final receipt in widget.receipts) {
      if (receipt.done) continue;
      if (!_servedIds.contains(receipt.customerId)) continue;
      // Always use the current note so two customers selling the same
      // product add up, and unmarking removes that contribution.
      add(_liveFreeze(receipt));
    }
    return DayChecklistSnapshot(
      receivedCents: cents,
      productCents: products,
    );
  }

  void _emitChecklistReceived() {
    final snapshot = _checklistSnapshot;
    final notify = widget.onChecklistChanged;
    if (notify == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notify(snapshot);
    });
  }

  @override
  void didUpdateWidget(covariant DayReceiptsCard oldWidget) {
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
    if (_ownsServed) {
      final ids = {for (final receipt in widget.receipts) receipt.customerId};
      // Keep marks while the list is empty (reload flash).
      if (ids.isNotEmpty) {
        _localServedIds.removeWhere((id) => !ids.contains(id));
      }
    }
    if (oldWidget.receipts != widget.receipts ||
        oldWidget.servedCustomerIds != widget.servedCustomerIds ||
        oldWidget.frozenByCustomer != widget.frozenByCustomer ||
        oldWidget.noteLinesByCustomer != widget.noteLinesByCustomer) {
      _emitChecklistReceived();
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

  void _toggleServed(String customerId) {
    final owned = widget.onToggleServed;
    final marking = !_servedIds.contains(customerId);
    DayChecklistFrozen? entry;
    if (marking) {
      for (final receipt in widget.receipts) {
        if (receipt.customerId != customerId) continue;
        entry = _liveFreeze(receipt);
        break;
      }
    }
    if (owned != null) {
      owned(customerId, entry);
      return;
    }
    setState(() {
      if (!_localServedIds.add(customerId)) {
        _localServedIds.remove(customerId);
      }
    });
    _emitChecklistReceived();
  }

  @override
  Widget build(BuildContext context) {
    final colors = workspaceColorsOf(context);
    final total = widget.receipts.length;
    final done = _doneCount;
    final fraction = total == 0 ? 0.0 : done / total;
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
              progressLabel: '$done de $total',
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
              isServed: _isServed,
              onToggleServed: _toggleServed,
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
    required this.isServed,
    required this.onToggleServed,
    required this.onOpenCustomer,
    required this.onExpand,
  });

  final List<DayReceiptCustomer> receipts;
  final bool valuesHidden;
  final bool expanded;
  final bool canExpand;
  final bool Function(DayReceiptCustomer receipt) isServed;
  final ValueChanged<String> onToggleServed;
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
            served: isServed(visible[index]),
            onToggleServed: () => onToggleServed(visible[index].customerId),
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
    required this.served,
    required this.onToggleServed,
    required this.onOpenCustomer,
  });

  final DayReceiptCustomer receipt;
  final bool valuesHidden;
  final bool served;
  final VoidCallback onToggleServed;
  final VoidCallback onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _VisitCheck(
              key: Key('day_receipt_check_${receipt.customerId}'),
              done: served,
              locked: receipt.done,
              onTap: receipt.done ? null : onToggleServed,
            ),
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
                    color: served
                        ? _DayReceiptsCardState._servedInk
                        : _DayReceiptsCardState._ink,
                    decoration: served
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: _DayReceiptsCardState._servedInk,
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
                color: served
                    ? _DayReceiptsCardState._servedInk
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
  const _VisitCheck({
    super.key,
    required this.done,
    this.locked = false,
    this.onTap,
  });

  final bool done;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: onTap != null,
        checked: done,
        enabled: !locked,
        label: done ? 'Atendida' : 'Marcar como atendida',
        child: done
            ? const DecoratedBox(
                decoration: BoxDecoration(
                  color: _DayReceiptsCardState._servedCheckBg,
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
      ),
    );
  }
}
