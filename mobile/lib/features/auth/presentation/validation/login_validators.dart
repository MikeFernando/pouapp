final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Informe o e-mail.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Informe a senha.';
  }
  return null;
}

String? validateName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Informe o nome.';
  }
  return null;
}

String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Informe a senha.';
  }
  if (value.length < 6) {
    return 'A senha deve ter pelo menos 6 caracteres.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Confirme a senha.';
  }
  if (value != password) {
    return 'As senhas não coincidem.';
  }
  return null;
}
