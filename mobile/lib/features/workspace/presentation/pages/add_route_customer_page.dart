import 'package:flutter/material.dart';

import '../../domain/entities/street_ledger.dart';

class AddRouteCustomerPage extends StatefulWidget {
  const AddRouteCustomerPage({
    super.key,
    required this.customers,
    required this.onAdd,
  });

  final List<RouteCustomerOption> customers;
  final void Function(RouteCustomerOption customer, List<VisitReason> reasons)
  onAdd;

  @override
  State<AddRouteCustomerPage> createState() => _AddRouteCustomerPageState();
}

class _AddRouteCustomerPageState extends State<AddRouteCustomerPage> {
  String? _customerId;
  final _reasons = <VisitReason>{VisitReason.sale};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar ao roteiro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Motivo da visita'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final reason in VisitReason.values)
                FilterChip(
                  key: Key('reason_${reason.name}'),
                  label: Text(_label(reason)),
                  selected: _reasons.contains(reason),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _reasons.add(reason);
                      } else {
                        _reasons.remove(reason);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.customers.isEmpty)
            const Text('Nenhum cliente ativo para incluir.')
          else
            RadioGroup<String>(
              groupValue: _customerId,
              onChanged: (value) => setState(() => _customerId = value),
              child: Column(
                children: [
                  for (final customer in widget.customers)
                    RadioListTile<String>(
                      key: Key('route_customer_${customer.id}'),
                      value: customer.id,
                      title: Text(customer.name),
                      subtitle: Text(customer.address),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('confirm_add_customer'),
            onPressed: _customerId == null || _reasons.isEmpty
                ? null
                : () {
                    final customer = widget.customers.firstWhere(
                      (item) => item.id == _customerId,
                    );
                    widget.onAdd(customer, _reasons.toList());
                  },
            child: const Text('Incluir no roteiro'),
          ),
        ],
      ),
    );
  }

  String _label(VisitReason reason) {
    return switch (reason) {
      VisitReason.sale => 'Venda',
      VisitReason.delivery => 'Entrega',
      VisitReason.collection => 'Recebimento',
    };
  }
}
