import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/auth/presentation/validation/login_validators.dart';

void main() {
  group('validateEmail', () {
    test('should require an email', () {
      expect(validateEmail(null), 'Informe o e-mail.');
      expect(validateEmail('   '), 'Informe o e-mail.');
    });

    test('should reject an invalid email', () {
      expect(validateEmail('ana'), 'Informe um e-mail válido.');
      expect(validateEmail('ana@pouapp'), 'Informe um e-mail válido.');
    });

    test('should accept a valid email', () {
      expect(validateEmail(' ana.souza@pouapp.dev '), isNull);
    });
  });

  group('validatePassword', () {
    test('should require a password', () {
      expect(validatePassword(null), 'Informe a senha.');
      expect(validatePassword(''), 'Informe a senha.');
    });

    test('should accept any non-empty password', () {
      expect(validatePassword('senha-dev'), isNull);
    });
  });
}
