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
