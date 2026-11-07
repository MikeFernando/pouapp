import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/pou_app_colors.dart';

import '../../../../injection_container.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../customers/presentation/pages/customer_form_page.dart';
import '../../../customers/presentation/whatsapp_launch.dart';
import '../../data/receivable_store.dart';
import '../../domain/entities/receivable.dart';
import '../../domain/rules/receivable_rules.dart';
import '../operation_labels.dart';
import '../street_input.dart';
import 'business_settings_page.dart';

class ChargePage extends StatefulWidget {
  const ChargePage({super.key, required this.customerId, this.openChat});

  final String customerId;
  final Future<bool> Function(Uri uri)? openChat;

  @override
  State<ChargePage> createState() => _ChargePageState();
}

enum _ChargeChoice { note, total, custom }

class _ChargePageState extends State<ChargePage> {
  final _custom = TextEditingController();
  late final String _id = sl<ReceivableStore>().nextId();
  var _loading = true;
  var _opening = false;
  String? _error;
  Customer? _customer;
  CustomerAccount? _account;
  BusinessProfile? _profile;
  _ChargeChoice _choice = _ChargeChoice.total;
  String? _receivableId;
  ChargePreparation? _charge;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ChargePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      _customer = null;
      _account = null;
      _charge = null;
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _selection {
    if (_choice == _ChargeChoice.custom) return 'custom';
    if (_choice == _ChargeChoice.note && _receivableId != null) {
      return 'note:$_receivableId';
    }
    return 'total';
  }

  void _select(String? value) {
    if (value == null) return;
    setState(() {
      _charge = null;
      if (value == 'total') {
        _choice = _ChargeChoice.total;
        _receivableId = null;
      } else if (value == 'custom') {
        _choice = _ChargeChoice.custom;
        _receivableId = null;
      } else {
        _choice = _ChargeChoice.note;
        _receivableId = value.replaceFirst('note:', '');
      }
    });
  }

