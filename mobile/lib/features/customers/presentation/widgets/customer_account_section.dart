import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../../workspace/data/receivable_store.dart';
import '../../../workspace/presentation/bloc/company_operation_bloc.dart';
import '../../../workspace/domain/entities/receivable.dart';
import '../../../workspace/domain/entities/street_ledger.dart';
import '../../../workspace/domain/rules/receivable_rules.dart'
    hide paymentMethodLabel;
import '../../../workspace/presentation/operation_labels.dart';
import '../../../workspace/presentation/pages/charge_page.dart';
import '../../../workspace/presentation/pages/receipt_page.dart';
import '../../domain/entities/customer.dart';

const noteActionColor = Color(0xFF1E88E5);

ButtonStyle notePrimaryButton() {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    backgroundColor: noteActionColor,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
}

ButtonStyle noteSecondaryButton() {
  return OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    backgroundColor: Colors.white,
    foregroundColor: noteActionColor,
    side: const BorderSide(color: noteActionColor, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
}

ButtonStyle noteQuietButton() {
  return TextButton.styleFrom(
    foregroundColor: noteActionColor,
    minimumSize: const Size.fromHeight(44),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );
}

class CustomerAccountSection extends StatefulWidget {
  const CustomerAccountSection({super.key, required this.customer});

  final Customer customer;

  @override
  State<CustomerAccountSection> createState() => _CustomerAccountSectionState();
}

class _CustomerAccountSectionState extends State<CustomerAccountSection> {
  CustomerAccount? _account;
  String? _reversalFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CustomerAccountSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer.id != widget.customer.id) _load();
  }

  Future<void> _load() async {
    if (!sl.isRegistered<ReceivableStore>()) return;
    final account = await sl<ReceivableStore>().account(widget.customer.id);
    if (!mounted) return;
    setState(() => _account = account);
  }

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<ReceivableStore>()) return const SizedBox.shrink();
    final account = _account;
    final balance = account?.balanceCents;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Saldo em aberto',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 4),
              Text(
                balance == null
                    ? 'Carregando'
                    : balance < 0
                    ? 'Crédito de ${formatBrl(-balance)}'
                    : formatBrl(balance),
                key: const Key('customer_account_balance'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('receive_payment'),
                style: notePrimaryButton(),
                onPressed: () => _open(
                  ReceiptPage(
                    customerId: widget.customer.id,
                    customerName: widget.customer.name,
                  ),
                ),
                child: const Text('Receber pagamento'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const Key('send_pix_charge'),
                style: noteSecondaryButton(),
                onPressed: () =>
                    _open(ChargePage(customerId: widget.customer.id)),
                child: const Text('Enviar cobrança Pix'),
              ),
              TextButton(
                key: const Key('register_opening_debt'),
                style: noteQuietButton(),
                onPressed: () => _open(
                  OpeningDebtPage(
                    customerId: widget.customer.id,
                    customerName: widget.customer.name,
                  ),
                ),
                child: const Text('Registrar saldo inicial'),
              ),
              if (account != null)
                for (final receipt in account.receipts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${paymentMethodLabel(receipt.method)} · ${formatBrl(receipt.amountCents)}',
                    ),
                    subtitle: Text(
                      receipt.reversed
                          ? 'Estornado · ${formatDay(dateFromIso(receipt.paidOn))}'
                          : formatDay(dateFromIso(receipt.paidOn)),
                    ),
                    trailing: receipt.reversed
                        ? null
                        : TextButton(
                            key: Key('reverse_${receipt.id}'),
                            style: noteQuietButton().copyWith(
                              foregroundColor: const WidgetStatePropertyAll(
                                Color(0xFFC62828),
                              ),
                            ),
                            onPressed: () => _reverse(receipt.id),
                            child: const Text('Estornar'),
                          ),
                  ),
              if (account != null)
                for (final charge in account.charges)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(chargeStatusLabel(charge.status)),
                    subtitle: Text(formatBrl(charge.amountCents)),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(Widget page) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute<bool>(builder: (_) => page));
    if (changed == true) await _load();
  }

  Future<void> _reverse(String receiptId) async {
    _reversalFor ??= sl<ReceivableStore>().nextId();
    final reversalId = _reversalFor!;
    try {
      await sl<ReceivableStore>().reverseReceipt(
        reversalId: reversalId,
        receiptId: receiptId,
      );
      _reversalFor = null;
      if (sl.isRegistered<CompanyOperationBloc>()) {
        sl<CompanyOperationBloc>().add(const CompanyOperationRequested());
      }
      await _load();
    } on ReceivableException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
