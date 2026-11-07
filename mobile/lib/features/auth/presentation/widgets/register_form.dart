import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../validation/login_validators.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final isSubmitting = state is AuthRegisterInProgress;
    final errorMessage = state is AuthRegisterFailure ? state.message : null;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'PouApp',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Criar conta',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          key: const Key('register_name'),
                          controller: _nameController,
                          focusNode: _nameFocus,
                          enabled: !isSubmitting,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            border: OutlineInputBorder(),
                          ),
                          validator: validateName,
                          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                        ),
                        const SizedBox(height: 16),
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
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            border: OutlineInputBorder(),
                          ),
                          validator: validateEmail,
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: 16),
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
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              key: const Key('register_toggle_password'),
                              tooltip: _obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: validateNewPassword,
                          onFieldSubmitted: (_) =>
                              _confirmationFocus.requestFocus(),
                        ),
                        const SizedBox(height: 16),
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
                          decoration: InputDecoration(
                            labelText: 'Confirmar senha',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              key: const Key('register_toggle_confirmation'),
                              tooltip: _obscureConfirmation
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscureConfirmation =
                                            !_obscureConfirmation;
                                      });
                                    },
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility
                                    : Icons.visibility_off,
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
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              errorMessage,
                              key: const Key('register_error'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('register_submit'),
                          style: pouAppPrimaryButtonStyle(),
                          onPressed: isSubmitting ? null : _submit,
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
                              : const Text('Criar conta'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          key: const Key('back_to_login'),
                          onPressed: isSubmitting ? null : widget.onSignIn,
                          style: TextButton.styleFrom(
                            foregroundColor: pouAppBlue,
                          ),
                          child: const Text('Já tenho uma conta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