  Future<void> _load() async {
    final customer = await sl<CustomerRepository>().getCustomerById(
      widget.customerId,
    );
    final account = await sl<ReceivableStore>().account(widget.customerId);
    final profile = await sl<ReceivableStore>().readProfile();
    if (!mounted) return;
    customer.fold(
      (failure) => setState(() {
        _loading = false;
        _error = 'Cliente não encontrada.';
      }),
      (value) => setState(() {
        _loading = false;
        _customer = value;
        _account = account;
        _profile = profile;
        final open = account.openReceivables;
        if (open.length == 1) {
          _choice = _ChargeChoice.note;
          _receivableId = open.single.id;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final account = _account;
    final profile = _profile;
    if (_loading || customer == null || account == null || profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Enviar cobrança Pix')),
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : Center(child: Text(_error!)),
      );
    }
    final draft = _draft(customer, account, profile);
    final phone = _phone(customer);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: pouAppBlue,
        foregroundColor: Colors.white,
        title: const Text('Enviar cobrança Pix'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            customer.name,
            key: const Key('charge_customer'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            phone == null ? 'Sem telefone' : 'Telefone $phone',
            key: const Key('charge_phone'),
          ),
          const SizedBox(height: 12),
          if (account.openReceivables.isEmpty)
            const Text('Não há saldo em aberto para cobrar.')
          else
            RadioGroup<String>(
              groupValue: _selection,
              onChanged: _select,
              child: Column(
                children: [
                  for (final item in account.openReceivables)
                    RadioListTile<String>(
                      key: Key('charge_note_${item.id}'),
                      contentPadding: EdgeInsets.zero,
                      value: 'note:${item.id}',
                      title: Text('Saldo restante de ${item.description}'),
                      subtitle: Text(formatBrl(item.openCents)),
                    ),
                  RadioListTile<String>(
                    key: const Key('charge_total'),
                    contentPadding: EdgeInsets.zero,
                    value: 'total',
                    title: const Text('Saldo total em aberto'),
                    subtitle: Text(formatBrl(account.balanceCents)),
                  ),
                  RadioListTile<String>(
                    key: const Key('charge_custom'),
                    contentPadding: EdgeInsets.zero,
                    value: 'custom',
                    title: const Text('Outro valor'),
                  ),
                  if (_choice == _ChargeChoice.custom)
                    TextField(
                      key: const Key('charge_custom_amount'),
                      controller: _custom,
                      decoration: const InputDecoration(labelText: 'Valor'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _charge = null),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (draft.error != null)
            Text(
              draft.error!,
              key: const Key('charge_error'),
              style: const TextStyle(color: Color(0xFFB42318)),
            )
          else if (draft.message != null)
            Container(
              key: const Key('charge_preview'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Text(draft.message!),
            ),
          if (phone == null)
            TextButton(
              key: const Key('charge_fix_phone'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CustomerFormPage(customerId: widget.customerId),
                  ),
                );
                await _load();
              },
              child: const Text('Informar telefone'),
            ),
          if (!profile.hasPixKey || pixProfileProblem(profile) != null)
            TextButton(
              key: const Key('charge_fix_key'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BusinessSettingsPage(),
                  ),
                );
                await _load();
              },
              child: const Text('Configurar chave Pix'),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('charge_open_whatsapp'),
            onPressed: _opening || draft.message == null || phone == null
                ? null
                : () => _open(draft, phone),
            child: const Text('Abrir WhatsApp'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('charge_copy_message'),
            onPressed: draft.message == null
                ? null
                : () => _copy(draft.message!, 'Mensagem copiada.'),
            child: const Text('Copiar mensagem'),
          ),
          OutlinedButton(
            key: const Key('charge_copy_key'),
            onPressed: (profile.pixKey ?? '').trim().isEmpty
                ? null
                : () => _copy(profile.pixKey!.trim(), 'Chave Pix copiada.'),
            child: const Text('Copiar chave'),
          ),
          const SizedBox(height: 8),
          Text(
            _charge == null
                ? 'Abrir o WhatsApp não envia a mensagem nem registra pagamento.'
                : chargeStatusLabel(_charge!.status),
            key: const Key('charge_status'),
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  _Draft _draft(
    Customer customer,
    CustomerAccount account,
    BusinessProfile profile,
  ) {
    if (!profile.hasPixKey) {
      return const _Draft(error: 'Configure a chave Pix antes de cobrar.');
    }
    final problem = pixProfileProblem(profile);
    if (problem != null) return _Draft(error: problem);
    final open = account.openReceivables;
    late final int amount;
    late final String description;
    String? dueOn;
    if (_choice == _ChargeChoice.note) {
      final item = open.where((row) => row.id == _receivableId).firstOrNull;
      if (item == null) {
        return const _Draft(error: 'Escolha a conta que será cobrada.');
      }
      amount = item.openCents;
      description = chargeDescription(
        total: false,
        custom: false,
        receivableDescription: item.description,
      );
      dueOn = item.dueOn;
    } else if (_choice == _ChargeChoice.total) {
      amount = account.balanceCents;
      description = chargeDescription(total: true, custom: false);
      dueOn = sharedDueDate(open.map((item) => item.dueOn));
    } else {
      final typed = parseBrlToCents(_custom.text);
      if (typed == null) {
        return const _Draft(error: 'Informe o valor da cobrança.');
      }
      amount = typed;
      description = chargeDescription(total: false, custom: true);
    }
    final amountProblem = chargeAmountProblem(
      amountCents: amount,
      openCents: account.balanceCents < 0 ? 0 : account.balanceCents,
    );
    if (amountProblem != null) return _Draft(error: amountProblem);
    return _Draft(
      amountCents: amount,
      description: description,
      message: chargeMessage(
        customerName: customer.name,
        description: description,
        amountCents: amount,
        dueOn: dueOn,
        pixKey: profile.pixKey!.trim(),
        receiverName: profile.receiverName!.trim(),
      ),
    );
  }

  Future<void> _open(_Draft draft, String phone) async {
    if (_opening || draft.message == null) return;
    setState(() => _opening = true);
    final store = sl<ReceivableStore>();
    final prepared = await store.prepareCharge(
      id: _id,
      customerId: widget.customerId,
      amountCents: draft.amountCents,
      description: draft.description,
      message: draft.message!,
      phone: phone,
    );
    final uri = whatsAppChatUri(digits: phone, message: draft.message!);
    final open = widget.openChat ?? launchCustomerWhatsAppUri;
    final opened = await open(uri);
    ChargePreparation current = prepared;
    if (opened) current = await store.markWhatsAppOpened(prepared.id);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _charge = current;
      _error = opened ? null : 'Não foi possível abrir o WhatsApp.';
    });
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir o WhatsApp. A cobrança ficou salva neste aparelho e a mensagem continua aqui para copiar.',
          ),
        ),
      );
    }
  }

  Future<void> _copy(String text, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(confirmation)));
  }
}

class _Draft {
  const _Draft({
    this.amountCents = 0,
    this.description = '',
    this.message,
    this.error,
  });

  final int amountCents;
  final String description;
  final String? message;
  final String? error;
}

String? _phone(Customer customer) {
  final raw = (customer.mobilePhone ?? '').trim().isNotEmpty
      ? customer.mobilePhone
      : customer.phone;
  return whatsAppDigits(raw);
}
