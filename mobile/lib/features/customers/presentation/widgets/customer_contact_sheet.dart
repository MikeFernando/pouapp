import 'package:flutter/material.dart';

import '../../domain/entities/customer_contact.dart';
import '../../domain/validation/customer_validators.dart';
import '../customer_messages.dart';

Future<ContactInput?> showCustomerContactSheet(
  BuildContext context, {
  required String customerId,
  CustomerContact? current,
}) {
  return showModalBottomSheet<ContactInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _ContactSheet(customerId: customerId, current: current),
  );
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.customerId, this.current});

  final String customerId;
  final CustomerContact? current;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late bool _primary;
  late bool _billing;
  late bool _delivery;
  late bool _whatsapp;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _name = TextEditingController(text: current?.name ?? '');
    _role = TextEditingController(text: current?.role ?? '');
    _phone = TextEditingController(text: current?.phone ?? '');
    _email = TextEditingController(text: current?.email ?? '');
    _primary = current?.isPrimary ?? false;
    _billing = current?.canReceiveBilling ?? false;
    _delivery = current?.canReceiveDelivery ?? false;
    _whatsapp = current?.canReceiveWhatsApp ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.92;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.current == null
                          ? 'Novo contato'
                          : 'Editar contato',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'As preferências ficam registradas. Nenhuma mensagem é enviada nesta versão.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('contact_name'),
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _role,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Função'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('contact_phone'),
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('contact_email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Contato principal'),
                      value: _primary,
                      onChanged: (value) => setState(() => _primary = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pode receber cobrança'),
                      value: _billing,
                      onChanged: (value) => setState(() => _billing = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pode receber entrega'),
                      value: _delivery,
                      onChanged: (value) => setState(() => _delivery = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pode receber WhatsApp'),
                      value: _whatsapp,
                      onChanged: (value) => setState(() => _whatsapp = value),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        key: const Key('contact_error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                key: const Key('contact_save'),
                onPressed: _save,
                child: const Text('Salvar contato'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final input = ContactInput(
      customerId: widget.customerId,
      name: _name.text,
      role: _role.text,
      phone: _phone.text,
      email: _email.text,
      isPrimary: _primary,
      canReceiveBilling: _billing,
      canReceiveDelivery: _delivery,
      canReceiveWhatsApp: _whatsapp,
    );
    final error = validateContactInput(input);
    if (error != null) {
      setState(() => _error = customerValidationMessage(error));
      return;
    }
    Navigator.of(context).pop(input);
  }
}
