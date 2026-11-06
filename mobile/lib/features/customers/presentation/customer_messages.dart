import '../../../core/error/failures.dart';
import '../domain/entities/customer.dart';
import '../domain/failures/customer_failures.dart';
import '../domain/validation/customer_validators.dart';

String customerValidationMessage(CustomerValidationError error) {
  return switch (error) {
    CustomerValidationError.nameRequired => 'Informe o nome.',
    CustomerValidationError.nameTooLong =>
      'O nome pode ter no máximo 120 caracteres.',
    CustomerValidationError.tradeNameTooLong =>
      'O nome fantasia pode ter no máximo 120 caracteres.',
    CustomerValidationError.invalidDocument => 'Informe um CPF ou CNPJ válido.',
    CustomerValidationError.invalidEmail => 'Informe um e-mail válido.',
    CustomerValidationError.invalidPhone =>
      'Informe um telefone com DDD e 8 ou 9 dígitos.',
    CustomerValidationError.invalidMobilePhone =>
      'Informe um celular com DDD e 9 dígitos.',
    CustomerValidationError.notesTooLong =>
      'As observações podem ter no máximo 500 caracteres.',
    CustomerValidationError.addressLabelRequired =>
      'Informe um nome para o endereço.',
    CustomerValidationError.addressStreetRequired => 'Informe a rua.',
    CustomerValidationError.addressNumberRequired => 'Informe o número.',
    CustomerValidationError.addressNeighborhoodRequired => 'Informe o bairro.',
    CustomerValidationError.addressCityRequired => 'Informe a cidade.',
    CustomerValidationError.addressStateRequired =>
      'Informe a UF com duas letras.',
    CustomerValidationError.invalidZipCode => 'Informe um CEP com 8 dígitos.',
    CustomerValidationError.contactNameRequired => 'Informe o nome do contato.',
    CustomerValidationError.contactChannelRequired =>
      'Informe um telefone ou um e-mail.',
    CustomerValidationError.contactInvalidEmail => 'Informe um e-mail válido.',
    CustomerValidationError.contactInvalidPhone =>
      'Informe um telefone com DDD.',
  };
}

String customerFailureMessage(Failure failure) {
  return switch (failure) {
    InvalidCustomerDataFailure(:final error) => customerValidationMessage(
      error,
    ),
    CustomerNotFoundFailure() => 'Cliente não encontrado.',
    AddressNotFoundFailure() => 'Endereço não encontrado.',
    ContactNotFoundFailure() => 'Contato não encontrado.',
    DuplicateExternalCustomerFailure() =>
      'Já existe um cliente com este identificador de origem.',
    CacheFailure() => 'Não foi possível acessar os clientes salvos.',
    _ => 'Não foi possível concluir a operação. Tente novamente.',
  };
}

String customerTypeLabel(CustomerType type) {
  return switch (type) {
    CustomerType.individual => 'Pessoa física',
    CustomerType.company => 'Pessoa jurídica',
  };
}

String customerStatusLabel(CustomerStatus status) {
  return switch (status) {
    CustomerStatus.active => 'Ativo',
    CustomerStatus.inactive => 'Inativo',
  };
}

String formatPhone(String? value) {
  final digits = onlyDigits(value);
  if (digits.length == 11) {
    return '(${digits.substring(0, 2)}) '
        '${digits.substring(2, 7)}-${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return '(${digits.substring(0, 2)}) '
        '${digits.substring(2, 6)}-${digits.substring(6)}';
  }
  return digits;
}

String formatDocument(String? value) {
  final digits = onlyDigits(value);
  if (digits.length == 11) {
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.'
        '${digits.substring(6, 9)}-${digits.substring(9)}';
  }
  if (digits.length == 14) {
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.'
        '${digits.substring(5, 8)}/${digits.substring(8, 12)}-'
        '${digits.substring(12)}';
  }
  return digits;
}

String primaryPhone(Customer customer) {
  final mobile = formatPhone(customer.mobilePhone);
  if (mobile.isNotEmpty) return mobile;
  return formatPhone(customer.phone);
}
