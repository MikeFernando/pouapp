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

  group('validateName', () {
    test('should require a name', () {
      expect(validateName(null), 'Informe o nome.');
      expect(validateName('   '), 'Informe o nome.');
    });

    test('should accept a name', () {
      expect(validateName(' Ana Souza '), isNull);
    });
  });

  group('validateNewPassword', () {
    test('should require 8+ chars with letter and number', () {
      expect(validateNewPassword(null), 'Informe a senha.');
      expect(validateNewPassword(''), 'Informe a senha.');
      expect(
        validateNewPassword('1234567'),
        'A senha deve ter pelo menos 8 caracteres.',
      );
      expect(
        validateNewPassword('12345678'),
        'A senha deve ter letra e número.',
      );
      expect(
        validateNewPassword('abcdefgh'),
        'A senha deve ter letra e número.',
      );
      expect(validateNewPassword('Edipo123'), isNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('should require the same password', () {
      expect(validatePasswordConfirmation(null, '123456'), 'Confirme a senha.');
      expect(validatePasswordConfirmation('', '123456'), 'Confirme a senha.');
      expect(
        validatePasswordConfirmation('1234567', '123456'),
        'As senhas não coincidem.',
      );
      expect(validatePasswordConfirmation('123456', '123456'), isNull);
    });
  });
}
