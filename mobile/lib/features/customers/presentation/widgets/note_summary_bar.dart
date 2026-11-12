import 'package:flutter/material.dart';

import '../../../../app/pou_top_snack.dart';
import '../../../workspace/domain/entities/street_ledger.dart';
import '../../../workspace/presentation/operation_labels.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import 'save_note_sheet.dart';

class _NoteSaveBaseline {
  const _NoteSaveBaseline({
    required this.itemCount,
    required this.totalCents,
    required this.paymentMethod,
    required this.dueOn,
  });

  final int itemCount;
  final int totalCents;
  final PaymentMethod? paymentMethod;
  final DateTime? dueOn;

  bool matches({
    required int itemCount,
    required int totalCents,
    required PaymentMethod? paymentMethod,
    required DateTime? dueOn,
  }) {
    return this.itemCount == itemCount &&
        this.totalCents == totalCents &&
        this.paymentMethod == paymentMethod &&
        this.dueOn == dueOn;
  }
}

/// Bottom summary for the open note: items, payment, due date, save CTA.
class NoteSummaryBar extends StatefulWidget {
  const NoteSummaryBar({
    super.key,
    required this.customer,
    required this.note,
    required this.paymentMethod,
    required this.onPickPayment,
    required this.onPickDue,
    this.onCommit,
  });

  final Customer customer;
  final CustomerNote? note;
  final PaymentMethod? paymentMethod;
  final VoidCallback onPickPayment;
  final VoidCallback? onPickDue;

  /// Persists the note for [choice]. Return false to keep Salvar enabled.
  final Future<bool> Function(SaveNoteChoice choice)? onCommit;

  @override
  State<NoteSummaryBar> createState() => _NoteSummaryBarState();
}

class _NoteSummaryBarState extends State<NoteSummaryBar> {
  static const _ink = Color(0xFF121417);
  static const _muted = Color(0xFF808793);
  static const _green = Color(0xFF305536);
  static const _border = Color(0xFFD9DBDE);
  static const _radius = 30.0;

  _NoteSaveBaseline? _baseline;

  @override
  void initState() {
    super.initState();
    _restoreBaselineIfAlreadySaved();
  }

  int get _itemCount => widget.note?.lines.length ?? 0;
  int get _totalCents => widget.note?.totalCents ?? 0;
  DateTime? get _dueOn => widget.note?.dueOn;

  String get _itemsLabel {
    if (_itemCount <= 0) return formatBrl(0);
    return formatBrl(_totalCents);
  }

  String get _paymentLabel {
    final method = widget.paymentMethod;
    if (method == null) return 'Selecione';
    return paymentMethodLabel(method);
  }

  String get _dueLabel {
    final due = _dueOn;
    if (due == null) return 'Sem data';
    return formatDay(due);
  }

  bool get _canSave {
    return _itemCount > 0 &&
        widget.paymentMethod != null &&
        _dueOn != null;
  }

  bool get _hasUnsavedChanges {
    final baseline = _baseline;
    if (baseline == null) return true;
    return !baseline.matches(
      itemCount: _itemCount,
      totalCents: _totalCents,
      paymentMethod: widget.paymentMethod,
      dueOn: _dueOn,
    );
  }

  bool get _readyToSave => _canSave && _hasUnsavedChanges;

  String? get _missingHint {
    final noItems = _itemCount <= 0;
    final noPay = widget.paymentMethod == null;
    final noDue = _dueOn == null;
    if (!noItems && !noPay && !noDue) return null;
    if (noItems && noPay && noDue) {
      return 'Adicione itens, pagamento e vencimento.';
    }
    if (noItems && noPay) return 'Adicione itens e a forma de pagamento.';
    if (noItems && noDue) return 'Adicione itens e o vencimento.';
    if (noPay && noDue) return 'Selecione pagamento e vencimento.';
    if (noItems) return 'Adicione pelo menos um item.';
    if (noPay) return 'Selecione a forma de pagamento.';
    return 'Escolha a data de vencimento.';
  }

  void _captureBaseline() {
    _baseline = _NoteSaveBaseline(
      itemCount: _itemCount,
      totalCents: _totalCents,
      paymentMethod: widget.paymentMethod,
      dueOn: _dueOn,
    );
  }

  void _restoreBaselineIfAlreadySaved() {
    if (_baseline != null) return;
    if (widget.note?.paymentMethod == null) return;
    if (!_canSave) return;
    _captureBaseline();
  }

  @override
  void didUpdateWidget(covariant NoteSummaryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer.id != widget.customer.id ||
        oldWidget.note?.id != widget.note?.id) {
      _baseline = null;
      _restoreBaselineIfAlreadySaved();
    }
  }

  Future<void> _save() async {
    final hint = _missingHint;
    if (hint != null) {
      await showPouTopSnack(
        context,
        message: hint,
        icon: Icons.info_outline_rounded,
        tone: PouTopSnackTone.info,
      );
      return;
    }
    if (!_hasUnsavedChanges) {
      await showPouTopSnack(
        context,
        message: 'Altere algo para salvar de novo.',
        icon: Icons.info_outline_rounded,
        tone: PouTopSnackTone.info,
      );
      return;
    }
    final current = widget.note;
    if (current == null) return;
    final choice = await showSaveNoteSheet(
      context: context,
      customer: widget.customer,
      note: current,
    );
    if (choice == null || !mounted) return;
    final committed = await widget.onCommit?.call(choice) ?? true;
    if (!committed || !mounted) return;
    setState(_captureBaseline);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final ready = _readyToSave;

    return Material(
      key: const Key('note_summary_bar'),
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
          border: Border(
            top: BorderSide(color: _border, width: 1),
            left: BorderSide(color: _border, width: 1),
            right: BorderSide(color: _border, width: 1),
          ),
        ),
        padding: EdgeInsets.fromLTRB(25, 22, 25, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('note_summary_payment'),
                        onTap: widget.onPickPayment,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Semantics(
                            button: true,
                            label:
                                '$_itemsLabel, forma de pagamento $_paymentLabel',
                            excludeSemantics: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _itemsLabel,
                                  key: const Key('note_summary_items'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _paymentLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('note_summary_due'),
                    onTap: widget.onPickDue,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Semantics(
                        button: true,
                        label: 'Vencimento $_dueLabel',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'VENCIMENTO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _green,
                                letterSpacing: 0.4,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dueLabel,
                              key: const Key('note_summary_due_date'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 62,
              child: FilledButton(
                key: const Key('receive_payment'),
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      ready ? _green : const Color(0xFFB7C4B9),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(31),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text(
                  'Salvar',
                  key: Key('customer_open_balance'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
