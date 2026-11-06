import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../data/receivable_store.dart';
import '../../domain/entities/receivable.dart';
import '../../domain/entities/street_ledger.dart';
import '../operation_labels.dart';
import 'charge_page.dart';
import 'receipt_page.dart';

/// Purchases, due dates, payments and the open balance of one customer.
///
/// Opening this page does not record a payment. The charge button only
/// prepares the WhatsApp message.
class CustomerDebtPage extends StatefulWidget {
  const CustomerDebtPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<CustomerDebtPage> createState() => _CustomerDebtPageState();
}

class _CustomerDebtPageState extends State<CustomerDebtPage> {
  var _loading = true;
  String? _error;
  CustomerAccount? _account;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!sl.isRegistered<ReceivableStore>()) {
      setState(() {
        _loading = false;
        _error = 'A conta desta cliente ainda não está disponível.';
      });
      return;
    }
    try {
      final account = await sl<ReceivableStore>().account(widget.customerId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _account = account;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar a dívida.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.customerName),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _Notice(text: _error!, onRetry: _load)
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _BalanceCard(balanceCents: account?.balanceCents ?? 0),
                  const SizedBox(height: 16),
                  const _Heading('Compras'),
                  if (account == null || account.receivables.isEmpty)
                    const _Empty('Nenhuma compra nesta conta.')
                  else
                    for (final item in account.receivables)
                      _PurchaseTile(item: item),
                  const SizedBox(height: 8),
                  const _Heading('Pagamentos'),
                  if (account == null ||
                      account.receipts.every((receipt) => receipt.reversed))
                    const _Empty('Nenhum pagamento registrado.')
                  else
                    for (final receipt in account.receipts)
                      if (!receipt.reversed) _PaymentTile(receipt: receipt),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('receive_payment'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B3A2F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _open(
                      ReceiptPage(
                        customerId: widget.customerId,
                        customerName: widget.customerName,
                      ),
                    ),
                    child: const Text('Receber pagamento'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('send_pix_charge'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B3A2F),
                      side: const BorderSide(color: Color(0xFF1B3A2F)),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () =>
                        _open(ChargePage(customerId: widget.customerId)),
                    child: const Text('Enviar cobrança Pix'),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _open(Widget page) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute<bool>(builder: (_) => page));
    if (changed == true) await _load();
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceCents});

  final int balanceCents;

  @override
  Widget build(BuildContext context) {
    final credit = balanceCents < 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              credit ? 'Crédito disponível' : 'Saldo pendente',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 4),
            Text(
              formatBrl(credit ? -balanceCents : balanceCents),
              key: const Key('debt_balance'),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16342C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF16342C),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.item});

  final Receivable item;

  @override
  Widget build(BuildContext context) {
    final due = item.dueOn == null
        ? 'Sem vencimento'
        : 'Vence ${formatDay(dateFromIso(item.dueOn!))}';
    final state = item.openCents == 0
        ? 'Quitada'
        : 'Em aberto ${formatBrl(item.openCents)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.description),
        subtitle: Text('$due · $state'),
        trailing: Text(formatBrl(item.amountCents)),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.receipt});

  final AccountReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final credit = receipt.creditCents - receipt.appliedCreditCents;
    final note = credit > 0
        ? 'Crédito não alocado ${formatBrl(credit)}'
        : formatDay(dateFromIso(receipt.paidOn));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${paymentMethodLabel(receipt.method)} · ${formatBrl(receipt.amountCents)}',
        ),
        subtitle: Text(note),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
