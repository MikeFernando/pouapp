import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../app/pou_date_sheet.dart';
import '../../../../injection_container.dart';
import '../../../customers/presentation/customer_messages.dart';
import '../../../customers/presentation/whatsapp_launch.dart';
import '../../data/receivable_store.dart';
import '../../domain/entities/receivable.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/receivable_rules.dart' hide paymentMethodLabel;
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';
import '../street_input.dart';
import 'business_settings_page.dart';

const _receiptGreen = Color(0xFF146C43);
const _receiptGreenSoft = Color(0xFFE7F6EC);
const _receiptMuted = Color(0xFF8E8E93);
const _receiptField = Color(0xFFF2F2F4);

Future<bool> showReceiptSheet(
  BuildContext context, {
  required String customerId,
  required String customerName,
  String? customerPhone,
  String? customerMobilePhone,
  int owedCents = 0,
  ValueChanged<DateTime>? onRemainingDueSet,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => ReceiptPage(
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerMobilePhone: customerMobilePhone,
      owedCents: owedCents,
      onRemainingDueSet: onRemainingDueSet,
    ),
  );
  return result == true;
}

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerMobilePhone,
    this.owedCents = 0,
    this.onRemainingDueSet,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerMobilePhone;

  /// Open amount from the current note when the store has no debt yet.
  final int owedCents;
  final ValueChanged<DateTime>? onRemainingDueSet;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final _amount = TextEditingController();
  final _remainingDue = TextEditingController();
  late final _date = TextEditingController(text: formatDay(DateTime.now()));
  late final String _id = sl<ReceivableStore>().nextId();
  late final String _debtId = sl<ReceivableStore>().nextId();
  PaymentMethod _method = PaymentMethod.cash;
  final _selected = <String>{};
  var _allowCredit = false;
  var _loading = true;
  var _saving = false;
  String? _error;
  CustomerAccount? _account;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _remainingDue.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final account = await sl<ReceivableStore>().account(widget.customerId);
    if (!mounted) return;
    setState(() {
      _account = account;
      _loading = false;
      if (_selected.isEmpty && account.openReceivables.isNotEmpty) {
        _selected.addAll(account.openReceivables.map((item) => item.id));
      }
      final open = _openTargetCents;
      if (_amount.text.trim().isEmpty && open > 0) {
        _amount.text = _amountInputText(open);
      }
      if (_date.text.trim().isEmpty) {
        _date.text = formatDay(DateTime.now());
      }
    });
  }

  /// Amount field already shows `R$` via [prefixText]; keep only the number.
  String _amountInputText(int cents) {
    return formatBrl(cents).replaceFirst(RegExp(r'^-?R\$\s*'), '');
  }

  int get _openTargetCents {
    final account = _account;
    if (account != null && account.openReceivables.isNotEmpty) {
      if (_selected.isEmpty) {
        return account.openReceivables.fold<int>(
          0,
          (sum, item) => sum + item.openCents,
        );
      }
      return [
        for (final item in account.openReceivables)
          if (_selected.contains(item.id)) item.openCents,
      ].fold<int>(0, (sum, cents) => sum + cents);
    }
    return widget.owedCents;
  }

  Future<void> _pickDate({
    required TextEditingController controller,
    required String title,
    DateTime? firstDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = parseBrazilianDay(controller.text) ?? today;
    final picked = await showPouDateSheet(
      context,
      initial: current,
      title: title,
      firstDate: firstDate,
    );
    if (picked == null || !mounted) return;
    setState(() => controller.text = formatDay(picked));
  }

  String? get _customerWhatsAppDigits {
    return whatsAppDigits(widget.customerMobilePhone) ??
        whatsAppDigits(widget.customerPhone);
  }

  Future<void> _selectPix() async {
    setState(() => _method = PaymentMethod.pix);
    await _offerPixWhatsApp();
  }

  Future<void> _offerPixWhatsApp() async {
    final store = sl<ReceivableStore>();
    final profile = await store.readProfile();
    if (!mounted) return;

    final profileProblem = pixProfileProblem(profile);
    if (profileProblem != null) {
      final openSettings = await showDialog<bool>(
        context: context,
        barrierColor: const Color(0x990E0D0F),
        builder: (context) => const _PixSetupDialog(),
      );
      if (openSettings == true && mounted) {
        await showBusinessSettingsSheet(context);
      }
      return;
    }

    final amount = parseBrlToCents(_amount.text) ?? _openTargetCents;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o valor antes de enviar a chave Pix.'),
        ),
      );
      return;
    }

    final pixKey = profile.pixKey!.trim();
    final displayKey = _formattedPixKey(profile.pixKeyType, pixKey);
    // WhatsApp gets the raw key alone so the customer can copy-paste into the bank.
    final copyableKey = _copyablePixKey(profile.pixKeyType, pixKey);
    final message = chargeMessage(
      customerName: widget.customerName,
      description: chargeDescription(
        total: true,
        custom: amount != _openTargetCents,
      ),
      amountCents: amount,
      pixKey: copyableKey,
      receiverName: profile.receiverName!.trim(),
    );

    final send = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x990E0D0F),
      builder: (context) => _PixWhatsAppDialog(
        amountLabel: formatBrl(amount),
        pixKey: displayKey,
        receiverName: profile.receiverName!.trim(),
        message: message,
      ),
    );
    if (send != true || !mounted) return;

    final digits = _customerWhatsAppDigits;
    if (digits == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente sem telefone para abrir o WhatsApp.'),
        ),
      );
      return;
    }

    final chargeId = store.nextId();
    try {
      await store.prepareCharge(
        id: chargeId,
        customerId: widget.customerId,
        amountCents: amount,
        description: chargeDescription(
          total: true,
          custom: amount != _openTargetCents,
        ),
        message: message,
        phone: digits,
      );
      final opened = await launchCustomerWhatsApp(digits, message: message);
      if (opened) {
        await store.markWhatsAppOpened(chargeId);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    } on ReceivableException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final amount = parseBrlToCents(_amount.text);
    final openTarget = _openTargetCents;
    final selected = [
      if (account != null)
        for (final item in account.openReceivables)
          if (_selected.contains(item.id)) item,
    ];
    final planningSelected = selected.isNotEmpty
        ? selected
        : (openTarget > 0
              ? [
                  Receivable(
                    id: 'pending-note',
                    customerId: widget.customerId,
                    description: 'Nota em aberto',
                    amountCents: openTarget,
                    openCents: openTarget,
                    occurredOn: isoDate(DateTime.now()),
                  ),
                ]
              : selected);
    final plan = amount == null
        ? null
        : planReceipt(
            amountCents: amount,
            selected: planningSelected,
            allowCredit: _allowCredit,
          );
    final remainingCents = amount == null
        ? openTarget
        : (amount >= openTarget ? 0 : openTarget - amount);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = media.size.height - media.padding.top - kToolbarHeight;
    final balanceLabel = openTarget > 0
        ? formatBrl(openTarget)
        : formatBrl(account?.balanceCents ?? 0);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8D8DC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Receber pagamento',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: pouInk,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Material(
                        color: _receiptField,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(false),
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: pouInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_loading || account == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    DecoratedBox(
                      key: const Key('receipt_previous'),
                      decoration: BoxDecoration(
                        color: _receiptField,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Saldo em aberto',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _receiptMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              balanceLabel,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: pouInk,
                                letterSpacing: -0.8,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Valor total da dívida',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _receiptMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Forma de pagamento',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PaymentMethodCard(
                            key: const Key('receipt_method_cash'),
                            label: 'Dinheiro',
                            icon: Icons.payments_outlined,
                            selected: _method == PaymentMethod.cash,
                            onTap: _saving
                                ? null
                                : () => setState(
                                      () => _method = PaymentMethod.cash,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PaymentMethodCard(
                            key: const Key('receipt_method_pix'),
                            label: 'Pix',
                            icon: Icons.qr_code_2_rounded,
                            selected: _method == PaymentMethod.pix,
                            onTap: _saving ? null : _selectPix,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Valor recebido',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('receipt_amount'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: pouInk,
                      ),
                      decoration: InputDecoration(
                        prefixText: 'R\$ ',
                        prefixStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: pouInk,
                        ),
                        filled: true,
                        fillColor: _receiptField,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: pouAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Data do recebimento',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DateField(
                      key: const Key('receipt_date'),
                      value: _date.text,
                      placeholder: 'Selecionar data',
                      onTap: _saving
                          ? null
                          : () => _pickDate(
                                controller: _date,
                                title: 'Escolha a data do recebimento',
                              ),
                    ),
                    if (account.openReceivables.length > 1) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Dívidas que este pagamento quita',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: pouInk,
                        ),
                      ),
                      for (final item in account.openReceivables)
                        CheckboxListTile(
                          key: Key('receipt_debt_${item.id}'),
                          contentPadding: EdgeInsets.zero,
                          value: _selected.contains(item.id),
                          title: Text(item.description),
                          subtitle: Text(
                            'Em aberto ${formatBrl(item.openCents)}'
                            '${item.dueOn == null ? '' : ' · vence ${formatDay(dateFromIso(item.dueOn!))}'}',
                          ),
                          onChanged: _saving
                              ? null
                              : (checked) => setState(() {
                                  if (checked ?? false) {
                                    _selected.add(item.id);
                                  } else {
                                    _selected.remove(item.id);
                                  }
                                }),
                        ),
                    ],
                    if (plan != null &&
                        plan.error != null &&
                        plan.error!.contains('crédito')) ...[
                      CheckboxListTile(
                        key: const Key('receipt_allow_credit'),
                        contentPadding: EdgeInsets.zero,
                        value: _allowCredit,
                        title: const Text(
                          'Registrar o excedente como crédito',
                        ),
                        onChanged: _saving
                            ? null
                            : (checked) => setState(
                                  () => _allowCredit = checked ?? false,
                                ),
                      ),
                    ],
                    if (amount != null) ...[
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: Color(0xFFE9E8EB)),
                      const SizedBox(height: 16),
                      _SummaryRow(
                        label: 'Valor recebido',
                        value: formatBrl(amount),
                        valueKey: const Key('receipt_received'),
                        valueColor: _receiptGreen,
                        valueWeight: FontWeight.w700,
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: 'Saldo restante',
                        value: formatBrl(remainingCents),
                        valueKey: const Key('receipt_partial_remaining'),
                        valueColor: pouInk,
                        valueWeight: FontWeight.w800,
                        valueSize: 18,
                      ),
                    ],
                    if (remainingCents > 0 && amount != null) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Novo vencimento do restante',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DateField(
                        key: const Key('receipt_remaining_due'),
                        value: _remainingDue.text,
                        placeholder: 'Selecionar data',
                        onTap: _saving
                            ? null
                            : () {
                                  final now = DateTime.now();
                                  _pickDate(
                                    controller: _remainingDue,
                                    title: 'Escolha a data de vencimento',
                                    firstDate: DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    ),
                                  );
                                },
                      ),
                    ],
                    if (_error != null ||
                        (plan?.error != null &&
                            amount != null &&
                            planningSelected.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error ?? plan!.error!,
                          key: const Key('receipt_error'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB42318),
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        key: const Key('receipt_save'),
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: pouBrand,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: pouBrand.withValues(
                            alpha: 0.38,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          _saving ? 'Gravando' : 'Confirmar recebimento',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = parseBrlToCents(_amount.text);
    final date = parseBrazilianDay(_date.text);
    if (amount == null || date == null) {
      setState(() => _error = 'Informe o valor e a data do pagamento.');
      return;
    }
    final openTarget = _openTargetCents;
    final remainingCents = amount >= openTarget ? 0 : openTarget - amount;
    DateTime? remainingDue;
    if (remainingCents > 0) {
      remainingDue = parseBrazilianDay(_remainingDue.text);
      if (remainingDue == null) {
        setState(
          () => _error = 'Informe o novo vencimento do valor restante.',
        );
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final store = sl<ReceivableStore>();
      var receivableIds = _selected.toList();
      final existingOpen = _account?.openReceivables ?? const <Receivable>[];
      if (receivableIds.isEmpty && existingOpen.isNotEmpty) {
        receivableIds = [for (final item in existingOpen) item.id];
      }
      if (receivableIds.isEmpty) {
        if (openTarget <= 0) {
          setState(() {
            _saving = false;
            _error = 'Não há valor em aberto para receber.';
          });
          return;
        }
        await store.openDebt(
          id: _debtId,
          customerId: widget.customerId,
          amountCents: openTarget,
          description: 'Nota em aberto',
          dueOn: remainingDue == null ? null : isoDate(remainingDue),
        );
        receivableIds = [_debtId];
      }
      final receipt = await store.confirmReceipt(
        id: _id,
        customerId: widget.customerId,
        amountCents: amount,
        paidOn: isoDate(date),
        method: _method,
        receivableIds: receivableIds,
        allowCredit: _allowCredit,
      );
      if (remainingDue != null) {
        final dueIso = isoDate(remainingDue);
        for (final id in receivableIds) {
          await store.updateDueOn(id: id, dueOn: dueIso);
        }
        widget.onRemainingDueSet?.call(remainingDue);
      }
      if (!mounted) return;
      if (sl.isRegistered<CompanyOperationBloc>()) {
        sl<CompanyOperationBloc>().add(const CompanyOperationRequested());
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      final remainingText = remainingCents > 0
          ? ' Restam ${formatBrl(remainingCents)} para ${formatDay(remainingDue!)}.'
          : '';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            receipt.alreadyRecorded
                ? 'Este recebimento já foi registrado.'
                : 'Recebimento de ${formatBrl(receipt.amountCents)} em ${paymentMethodLabel(receipt.method)}.$remainingText',
          ),
        ),
      );
    } on ReceivableException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _receiptGreenSoft : _receiptField,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _receiptGreen : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? _receiptGreen : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? _receiptGreen : pouInk,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: _receiptGreen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String value;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    return Material(
      color: _receiptField,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  empty ? placeholder : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: empty ? _receiptMuted : pouInk,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.valueWeight,
    this.valueKey,
    this.valueSize = 16,
  });

  final String label;
  final String value;
  final Color valueColor;
  final FontWeight valueWeight;
  final Key? valueKey;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _receiptMuted,
            ),
          ),
        ),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: valueWeight,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

