import 'package:flutter/material.dart';

import '../../domain/entities/street_ledger.dart';
import '../operation_labels.dart';
import '../street_actions.dart';
import '../street_input.dart';

class PaymentFormPage extends StatefulWidget {
  const PaymentFormPage({
    super.key,
    required this.visitId,
    required this.customerId,
    required this.ledger,
  });

  final String visitId;
  final String customerId;
  final StreetLedger ledger;

  @override
  State<PaymentFormPage> createState() => _PaymentFormPageState();
}

class _PaymentFormPageState extends State<PaymentFormPage> {
  final _amount = TextEditingController();
  late final _date = TextEditingController(text: formatDay(DateTime.now()));
  PaymentMethod _method = PaymentMethod.cash;
  final _orders = <String>{};
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  List<SaleOrder> get _openOrders => [
    for (final order in widget.ledger.orders)
      if (order.customerId == widget.customerId &&
          order.recorded &&
          orderOpenCents(widget.ledger, order) > 0)
        order,
  ];

  @override
  Widget build(BuildContext context) {
    final balance = customerBalanceCents(widget.ledger, widget.customerId);
    final cents = parseBrlToCents(_amount.text);
    final next = cents == null ? null : balance - cents;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar pagamento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Saldo atual ${formatBrl(balance)}'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('payment_amount'),
            controller: _amount,
            decoration: const InputDecoration(labelText: 'Valor'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('payment_date'),
            controller: _date,
            decoration: const InputDecoration(labelText: 'Data'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(value: PaymentMethod.cash, label: Text('Dinheiro')),
              ButtonSegment(value: PaymentMethod.pix, label: Text('Pix')),
              ButtonSegment(value: PaymentMethod.card, label: Text('Cartão')),
            ],
            selected: {_method},
            onSelectionChanged: (value) =>
                setState(() => _method = value.first),
          ),
          const SizedBox(height: 16),
          Text(
            'Compras que este pagamento quita',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_openOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Nenhuma compra em aberto.'),
            )
          else
            for (final order in _openOrders)
              CheckboxListTile(
                key: Key('pay_order_${order.id}'),
                contentPadding: EdgeInsets.zero,
                value: _orders.contains(order.id),
                title: Text('Pedido ${order.code}'),
                subtitle: Text(
                  'Em aberto ${formatBrl(orderOpenCents(widget.ledger, order))}',
                ),
                onChanged: (selected) {
                  setState(() {
                    if (selected ?? false) {
                      _orders.add(order.id);
                    } else {
                      _orders.remove(order.id);
                    }
                  });
                },
              ),
          if (next != null) ...[
            const SizedBox(height: 8),
            Text(
              'Saldo depois do pagamento ${formatBrl(next)}',
              key: const Key('payment_preview'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('payment_save'),
            onPressed: _save,
            child: const Text('Salvar pagamento'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final cents = parseBrlToCents(_amount.text);
    final date = parseBrazilianDay(_date.text);
    if (cents == null || cents <= 0 || date == null) {
      setState(() => _error = 'Informe o valor e a data do pagamento.');
      return;
    }
    final saved = await applyStreetChange(
      context,
      RegisterPayment(
        visitId: widget.visitId,
        customerId: widget.customerId,
        amountCents: cents,
        paidOn: isoDate(date),
        method: _method,
        orderIds: _orders.toList(),
      ),
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }
}
