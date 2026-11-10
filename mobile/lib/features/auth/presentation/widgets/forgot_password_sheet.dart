import 'package:flutter/material.dart';

import '../../../../core/config/api_config.dart';
import '../../../customers/presentation/whatsapp_launch.dart';
import '../validation/login_validators.dart';

const _sheetGreen = Color(0xFF0D6B3F);
const _fieldFill = Color(0xFFF3F4F6);
const _hintColor = Color(0xFF9CA3AF);
const _labelColor = Color(0xFF111827);

/// Collects the account e-mail and opens WhatsApp so you can reset the password.
Future<void> showForgotPasswordSheet(
  BuildContext context, {
  String initialEmail = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ForgotPasswordSheet(initialEmail: initialEmail),
  );
}

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim().toLowerCase();
    setState(() => _sending = true);

    final digits = ApiConfig.supportWhatsAppDigits.replaceAll(
      RegExp(r'\D'),
      '',
    );
    final message =
        'Olá! Esqueci a senha do PouApp.\n\n'
        'E-mail da conta: $email\n\n'
        'Pode redefinir e me enviar a nova senha, por favor?';

    final opened = await launchCustomerWhatsApp(digits, message: message);
    if (!mounted) return;
    setState(() => _sending = false);

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Pedido enviado. Assim que a senha for redefinida, use-a para entrar.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recuperar senha',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _labelColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Informe o e-mail da conta. Vamos abrir o WhatsApp para pedir a redefinição da senha.',
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'E-mail',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _labelColor,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('forgot_password_email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              enabled: !_sending,
              decoration: InputDecoration(
                hintText: 'Seu e-mail',
                hintStyle: const TextStyle(color: _hintColor),
                filled: true,
                fillColor: _fieldFill,
                prefixIcon: const Icon(
                  Icons.mail_outline_rounded,
                  color: Color(0xFF6B7280),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: validateEmail,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('forgot_password_submit'),
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Pedir nova senha no WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: _sheetGreen),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
