import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../validation/login_validators.dart';
import 'forgot_password_sheet.dart';

const _sheetGreen = Color(0xFF0D6B3F);
const _fieldFill = Color(0xFFF3F4F6);
const _hintColor = Color(0xFF9CA3AF);
const _subtitleColor = Color(0xFF6B7280);
const _labelColor = Color(0xFF111827);

/// Opens login/register in a modal over the welcome screen.
Future<void> showLoginSheet(BuildContext context) {
  final authBloc = context.read<AuthBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider.value(
      value: authBloc,
      child: const LoginSheet(),
    ),
  );
}

class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  var _creatingAccount = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final baseHeight =
        media.size.height * (_creatingAccount ? 0.72 : 0.58);
    final sheetHeight =
        (baseHeight + keyboard).clamp(baseHeight, media.size.height * 0.94);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is Authenticated && previous is! Authenticated,
      listener: (context, state) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Expanded(
              child: _creatingAccount
                  ? _RegisterSheetForm(
                      onSignIn: () =>
                          setState(() => _creatingAccount = false),
                    )
                  : _LoginSheetForm(
                      onCreateAccount: () =>
                          setState(() => _creatingAccount = true),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _sheetFieldDecoration({
  required String hint,
  IconData? prefix,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: _hintColor,
      fontWeight: FontWeight.w400,
      fontSize: 15,
    ),
    filled: true,
    fillColor: _fieldFill,
    prefixIcon: prefix == null
        ? null
        : Icon(prefix, color: const Color(0xFF6B7280), size: 22),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.black, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFC62828)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.4),
    ),
  );
}

ButtonStyle get _blackPillButtonStyle => FilledButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.black.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );

class _LoginSheetForm extends StatefulWidget {
  const _LoginSheetForm({required this.onCreateAccount});

  final VoidCallback onCreateAccount;

  @override
  State<_LoginSheetForm> createState() => _LoginSheetFormState();
}

class _LoginSheetFormState extends State<_LoginSheetForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  var _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    context.read<AuthBloc>().add(
      AuthLoginSubmitted(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final isSubmitting = state is AuthLoginInProgress;
    final errorMessage = state is AuthFailure ? state.message : null;

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bem-vindo de volta',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: pouInk,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Entre para continuar sua gestão.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _subtitleColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      minimumSize: const Size(40, 40),
                    ),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 22),
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
                key: const Key('login_email'),
                controller: _emailController,
                focusNode: _emailFocus,
                enabled: !isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                decoration: _sheetFieldDecoration(
                  hint: 'Seu e-mail',
                  prefix: Icons.mail_outline_rounded,
                ),
                validator: validateEmail,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Senha',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _labelColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('login_password'),
                controller: _passwordController,
                focusNode: _passwordFocus,
                enabled: !isSubmitting,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                decoration: _sheetFieldDecoration(
                  hint: 'Sua senha',
                  prefix: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    key: const Key('toggle_password'),
                    tooltip:
                        _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                    onPressed: isSubmitting
                        ? null
                        : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
                validator: validatePassword,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('forgot_password'),
                  onPressed: isSubmitting
                      ? null
                      : () {
                          showForgotPasswordSheet(
                            context,
                            initialEmail: _emailController.text,
                          );
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: _sheetGreen,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Esqueceu a senha?'),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    errorMessage,
                    key: const Key('login_error'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton(
                  key: const Key('login_submit'),
                  onPressed: isSubmitting ? null : _submit,
                  style: _blackPillButtonStyle,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                            semanticsLabel: 'Entrando',
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Entrar'),
                            SizedBox(width: 8),
                            Text('→', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Ainda não tem conta? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: _subtitleColor,
                      ),
                    ),
                    TextButton(
                      key: const Key('create_account'),
                      onPressed:
                          isSubmitting ? null : widget.onCreateAccount,
                      style: TextButton.styleFrom(
                        foregroundColor: _sheetGreen,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Criar conta'),
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
}

class _RegisterSheetForm extends StatefulWidget {
  const _RegisterSheetForm({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  State<_RegisterSheetForm> createState() => _RegisterSheetFormState();
}

class _RegisterSheetFormState extends State<_RegisterSheetForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();
  var _obscurePassword = true;
  var _obscureConfirmation = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmationFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    context.read<AuthBloc>().add(
      AuthRegisterSubmitted(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  String? _validateSheetPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe a senha.';
    }
    if (value.length < 8) {
      return 'Use pelo menos 8 caracteres.';
    }
    return null;
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _labelColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final isSubmitting = state is AuthRegisterInProgress;
    final errorMessage = state is AuthRegisterFailure ? state.message : null;

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crie sua conta',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: pouInk,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Comece a organizar seu negócio.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _subtitleColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      minimumSize: const Size(40, 40),
                    ),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _fieldLabel('Nome e sobrenome'),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('register_name'),
                controller: _nameController,
                focusNode: _nameFocus,
                enabled: !isSubmitting,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: _sheetFieldDecoration(
                  hint: 'Seu nome e sobrenome',
                  prefix: Icons.person_outline_rounded,
                ),
                validator: validateName,
                onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              const SizedBox(height: 14),
              _fieldLabel('E-mail'),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('register_email'),
                controller: _emailController,
                focusNode: _emailFocus,
                enabled: !isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                decoration: _sheetFieldDecoration(
                  hint: 'Seu e-mail',
                  prefix: Icons.mail_outline_rounded,
                ),
                validator: validateEmail,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 14),
              _fieldLabel('Senha'),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('register_password'),
                controller: _passwordController,
                focusNode: _passwordFocus,
                enabled: !isSubmitting,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _sheetFieldDecoration(
                  hint: 'Crie uma senha',
                  prefix: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    key: const Key('register_toggle_password'),
                    tooltip:
                        _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                    onPressed: isSubmitting
                        ? null
                        : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
                validator: _validateSheetPassword,
                onFieldSubmitted: (_) => _confirmationFocus.requestFocus(),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use pelo menos 8 caracteres.',
                style: TextStyle(
                  fontSize: 12,
                  color: _subtitleColor,
                ),
              ),
              const SizedBox(height: 14),
              _fieldLabel('Confirmar senha'),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('register_password_confirmation'),
                controller: _confirmationController,
                focusNode: _confirmationFocus,
                enabled: !isSubmitting,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _sheetFieldDecoration(
                  hint: 'Repita sua senha',
                  prefix: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    key: const Key('register_toggle_confirmation'),
                    tooltip: _obscureConfirmation
                        ? 'Mostrar senha'
                        : 'Ocultar senha',
                    onPressed: isSubmitting
                        ? null
                        : () => setState(
                              () =>
                                  _obscureConfirmation = !_obscureConfirmation,
                            ),
                    icon: Icon(
                      _obscureConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
                validator: (value) => validatePasswordConfirmation(
                  value,
                  _passwordController.text,
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    errorMessage,
                    key: const Key('register_error'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton(
                  key: const Key('register_submit'),
                  onPressed: isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.black.withValues(alpha: 0.45),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                            semanticsLabel: 'Criando conta',
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Criar conta'),
                            SizedBox(width: 8),
                            Text('→', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Já tem uma conta? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: _subtitleColor,
                      ),
                    ),
                    TextButton(
                      key: const Key('back_to_login'),
                      onPressed: isSubmitting ? null : widget.onSignIn,
                      style: TextButton.styleFrom(
                        foregroundColor: _sheetGreen,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Entrar'),
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
}
