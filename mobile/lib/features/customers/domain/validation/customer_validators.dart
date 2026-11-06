import '../entities/customer.dart';
import '../entities/customer_address.dart';
import '../entities/customer_contact.dart';

enum CustomerValidationError {
  nameRequired,
  nameTooLong,
  tradeNameTooLong,
  invalidDocument,
  invalidEmail,
  invalidPhone,
  invalidMobilePhone,
  notesTooLong,
  addressLabelRequired,
  addressStreetRequired,
  addressNumberRequired,
  addressNeighborhoodRequired,
  addressCityRequired,
  addressStateRequired,
  invalidZipCode,
  contactNameRequired,
  contactChannelRequired,
  contactInvalidEmail,
  contactInvalidPhone,
}

const customerNameMaxLength = 120;
const customerNotesMaxLength = 500;

CustomerValidationError? validateCustomerInput(CustomerInput input) {
  return validateCustomerName(input.name) ??
      validateTradeName(input.tradeName) ??
      validateDocument(input.type, input.document) ??
      validateEmailAddress(input.email) ??
      validatePhoneNumber(input.phone) ??
      validateMobileNumber(input.mobilePhone) ??
      validateNotes(input.notes);
}

CustomerValidationError? validateCustomerName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return CustomerValidationError.nameRequired;
  if (name.length > customerNameMaxLength) {
    return CustomerValidationError.nameTooLong;
  }
  return null;
}

CustomerValidationError? validateTradeName(String? value) {
  final tradeName = value?.trim() ?? '';
  if (tradeName.length > customerNameMaxLength) {
    return CustomerValidationError.tradeNameTooLong;
  }
  return null;
}

CustomerValidationError? validateNotes(String? value) {
  final notes = value?.trim() ?? '';
  if (notes.length > customerNotesMaxLength) {
    return CustomerValidationError.notesTooLong;
  }
  return null;
}

CustomerValidationError? validateDocument(CustomerType type, String? value) {
  final digits = onlyDigits(value);
  if (digits.isEmpty) return null;
  final valid = switch (type) {
    CustomerType.individual => isValidCpf(digits),
    CustomerType.company => isValidCnpj(digits),
  };
  if (!valid) return CustomerValidationError.invalidDocument;
  return null;
}

CustomerValidationError? validateEmailAddress(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!pattern.hasMatch(email)) return CustomerValidationError.invalidEmail;
  return null;
}

CustomerValidationError? validatePhoneNumber(String? value) {
  final digits = onlyDigits(value);
  if (digits.isEmpty) return null;
  if (digits.length != 10 && digits.length != 11) {
    return CustomerValidationError.invalidPhone;
  }
  return null;
}

CustomerValidationError? validateMobileNumber(String? value) {
  final digits = onlyDigits(value);
  if (digits.isEmpty) return null;
  if (digits.length != 11) return CustomerValidationError.invalidMobilePhone;
  return null;
}

CustomerValidationError? validateAddressInput(AddressInput input) {
  if (input.label.trim().isEmpty) {
    return CustomerValidationError.addressLabelRequired;
  }
  if (input.street.trim().isEmpty) {
    return CustomerValidationError.addressStreetRequired;
  }
  if (input.number.trim().isEmpty) {
    return CustomerValidationError.addressNumberRequired;
  }
  if (input.neighborhood.trim().isEmpty) {
    return CustomerValidationError.addressNeighborhoodRequired;
  }
  if (input.city.trim().isEmpty) {
    return CustomerValidationError.addressCityRequired;
  }
  if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(input.state.trim())) {
    return CustomerValidationError.addressStateRequired;
  }
  final zip = onlyDigits(input.zipCode);
  if (zip.isNotEmpty && zip.length != 8) {
    return CustomerValidationError.invalidZipCode;
  }
  return null;
}

CustomerValidationError? validateContactInput(ContactInput input) {
  if (input.name.trim().isEmpty) {
    return CustomerValidationError.contactNameRequired;
  }
  final phone = onlyDigits(input.phone);
  final email = input.email?.trim() ?? '';
  if (phone.isEmpty && email.isEmpty) {
    return CustomerValidationError.contactChannelRequired;
  }
  if (phone.isNotEmpty && phone.length != 10 && phone.length != 11) {
    return CustomerValidationError.contactInvalidPhone;
  }
  if (email.isNotEmpty && validateEmailAddress(email) != null) {
    return CustomerValidationError.contactInvalidEmail;
  }
  return null;
}

String onlyDigits(String? value) {
  return (value ?? '').replaceAll(RegExp(r'\D'), '');
}

bool isValidCpf(String value) {
  final digits = onlyDigits(value);
  if (digits.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;
  final numbers = digits.split('').map(int.parse).toList();
  return _checkDigit(numbers, 9) == numbers[9] &&
      _checkDigit(numbers, 10) == numbers[10];
}

bool isValidCnpj(String value) {
  final digits = onlyDigits(value);
  if (digits.length != 14) return false;
  if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) return false;
  final numbers = digits.split('').map(int.parse).toList();
  const firstWeights = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const secondWeights = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  return _weightedDigit(numbers, firstWeights) == numbers[12] &&
      _weightedDigit(numbers, secondWeights) == numbers[13];
}

int _checkDigit(List<int> numbers, int length) {
  var sum = 0;
  for (var index = 0; index < length; index++) {
    sum += numbers[index] * (length + 1 - index);
  }
  final mod = sum % 11;
  return mod < 2 ? 0 : 11 - mod;
}

int _weightedDigit(List<int> numbers, List<int> weights) {
  var sum = 0;
  for (var index = 0; index < weights.length; index++) {
    sum += numbers[index] * weights[index];
  }
  final mod = sum % 11;
  return mod < 2 ? 0 : 11 - mod;
}

List<CustomerAddress> withSinglePrimaryAddress(
  List<CustomerAddress> addresses,
  String primaryId,
) {
  return [
    for (final address in addresses)
      address.copyWith(isPrimary: address.id == primaryId),
  ];
}
