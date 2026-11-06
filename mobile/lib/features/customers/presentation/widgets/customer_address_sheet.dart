import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/customer_address.dart';
import '../../domain/validation/customer_validators.dart';
import '../customer_messages.dart';

Future<AddressInput?> showCustomerAddressSheet(
  BuildContext context, {
  required String customerId,
  CustomerAddress? current,
}) {
  return showModalBottomSheet<AddressInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _AddressSheet(customerId: customerId, current: current),
  );
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({required this.customerId, this.current});

  final String customerId;
  final CustomerAddress? current;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final TextEditingController _label;
  late final TextEditingController _recipient;
  late final TextEditingController _zip;
  late final TextEditingController _street;
  late final TextEditingController _number;
  late final TextEditingController _complement;
  late final TextEditingController _neighborhood;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _reference;
  late bool _primary;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _label = TextEditingController(text: current?.label ?? '');
    _recipient = TextEditingController(text: current?.recipientName ?? '');
    _zip = TextEditingController(text: current?.zipCode ?? '');
    _street = TextEditingController(text: current?.street ?? '');
    _number = TextEditingController(text: current?.number ?? '');
    _complement = TextEditingController(text: current?.complement ?? '');
    _neighborhood = TextEditingController(text: current?.neighborhood ?? '');
    _city = TextEditingController(text: current?.city ?? '');
    _state = TextEditingController(text: current?.state ?? '');
    _reference = TextEditingController(text: current?.reference ?? '');
    _primary = current?.isPrimary ?? false;
  }

  @override
  void dispose() {
    for (final controller in [
      _label,
      _recipient,
      _zip,
      _street,
      _number,
      _complement,
      _neighborhood,
      _city,
      _state,
      _reference,
    ]) {
      controller.dispose();
    }
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
                          ? 'Novo endereço'
                          : 'Editar endereço',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('address_label'),
                      controller: _label,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Identificação',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _recipient,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Quem recebe',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('address_zip'),
                      controller: _zip,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'CEP'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('address_street'),
                      controller: _street,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Rua'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('address_number'),
                      controller: _number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Número'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _complement,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Complemento',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('address_neighborhood'),
                      controller: _neighborhood,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Bairro'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('address_city'),
                      controller: _city,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Cidade'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('address_state'),
                      controller: _state,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'UF'),
                    ),
                    TextField(
                      controller: _reference,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Referência',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Endereço principal'),
                      value: _primary,
                      onChanged: (value) => setState(() => _primary = value),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        key: const Key('address_error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                key: const Key('address_save'),
                onPressed: _save,
                child: const Text('Salvar endereço'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final input = AddressInput(
      customerId: widget.customerId,
      label: _label.text,
      recipientName: _recipient.text,
      zipCode: _zip.text,
      street: _street.text,
      number: _number.text,
      complement: _complement.text,
      neighborhood: _neighborhood.text,
      city: _city.text,
      state: _state.text,
      reference: _reference.text,
      isPrimary: _primary,
    );
    final error = validateAddressInput(input);
    if (error != null) {
      setState(() => _error = customerValidationMessage(error));
      return;
    }
    Navigator.of(context).pop(input);
  }
}
