import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/entities/customer.dart';
import '../../domain/validation/customer_validators.dart';
import '../bloc/customer_form_bloc.dart';
import '../customer_messages.dart';

class CustomerFormPage extends StatelessWidget {
  const CustomerFormPage({super.key, this.customerId});

  final String? customerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          di.sl<CustomerFormBloc>()
            ..add(CustomerFormStarted(customerId: customerId)),
      child: const CustomerFormView(),
    );
  }
}

class CustomerFormView extends StatefulWidget {
  const CustomerFormView({super.key});

  @override
  State<CustomerFormView> createState() => _CustomerFormViewState();
}

class _CustomerFormViewState extends State<CustomerFormView> {
  final _name = TextEditingController();
  final _tradeName = TextEditingController();
  final _document = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _mobile = TextEditingController();
  final _notes = TextEditingController();
  var _type = CustomerType.company;
  var _status = CustomerStatus.active;
  var _filled = false;
  var _dirty = false;
  var _submitting = false;
  CustomerValidationError? _fieldError;

  @override
  void dispose() {
    _name.dispose();
    _tradeName.dispose();
    _document.dispose();
    _email.dispose();
    _phone.dispose();
    _mobile.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerFormBloc, CustomerFormState>(
      listenWhen: (previous, current) =>
          previous.messageToken != current.messageToken ||
          previous.status != current.status,
      listener: (context, state) {
        if (state.message != null) {
          _submitting = false;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message!)));
        }
        if (state.saved) {
          _dirty = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop(true);
          });
        }
      },
      builder: (context, state) {
        _applyCustomer(state);
        final saving = _submitting || state.status == CustomerFormStatus.saving;
        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop || !_dirty) return;
            final discard = await _confirmDiscard();
            if (discard && context.mounted) {
              setState(() => _dirty = false);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).pop();
              });
            }
          },
          child: Scaffold(
            appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, title: Text(
                state.customerId == null ? 'Novo cliente' : 'Editar cliente',
              ),),
            body: _body(context, state, saving),
            bottomNavigationBar: _actions(context, state, saving),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CustomerFormState state, bool saving) {
    if (state.status == CustomerFormStatus.initial ||
        state.status == CustomerFormStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando cliente'),
      );
    }
    if (state.status == CustomerFormStatus.failure && state.customer == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(state.message ?? 'Não foi possível abrir o cliente.'),
        ),
      );
    }

    final creating = state.customerId == null;
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!creating) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('customer_type_individual'),
                    label: const Text('Pessoa física'),
                    selected: _type == CustomerType.individual,
                    onSelected: saving
                        ? null
                        : (_) => setState(() {
                            _type = CustomerType.individual;
                            _dirty = true;
                          }),
                  ),
                  ChoiceChip(
                    key: const Key('customer_type_company'),
                    label: const Text('Pessoa jurídica'),
                    selected: _type == CustomerType.company,
                    onSelected: saving
                        ? null
                        : (_) => setState(() {
                            _type = CustomerType.company;
                            _dirty = true;
                          }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              key: const Key('customer_name'),
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: creating ? 'Nome' : 'Nome ou razão social',
              ),
              onChanged: _markDirty,
            ),
            if (!creating) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('customer_trade_name'),
                controller: _tradeName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Nome fantasia'),
                onChanged: _markDirty,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('customer_document'),
                controller: _document,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
                enabled: !saving,
                decoration: InputDecoration(
                  labelText: _type == CustomerType.individual ? 'CPF' : 'CNPJ',
                ),
                onChanged: _markDirty,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('customer_email'),
                controller: _email,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'E-mail'),
                onChanged: _markDirty,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('customer_phone'),
              controller: _phone,
              textInputAction: creating
                  ? TextInputAction.done
                  : TextInputAction.next,
              keyboardType: TextInputType.phone,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: 'Telefone (opcional)',
              ),
              onChanged: _markDirty,
            ),
            if (!creating) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('customer_mobile'),
                controller: _mobile,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Celular (opcional)',
                ),
                onChanged: _markDirty,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('customer_notes'),
                controller: _notes,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Observações'),
                onChanged: _markDirty,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('customer_status_active'),
                    label: const Text('Ativo'),
                    selected: _status == CustomerStatus.active,
                    onSelected: saving
                        ? null
                        : (_) => setState(() {
                            _status = CustomerStatus.active;
                            _dirty = true;
                          }),
                  ),
                  ChoiceChip(
                    key: const Key('customer_status_inactive'),
                    label: const Text('Desativado'),
                    selected: _status == CustomerStatus.inactive,
                    onSelected: saving
                        ? null
                        : (_) => setState(() {
                            _status = CustomerStatus.inactive;
                            _dirty = true;
                          }),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _actions(BuildContext context, CustomerFormState state, bool saving) {
    if (state.status == CustomerFormStatus.initial ||
        state.status == CustomerFormStatus.loading ||
        (state.status == CustomerFormStatus.failure &&
            state.customer == null)) {
      return null;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_fieldError != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  customerValidationMessage(_fieldError!),
                  key: const Key('customer_form_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              key: const Key('customer_save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: saving ? null : _submit,
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Salvando cliente',
                      ),
                    )
                  : const Text('Salvar'),
            ),
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).maybePop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyCustomer(CustomerFormState state) {
    if (_filled) return;
    if (state.status != CustomerFormStatus.ready &&
        state.status != CustomerFormStatus.failure) {
      return;
    }
    final customer = state.customer;
    if (customer == null && state.customerId != null) return;
    _filled = true;
    if (customer == null) return;
    _name.text = customer.name;
    _tradeName.text = customer.tradeName ?? '';
    _document.text = customer.document ?? '';
    _email.text = customer.email ?? '';
    _phone.text = customer.phone ?? '';
    _mobile.text = customer.mobilePhone ?? '';
    _notes.text = customer.notes ?? '';
    _type = customer.type;
    _status = customer.status;
  }

  void _markDirty(String _) {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  void _submit() {
    if (_submitting) return;
    final creating = context.read<CustomerFormBloc>().state.customerId == null;
    final phoneDigits = onlyDigits(_phone.text);
    final mobileDigits = onlyDigits(_mobile.text);
    final input = CustomerInput(
      type: creating ? CustomerType.individual : _type,
      name: _name.text,
      tradeName: _tradeName.text,
      document: _document.text,
      email: _email.text,
      phone: phoneDigits.isEmpty ? null : phoneDigits,
      mobilePhone: mobileDigits.isEmpty ? null : mobileDigits,
      status: _status,
      notes: _notes.text,
    );
    final error = validateCustomerInput(input);
    if (error != null) {
      setState(() => _fieldError = error);
      return;
    }
    _submitting = true;
    setState(() => _fieldError = null);
    context.read<CustomerFormBloc>().add(CustomerFormSubmitted(input));
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Descartar alterações?'),
          content: const Text('As alterações deste cliente serão perdidas.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continuar editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Descartar'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
