import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';

import '../../../../injection_container.dart';
import '../../../workspace/data/receivable_store.dart';
import '../../../workspace/domain/entities/receivable.dart';
import '../../../workspace/domain/entities/street_ledger.dart';
import '../../../workspace/presentation/bloc/company_operation_bloc.dart';
import '../../../workspace/presentation/operation_labels.dart';
import '../../domain/entities/customer.dart';

const noteActionColor = pouBrand;

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
    backgroundColor: pouCanvas,
    foregroundColor: pouBrand,
    side: const BorderSide(color: pouBrand, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
}

ButtonStyle noteQuietButton() {
  return TextButton.styleFrom(
    foregroundColor: pouBrand,
    minimumSize: const Size.fromHeight(44),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );
}

class CustomerAccountSection extends StatefulWidget {
  const CustomerAccountSection({
    super.key,
    required this.customer,
  });

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
    final account = _account;
    if (account == null || account.receipts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pagamentos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
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
            ],
          ),
        ),
      ),
    );
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
