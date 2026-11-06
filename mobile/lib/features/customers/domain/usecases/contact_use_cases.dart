import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/customer_contact.dart';
import '../failures/customer_failures.dart';
import '../repositories/customer_repository.dart';
import '../validation/customer_validators.dart';

class GetCustomerContacts implements UseCase<List<CustomerContact>, String> {
  GetCustomerContacts(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, List<CustomerContact>>> call(String params) {
    return repository.getContacts(params);
  }
}

class AddCustomerContact implements UseCase<CustomerContact, ContactInput> {
  AddCustomerContact(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, CustomerContact>> call(ContactInput params) {
    final error = validateContactInput(params);
    if (error != null) {
      return Future.value(Left(InvalidCustomerDataFailure(error)));
    }
    return repository.addContact(params);
  }
}

class UpdateCustomerContact
    implements UseCase<CustomerContact, UpdateContactParams> {
  UpdateCustomerContact(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, CustomerContact>> call(UpdateContactParams params) {
    final error = validateContactInput(params.input);
    if (error != null) {
      return Future.value(Left(InvalidCustomerDataFailure(error)));
    }
    return repository.updateContact(id: params.id, input: params.input);
  }
}

class UpdateContactParams {
  const UpdateContactParams({required this.id, required this.input});

  final String id;
  final ContactInput input;
}

class DeleteCustomerContact implements UseCase<Unit, DeleteContactParams> {
  DeleteCustomerContact(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, Unit>> call(DeleteContactParams params) {
    return repository.deleteContact(
      customerId: params.customerId,
      contactId: params.contactId,
    );
  }
}

class DeleteContactParams {
  const DeleteContactParams({
    required this.customerId,
    required this.contactId,
  });

  final String customerId;
  final String contactId;
}
