import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';

import '../../../../injection_container.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../customers/domain/entities/customer_note.dart';
import '../../../customers/domain/repositories/customer_note_repository.dart';
import '../../../customers/domain/rules/note_rules.dart';
import '../../data/delivery_store.dart';
import '../../data/receivable_store.dart';
import '../../domain/entities/receivable.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/receivable_rules.dart';
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';
import '../street_input.dart';

class DeliveryReviewPage extends StatefulWidget {
  const DeliveryReviewPage({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.noteId,
  });

  final String customerId;
  final String customerName;
  final String noteId;

  @override
  State<DeliveryReviewPage> createState() => _DeliveryReviewPageState();
}

class _DeliveryReviewPageState extends State<DeliveryReviewPage> {
  final _amount = TextEditingController();
  final _tendered = TextEditingController();
  late final _date = TextEditingController(text: formatDay(DateTime.now()));
  String? _paymentId;
  PaymentMethod _method = PaymentMethod.cash;
  final _selected = <String>{};
  var _allowCredit = false;
  var _applyCredit = false;
  var _loading = true;
  var _saving = false;
  String? _error;
  CustomerNote? _note;
  CustomerAccount? _account;

  @override
  void initState() {
    super.initState();
    if (sl.isRegistered<DeliveryStore>()) {
      _paymentId = sl<DeliveryStore>().nextId();
    }
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _tendered.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final note = await sl<CustomerNoteRepository>().note(widget.noteId);
    final account = await sl<ReceivableStore>().account(widget.customerId);
    if (!mounted) return;
    note.fold(
      (_) => setState(() {
        _loading = false;
        _error = 'Nota não encontrada.';
      }),
      (value) => setState(() {
        _loading = false;
        _note = value;
        _account = account;
        _selected
          ..clear()
          ..add(saleReceivableId(value.id));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    final account = _account;
    if (_loading || note == null || account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmar entrega')),
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : Center(child: Text(_error!)),
      );
    }
    final amount = parseBrlToCents(_amount.text);
    final tendered = _method == PaymentMethod.cash
        ? parseBrlToCents(_tendered.text)
        : null;
    final sale = _sale(note);
    final choices = [
      ...account.openReceivables,
      if (note.status == NoteStatus.draft) sale,
    ];
    final selected = [
      for (final id in _selected)
        if (choices.where((item) => item.id == id).isNotEmpty)
          choices.firstWhere((item) => item.id == id),
    ];
    final plan = amount == null
        ? null
        : planReceipt(
            amountCents: amount,
            selected: selected,
            tenderedCents: tendered,
            allowCredit: _allowCredit,
          );
    final creditUses = _applyCredit && plan?.error == null
        ? planCreditUse(
            availableCents: account.creditCents,
            selected: selected,
            alreadyAllocated: plan?.allocations ?? const [],
          )
        : const <PaymentShare>[];
    final predicted = _predicted(
      account: account,
      saleCents: note.totalCents,
      plan: plan,
      creditUses: creditUses,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: pouAppBlue,
        foregroundColor: Colors.white,
        title: const Text('Confirmar entrega'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.customerName,
            key: const Key('delivery_customer'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Saldo anterior ${formatBrl(account.balanceCents)}',
            key: const Key('delivery_previous'),
          ),
          Text(
            'Vencimento desta compra ${note.dueOn == null ? 'sem data' : formatDay(note.dueOn!)}',
            key: const Key('delivery_due'),
          ),
          const SizedBox(height: 12),
          for (final line in note.lines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.name),
              subtitle: Text(
                '${_quantity(line)} · ${formatBrl(line.unitPriceCents)}',
              ),
              trailing: Text(formatBrl(line.totalCents)),
            ),
          Text(
            'Total ${formatBrl(note.totalCents)}',
            key: const Key('delivery_total'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (note.status == NoteStatus.delivered)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Esta entrega já foi confirmada. Reabrir a nota não cria outra venda.',
                key: Key('delivery_already'),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            const Text(
              'Pagamento opcional',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
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
              key: const Key('delivery_pay_amount'),
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
                key: const Key('delivery_tendered'),
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
              key: const Key('delivery_pay_date'),
              controller: _date,
              decoration: const InputDecoration(
                labelText: 'Data do pagamento',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text('O pagamento quita somente o que estiver marcado.'),
            CheckboxListTile(
              key: const Key('delivery_include_sale'),
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(sale.id),
              title: const Text('Esta compra'),
              subtitle: Text(formatBrl(note.totalCents)),
              onChanged: _saving
                  ? null
                  : (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(sale.id);
                      } else {
                        _selected.remove(sale.id);
                      }
                    }),
            ),
            for (final debt in account.openReceivables)
              CheckboxListTile(
                key: Key('delivery_debt_${debt.id}'),
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(debt.id),
                title: Text(debt.description),
                subtitle: Text('Em aberto ${formatBrl(debt.openCents)}'),
                onChanged: _saving
                    ? null
                    : (checked) => setState(() {
                        if (checked ?? false) {
                          _selected.add(debt.id);
                        } else {
                          _selected.remove(debt.id);
                        }
                      }),
              ),
            if (plan != null &&
                plan.error != null &&
                plan.error!.contains('crédito'))
              CheckboxListTile(
                key: const Key('delivery_allow_credit'),
                contentPadding: EdgeInsets.zero,
                value: _allowCredit,
                title: const Text('Registrar o excedente como crédito'),
                onChanged: _saving
                    ? null
                    : (checked) =>
                          setState(() => _allowCredit = checked ?? false),
              ),
            if (account.creditCents > 0)
              CheckboxListTile(
                key: const Key('delivery_apply_credit'),
                contentPadding: EdgeInsets.zero,
                value: _applyCredit,
                title: Text(
                  'Usar crédito de ${formatBrl(account.creditCents)}',
                ),
                onChanged: _saving
                    ? null
                    : (checked) =>
                          setState(() => _applyCredit = checked ?? false),
              ),
            if (plan != null && plan.error == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _splitText(plan.allocations, creditUses, sale.id, account),
                  key: const Key('delivery_split'),
                ),
              ),
            if (plan != null && plan.changeCents != null)
              Text(
                'Troco ${formatBrl(plan.changeCents!)}',
                key: const Key('delivery_change'),
              ),
            Text(
              'Saldo previsto ${formatBrl(predicted)}',
              key: const Key('delivery_predicted'),
            ),
            if (_error != null || (plan?.error != null && amount != null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error ?? plan!.error!,
                  key: const Key('delivery_error'),
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('delivery_save'),
              onPressed: _saving ? null : () => _save(note, amount),
              child: Text(_saving ? 'Gravando' : 'Confirmar entrega'),
            ),
          ],
        ],
      ),
    );
  }

  Receivable _sale(CustomerNote note) {
    return Receivable(
      id: saleReceivableId(note.id),
      customerId: note.customerId,
      description: 'Esta compra',
      amountCents: note.totalCents,
      openCents: note.totalCents,
      occurredOn: isoDate(DateTime.now()),
      dueOn: note.dueOn == null ? null : isoDate(note.dueOn!),
    );
  }

  int _predicted({
    required CustomerAccount account,
    required int saleCents,
    required ReceiptPlan? plan,
    required List<PaymentShare> creditUses,
  }) {
    final allocated = plan == null || plan.error != null
        ? 0
        : plan.allocatedCents;
    final createdCredit = plan == null || plan.error != null
        ? 0
        : plan.creditCents;
    final usedCredit = creditUses.fold<int>(
      0,
      (sum, share) => sum + share.amountCents,
    );
    final nextOpen = account.openCents + saleCents - allocated - usedCredit;
    final nextCredit = account.creditCents + createdCredit - usedCredit;
    if (nextOpen <= 0) return -nextCredit;
    return nextOpen;
  }

  String _splitText(
    List<PaymentShare> allocations,
    List<PaymentShare> creditUses,
    String saleId,
    CustomerAccount account,
  ) {
    final parts = <String>[
      for (final share in allocations)
        '${formatBrl(share.amountCents)} em ${_name(share.orderId, saleId, account)}',
      for (final share in creditUses)
        '${formatBrl(share.amountCents)} de crédito em ${_name(share.orderId, saleId, account)}',
    ];
    if (parts.isEmpty) {
      return 'Nenhum valor será recebido. A compra fica fiada.';
    }
    return parts.join('\n');
  }

  String _name(String id, String saleId, CustomerAccount account) {
    if (id == saleId) return 'esta compra';
    for (final debt in account.receivables) {
      if (debt.id == id) return debt.description;
    }
    return 'dívida';
  }

  String _quantity(NoteLine line) {
    final shown = displayQuantity(line.unit, line.quantity);
    final text = shown == shown.roundToDouble()
        ? shown.toStringAsFixed(0)
        : shown.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
    final unit = switch (line.unit) {
      CatalogUnit.kilogram => 'kg',
      CatalogUnit.piece => 'un',
      CatalogUnit.bunch => 'maço',
      CatalogUnit.box => 'cx',
      CatalogUnit.dozen => 'dúzia',
    };
    return '$text $unit';
  }

  Future<void> _save(CustomerNote note, int? amount) async {
    if (_saving) return;
    DeliveryPayment? payment;
    if (_amount.text.trim().isNotEmpty) {
      final date = parseBrazilianDay(_date.text);
      if (amount == null || amount <= 0 || date == null || _paymentId == null) {
        setState(() => _error = 'Informe o valor e a data do pagamento.');
        return;
      }
      payment = DeliveryPayment(
        id: _paymentId!,
        amountCents: amount,
        paidOn: isoDate(date),
        method: _method,
        receivableIds: _selected.toList(),
        tenderedCents: _method == PaymentMethod.cash
            ? parseBrlToCents(_tendered.text)
            : null,
        allowCredit: _allowCredit,
        applyCredit: _applyCredit,
      );
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await sl<DeliveryStore>().confirm(
        noteId: note.id,
        payment: payment,
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
            result.alreadyRecorded
                ? 'Esta entrega já estava confirmada.'
                : 'Entrega de ${formatBrl(result.totalCents)} confirmada.',
          ),
        ),
      );
    } on DeliveryException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }
}
