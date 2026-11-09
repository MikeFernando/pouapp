import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';

import '../../../../injection_container.dart';
import '../../data/receivable_store.dart';
import '../../domain/entities/receivable.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/receivable_rules.dart' hide paymentMethodLabel;
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';
import '../street_input.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final _amount = TextEditingController();
  final _tendered = TextEditingController();
  final _note = TextEditingController();
  late final _date = TextEditingController(text: formatDay(DateTime.now()));
  late final String _id = sl<ReceivableStore>().nextId();
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
    _tendered.dispose();
    _note.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final account = await sl<ReceivableStore>().account(widget.customerId);
    if (!mounted) return;
    setState(() {
      _account = account;
      _loading = false;
      if (_selected.isEmpty && account.openReceivables.length == 1) {
        _selected.add(account.openReceivables.single.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final amount = parseBrlToCents(_amount.text);
    final tendered = _method == PaymentMethod.cash
        ? parseBrlToCents(_tendered.text)
        : null;
    final selected = [
      if (account != null)
        for (final item in account.openReceivables)
          if (_selected.contains(item.id)) item,
    ];
    final plan = amount == null
        ? null
        : planReceipt(
            amountCents: amount,
            selected: selected,
            tenderedCents: tendered,
            allowCredit: _allowCredit,
          );
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F7),
      appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, title: const Text('Receber pagamento'),),
      body: _loading || account == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.customerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo anterior ${formatBrl(account.balanceCents)}',
                  key: const Key('receipt_previous'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<PaymentMethod>(
                  segments: const [
                    ButtonSegment(
                      value: PaymentMethod.cash,
                      label: Text('Dinheiro'),
                    ),
                    ButtonSegment(value: PaymentMethod.pix, label: Text('Pix')),
                  ],
                  selected: {_method},
                  onSelectionChanged: _saving
                      ? null
                      : (value) => setState(() => _method = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('receipt_amount'),
                  controller: _amount,
                  decoration: const InputDecoration(
                    labelText: 'Valor recebido',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_method == PaymentMethod.cash) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('receipt_tendered'),
                    controller: _tendered,
                    decoration: const InputDecoration(
                      labelText: 'Valor entregue pela cliente',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const Key('receipt_date'),
                  controller: _date,
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('receipt_note'),
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Observação',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dívidas que este pagamento quita',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (account.openReceivables.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Nenhuma dívida em aberto.'),
                  )
                else
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
                if (plan != null &&
                    plan.error != null &&
                    plan.error!.contains('crédito'))
                  CheckboxListTile(
                    key: const Key('receipt_allow_credit'),
                    contentPadding: EdgeInsets.zero,
                    value: _allowCredit,
                    title: const Text('Registrar o excedente como crédito'),
                    onChanged: _saving
                        ? null
                        : (checked) =>
                              setState(() => _allowCredit = checked ?? false),
                  ),
                if (amount != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Valor recebido ${formatBrl(amount)}',
                    key: const Key('receipt_received'),
                  ),
                  if (plan != null && plan.changeCents != null)
                    Text(
                      'Troco ${formatBrl(plan.changeCents!)}',
                      key: const Key('receipt_change'),
                    ),
                  if (plan != null && plan.error == null)
                    Text(
                      'Saldo restante ${formatBrl(account.balanceCents - amount)}',
                      key: const Key('receipt_remaining'),
                    ),
                ],
                if (_error != null || (plan?.error != null && amount != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error ?? plan!.error!,
                      key: const Key('receipt_error'),
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('receipt_save'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Gravando' : 'Confirmar recebimento'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O troco não vira crédito. O excedente só vira crédito se você marcar essa opção.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final receipt = await sl<ReceivableStore>().confirmReceipt(
        id: _id,
        customerId: widget.customerId,
        amountCents: amount,
        paidOn: isoDate(date),
        method: _method,
        receivableIds: _selected.toList(),
        tenderedCents: _method == PaymentMethod.cash
            ? parseBrlToCents(_tendered.text)
            : null,
        allowCredit: _allowCredit,
        note: _note.text,
      );
      if (!mounted) return;
      if (sl.isRegistered<CompanyOperationBloc>()) {
        sl<CompanyOperationBloc>().add(const CompanyOperationRequested());
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            receipt.alreadyRecorded
                ? 'Este recebimento já foi registrado.'
                : 'Recebimento de ${formatBrl(receipt.amountCents)} em ${paymentMethodLabel(receipt.method)}.',
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
      appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, title: const Text('Saldo inicial de dívida'),),
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
