import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../customers/domain/validation/customer_validators.dart';
import '../../data/receivable_store.dart';
import '../../domain/entities/receivable.dart';
import '../../domain/rules/receivable_rules.dart';

const _fieldFill = Color(0xFFF2F2F4);
const _muted = Color(0xFF8E8E93);

Future<bool> showBusinessSettingsSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => const BusinessSettingsPage(),
  );
  return result == true;
}

class BusinessSettingsPage extends StatefulWidget {
  const BusinessSettingsPage({super.key});

  @override
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
  final _key = TextEditingController();
  final _name = TextEditingController();
  PixKeyType _type = PixKeyType.phone;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await sl<ReceivableStore>().readProfile();
    if (!mounted) return;
    final type = profile.pixKeyType ?? PixKeyType.phone;
    setState(() {
      _loading = false;
      _type = type;
      _key.text = _displayPixKey(type, profile.pixKey ?? '');
      _name.text = profile.receiverName ?? '';
    });
  }

  void _onTypeChanged(PixKeyType type) {
    final current = _key.text;
    setState(() {
      _type = type;
      _key.text = _displayPixKey(type, current);
      _error = null;
    });
  }

  List<TextInputFormatter> get _keyFormatters {
    return switch (_type) {
      PixKeyType.phone => const [_PixPhoneFormatter()],
      PixKeyType.cpfCnpj => const [_PixCpfCnpjFormatter()],
      PixKeyType.email => const [_PixEmailFormatter()],
      PixKeyType.random => const [],
    };
  }

  TextInputType get _keyKeyboard {
    return switch (_type) {
      PixKeyType.phone || PixKeyType.cpfCnpj => TextInputType.number,
      PixKeyType.email => TextInputType.emailAddress,
      PixKeyType.random => TextInputType.text,
    };
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: _muted,
      ),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: pouAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 16, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Configurações',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: pouInk,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    Material(
                      color: _fieldFill,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).pop(false),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: pouInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + safeBottom),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _fieldFill,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'A cobrança envia esta chave. Ela não gera QR Code nem código Pix Copia e Cola.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Tipo de chave',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<PixKeyType>(
                        key: const Key('pix_key_type'),
                        initialValue: _type,
                        decoration: _fieldDecoration(hint: 'Selecione'),
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: pouInk,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF6B7280),
                        ),
                        items: [
                          for (final type in PixKeyType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(pixKeyTypeLabel(type)),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                _onTypeChanged(value);
                              },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Chave Pix',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: Key('pix_key_value_${_type.name}'),
                        controller: _key,
                        enabled: !_saving,
                        keyboardType: _keyKeyboard,
                        inputFormatters: _keyFormatters,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: pouInk,
                        ),
                        decoration: _fieldDecoration(
                          hint: _typeHint(_type),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Nome do recebedor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('pix_receiver_name'),
                        controller: _name,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: pouInk,
                        ),
                        decoration: _fieldDecoration(
                          hint: 'Como aparece no Pix',
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            key: const Key('pix_settings_error'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFB42318),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('pix_settings_save'),
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: pouInk,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFD1D1D6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(_saving ? 'Salvando…' : 'Salvar chave'),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Divider(height: 1, color: Color(0xFFE9E8EB)),
                      const SizedBox(height: 16),
                      const Text(
                        'Conta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 10),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final loggingOut = state is AuthLogoutInProgress;
                          return SizedBox(
                            height: 54,
                            width: double.infinity,
                            child: OutlinedButton(
                              key: const Key('logout_button'),
                              onPressed: loggingOut || _saving
                                  ? null
                                  : () => _logout(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB42318),
                                side: const BorderSide(
                                  color: Color(0xFFF2C7C3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: loggingOut
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFB42318),
                                        semanticsLabel: 'Saindo',
                                      ),
                                    )
                                  : const Text('Sair da conta'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.of(context).pop(false);
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  String _typeHint(PixKeyType type) {
    return switch (type) {
      PixKeyType.phone => 'Telefone com DDD',
      PixKeyType.email => 'E-mail',
      PixKeyType.cpfCnpj => 'CPF ou CNPJ',
      PixKeyType.random => 'Chave aleatória',
    };
  }

  Future<void> _save() async {
    final profile = BusinessProfile(
      pixKeyType: _type,
      pixKey: _normalizedPixKey(_type, _key.text),
      receiverName: _name.text.trim(),
    );
    final problem = pixProfileProblem(profile);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await sl<ReceivableStore>().saveProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReceivableException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }
}

String _displayPixKey(PixKeyType type, String raw) {
  return switch (type) {
    PixKeyType.phone => _formatPhoneMask(onlyDigits(raw)),
    PixKeyType.cpfCnpj => _formatCpfCnpjMask(onlyDigits(raw)),
    PixKeyType.email => raw.trim().replaceAll(' ', '').toLowerCase(),
    PixKeyType.random => raw.trim(),
  };
}

String _normalizedPixKey(PixKeyType type, String raw) {
  return switch (type) {
    PixKeyType.phone || PixKeyType.cpfCnpj => onlyDigits(raw),
    PixKeyType.email => raw.trim().replaceAll(' ', '').toLowerCase(),
    PixKeyType.random => raw.trim(),
  };
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

String _formatCpfCnpjMask(String digits) {
  final d = digits.length > 14 ? digits.substring(0, 14) : digits;
  if (d.isEmpty) return '';
  if (d.length <= 11) {
    if (d.length <= 3) return d;
    if (d.length <= 6) return '${d.substring(0, 3)}.${d.substring(3)}';
    if (d.length <= 9) {
      return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6)}';
    }
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.'
        '${d.substring(6, 9)}-${d.substring(9)}';
  }
  if (d.length <= 12) {
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.'
        '${d.substring(5, 8)}/${d.substring(8)}';
  }
  return '${d.substring(0, 2)}.${d.substring(2, 5)}.'
      '${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
}

class _PixPhoneFormatter extends TextInputFormatter {
  const _PixPhoneFormatter();

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

class _PixCpfCnpjFormatter extends TextInputFormatter {
  const _PixCpfCnpjFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatCpfCnpjMask(onlyDigits(newValue.text));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _PixEmailFormatter extends TextInputFormatter {
  const _PixEmailFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = newValue.text.replaceAll(' ', '').toLowerCase();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
