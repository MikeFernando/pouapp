import 'package:flutter/material.dart';

import '../../domain/entities/stock_board.dart';
import '../operation_labels.dart';

class ReceiptConferencePage extends StatelessWidget {
  const ReceiptConferencePage({super.key, required this.receipt});

  final StockReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = receivedTotalsByUnit(receipt.lines);
    return Scaffold(
      appBar: AppBar(title: Text(receipt.supplierName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${receiptStatusLabel(receipt.status)} · ${formatDay(receipt.receivedOn)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Material(
              color: Color(0xFFFFF3E0),
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Consulta de conferência. Nada foi salvo.',
                  key: Key('conference_notice'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Recebido por unidade', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in totals.entries)
                  Chip(
                    label: Text(
                      formatQuantity(entry.value, entry.key),
                      key: Key('conference_total_${entry.key.name}'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in receipt.lines) ...[
              const SizedBox(height: 12),
              _LineCard(line: line),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line});

  final ReceiptLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difference = line.difference;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.productName, style: theme.textTheme.titleMedium),
            Text(line.supplierName),
            const SizedBox(height: 8),
            Text(
              'Esperado: ${formatQuantity(line.expectedQuantity, line.unit)}',
            ),
            Text(
              'Recebido: ${formatQuantity(line.receivedQuantity, line.unit)}',
            ),
            Text(
              difference == 0
                  ? 'Sem divergência de quantidade.'
                  : 'Divergência: ${formatQuantity(difference, line.unit)}',
            ),
            if (line.hasWeight) ...[
              const SizedBox(height: 8),
              Text('Peso bruto: ${_kg(line.grossWeightKg)}'),
              Text('Tara: ${_kg(line.tareWeightKg)}'),
              Text('Peso líquido: ${_kg(line.netWeightKg)}'),
            ],
            if ((line.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(line.notes!),
            ],
          ],
        ),
      ),
    );
  }

  String _kg(double? value) {
    if (value == null) return 'não informado';
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1).replaceAll('.', ',');
    return '$text kg';
  }
}
