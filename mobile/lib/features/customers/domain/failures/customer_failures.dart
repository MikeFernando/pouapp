import '../../../../core/error/failures.dart';
import '../validation/customer_validators.dart';

class InvalidCustomerDataFailure extends Failure {
  const InvalidCustomerDataFailure(this.error);

  final CustomerValidationError error;

  @override
  List<Object?> get props => [error];
}

class CustomerNotFoundFailure extends Failure {
  const CustomerNotFoundFailure();
}

class AddressNotFoundFailure extends Failure {
  const AddressNotFoundFailure();
}

class ContactNotFoundFailure extends Failure {
  const ContactNotFoundFailure();
}

class DuplicateExternalCustomerFailure extends Failure {
  const DuplicateExternalCustomerFailure();
}
