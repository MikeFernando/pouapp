import 'package:flutter/material.dart';

import '../../domain/entities/street_ledger.dart';
import '../operation_labels.dart';
import '../street_actions.dart';
import '../street_input.dart';

class SaleFormPage extends StatefulWidget {
  const SaleFormPage({
    super.key,
    required this.visitId,
    required this.customerId,
    required this.customerName,
    this.order,
  });

  final String visitId;
  final String customerId;
  final String customerName;
  final SaleOrder? order;

  @override
  State<SaleFormPage> createState() => _SaleFormPageState();
}

class _SaleFormPageState extends State<SaleFormPage> {
  final _product = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  SaleUnit _unit = SaleUnit.kilogram;
  late List<SaleLine> _lines = [
    if (widget.order != null) ...widget.order!.lines,
  ];
  String? _error;

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  int get _total => _lines.fold(0, (sum, line) => sum + line.totalCents);

  @override
  Widget build(BuildContext context) {
    final correcting = widget.order != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(correcting ? 'Corrigir pedido' : 'Nova venda'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('sale_product'),
            controller: _product,
            decoration: const InputDecoration(
              labelText: 'Fruta ou verdura',
              hintText: 'Banana nanica',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sale_quantity'),
            controller: _quantity,
            decoration: const InputDecoration(labelText: 'Quantidade'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          SegmentedButton<SaleUnit>(
            segments: const [
              ButtonSegment(value: SaleUnit.kilogram, label: Text('kg')),
              ButtonSegment(value: SaleUnit.piece, label: Text('un')),
              ButtonSegment(value: SaleUnit.bunch, label: Text('maço')),
            ],
            selected: {_unit},
            onSelectionChanged: (value) => setState(() => _unit = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sale_price'),
            controller: _price,
            decoration: const InputDecoration(labelText: 'Preço unitário'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('sale_add_line'),
            onPressed: _addLine,
            child: const Text('Adicionar item'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          for (var index = 0; index < _lines.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_lines[index].productName),
              subtitle: Text(
                '${formatSaleQuantity(_lines[index].quantity, _lines[index].unit)} · ${formatBrl(_lines[index].unitPriceCents)}',
              ),
              trailing: Text(formatBrl(_lines[index].totalCents)),
            ),
          const Divider(),
          Text(
            'Total ${formatBrl(_total)}',
            key: const Key('sale_total'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('sale_save'),
            onPressed: _lines.isEmpty ? null : _save,
            child: const Text('Salvar venda'),
          ),
        ],
      ),
    );
  }

  void _addLine() {
    final quantity = parseDecimalQuantity(_quantity.text);
    final price = parseBrlToCents(_price.text);
    if (_product.text.trim().isEmpty || quantity == null || price == null) {
      setState(() => _error = 'Informe o produto, a quantidade e o preço.');
      return;
    }
    setState(() {
      _error = null;
      _lines = [
        ..._lines,
        SaleLine(
          productName: _product.text.trim(),
          quantity: quantity,
          unit: _unit,
          unitPriceCents: price,
        ),
      ];
      _product.clear();
      _quantity.clear();
      _price.clear();
    });
  }

  Future<void> _save() async {
    final saved = await applyStreetChange(
      context,
      SaveSale(
        visitId: widget.visitId,
        customerId: widget.customerId,
        customerName: widget.customerName,
        lines: _lines,
        orderId: widget.order?.id,
      ),
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }
}
