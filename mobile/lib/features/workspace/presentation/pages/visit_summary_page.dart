import 'package:flutter/material.dart';

import '../../domain/entities/street_ledger.dart';
import '../operation_labels.dart';

class VisitSummaryPage extends StatelessWidget {
  const VisitSummaryPage({
    super.key,
    required this.visit,
    required this.ledger,
    required this.onNext,
  });

  final RouteVisit visit;
  final StreetLedger ledger;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final work = visitWork(ledger, visit.id);
    final balance = customerBalanceCents(ledger, visit.customerId);
    final lines = <String>[
      if (work.sales.isNotEmpty) 'Venda registrada',
      if (work.deliveries.isNotEmpty) 'Mercadoria entregue',
      if (work.payments.isNotEmpty)
        'Pagamento recebido ${formatBrl(work.payments.fold(0, (sum, payment) => sum + payment.amountCents))}',
      if (work.agreements.isNotEmpty)
        'Pagamento combinado ${formatDay(dateFromIso(work.agreements.last.agreedOn))}',
      if (work.corrections.isNotEmpty) 'Correção registrada',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Visita concluída')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            visit.customerName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          if (lines.isEmpty)
            const Text('Nenhuma venda, entrega ou pagamento nesta visita.')
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line, key: Key('summary_${line.hashCode}')),
              ),
          const SizedBox(height: 8),
          Text(
            'Saldo em aberto ${formatBrl(balance)}',
            key: const Key('summary_balance'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Concluir a visita não quita a conta.',
            key: Key('summary_unpaid_notice'),
          ),
          const SizedBox(height: 24),
          if (onNext != null)
            FilledButton(
              key: const Key('next_customer'),
              onPressed: onNext,
              child: const Text('Próxima cliente'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar ao roteiro'),
          ),
        ],
      ),
    );
  }
}
