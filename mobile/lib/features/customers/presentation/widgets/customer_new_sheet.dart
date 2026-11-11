import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/entities/customer.dart';
import '../../domain/validation/customer_validators.dart';
import '../bloc/customer_form_bloc.dart';
import '../customer_messages.dart';

Future<bool?> showNewCustomerSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => BlocProvider(
      create: (_) =>
          di.sl<CustomerFormBloc>()..add(const CustomerFormStarted()),
      child: const NewCustomerSheet(),
    ),
  );
}

class NewCustomerSheet extends StatefulWidget {
  const NewCustomerSheet({super.key});

  @override
  State<NewCustomerSheet> createState() => _NewCustomerSheetState();
}

class _NewCustomerSheetState extends State<NewCustomerSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  var _submitting = false;
  CustomerValidationError? _fieldError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return BlocConsumer<CustomerFormBloc, CustomerFormState>(
      listenWhen: (previous, current) =>
          previous.messageToken != current.messageToken ||
          previous.status != current.status,
      listener: (context, state) {
        if (state.message != null) {
          _submitting = false;
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
        if (state.saved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop(true);
          });
        }
      },
      builder: (context, state) {
        final saving =
            _submitting || state.status == CustomerFormStatus.saving;
        return MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E7EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Novo cliente',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: pouInk,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('customer_name'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    enabled: !saving,
                    decoration: _fieldDecoration('Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('customer_phone'),
                    controller: _phone,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.phone,
                    enabled: !saving,
                    inputFormatters: const [_PhoneInputFormatter()],
                    onSubmitted: (_) => saving ? null : _submit(),
                    decoration: _fieldDecoration('Telefone (opcional)'),
                  ),
                  if (_fieldError != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        customerValidationMessage(_fieldError!),
                        key: const Key('customer_form_error'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      key: const Key('customer_save'),
                      onPressed: saving ? null : _submit,
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                                semanticsLabel: 'Salvando cliente',
                              ),
                            )
                          : const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit() {
    if (_submitting) return;
    final phoneDigits = onlyDigits(_phone.text);
    final input = CustomerInput(
      type: CustomerType.individual,
      name: _name.text,
      phone: phoneDigits.isEmpty ? null : phoneDigits,
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
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF6F5F7),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
  );
}

class _PhoneInputFormatter extends TextInputFormatter {
  const _PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatPhoneMask(onlyDigits(newValue.text));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatPhoneMask(String digits) {
  final d = digits.length > 11 ? digits.substring(0, 11) : digits;
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';
  final ddd = d.substring(0, 2);
  final rest = d.substring(2);
  if (d.length <= 6) return '($ddd) $rest';
  if (d.length <= 10) {
    return '($ddd) ${rest.substring(0, 4)}-${rest.substring(4)}';
  }
  return '($ddd) ${rest.substring(0, 5)}-${rest.substring(5)}';
}