String _formattedPixKey(PixKeyType? type, String raw) {
  return switch (type) {
    PixKeyType.phone => formatPhone(raw),
    PixKeyType.cpfCnpj => formatDocument(raw),
    PixKeyType.email => raw.trim().replaceAll(' ', '').toLowerCase(),
    PixKeyType.random || null => raw.trim(),
  };
}

/// Digits/email only — banks reject masked phone/CPF when pasting a Pix key.
String _copyablePixKey(PixKeyType? type, String raw) {
  final trimmed = raw.trim();
  return switch (type) {
    PixKeyType.phone || PixKeyType.cpfCnpj =>
      trimmed.replaceAll(RegExp(r'\D'), ''),
    PixKeyType.email => trimmed.replaceAll(' ', '').toLowerCase(),
    PixKeyType.random || null => trimmed,
  };
}

class _PixWhatsAppDialog extends StatelessWidget {
  const _PixWhatsAppDialog({
    required this.amountLabel,
    required this.pixKey,
    required this.receiverName,
    required this.message,
  });

  final String amountLabel;
  final String pixKey;
  final String receiverName;
  final String message;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enviar chave Pix',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: pouInk,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Abre o WhatsApp da cliente com a mensagem pronta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _receiptMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  decoration: BoxDecoration(
                    color: _receiptField,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        amountLabel,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: pouInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pixKey,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _receiptGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        receiverName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _receiptMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    key: const Key('receipt_pix_whatsapp_send'),
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: pouBrand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Enviar no WhatsApp'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('receipt_pix_whatsapp_skip'),
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Agora não'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PixSetupDialog extends StatelessWidget {
  const _PixSetupDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cadastre sua chave Pix',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: pouInk,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Para enviar a cobrança no WhatsApp, salve sua chave Pix nas configurações.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _receiptMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const Key('receipt_pix_open_settings'),
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: pouBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Cadastrar chave'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Agora não'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OpeningDebtPage extends StatefulWidget {
  const OpeningDebtPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<OpeningDebtPage> createState() => _OpeningDebtPageState();
}

class _OpeningDebtPageState extends State<OpeningDebtPage> {
  final _amount = TextEditingController();
  final _due = TextEditingController();
  late final String _id = sl<ReceivableStore>().nextId();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _due.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pouAppBlue,
        foregroundColor: pouCanvas,
        title: const Text('Saldo inicial de dívida'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.customerName),
          const SizedBox(height: 8),
          const Text(
            'Este lançamento não é uma venda do dia e não mexe no estoque.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('opening_debt_amount'),
            controller: _amount,
            decoration: const InputDecoration(labelText: 'Valor'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('opening_debt_due'),
            controller: _due,
            decoration: const InputDecoration(
              labelText: 'Vencimento',
              hintText: 'dd/mm/aaaa',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('opening_debt_save'),
            onPressed: _saving ? null : _save,
            child: const Text('Registrar saldo inicial'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = parseBrlToCents(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Informe o valor da dívida.');
      return;
    }
    String? dueOn;
    if (_due.text.trim().isNotEmpty) {
      final due = parseBrazilianDay(_due.text);
      if (due == null) {
        setState(() => _error = 'Informe o vencimento como dd/mm/aaaa.');
        return;
      }
      dueOn = isoDate(due);
    }
    setState(() => _saving = true);
    try {
      await sl<ReceivableStore>().openDebt(
        id: _id,
        customerId: widget.customerId,
        amountCents: amount,
        dueOn: dueOn,
      );
      if (!mounted) return;
      if (sl.isRegistered<CompanyOperationBloc>()) {
        sl<CompanyOperationBloc>().add(const CompanyOperationRequested());
      }
      Navigator.of(context).pop(true);
    } on ReceivableException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }
}
