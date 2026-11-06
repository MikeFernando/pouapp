import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/customer_address.dart';
import '../failures/customer_failures.dart';
import '../repositories/customer_repository.dart';
import '../validation/customer_validators.dart';

class GetCustomerAddresses implements UseCase<List<CustomerAddress>, String> {
  GetCustomerAddresses(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, List<CustomerAddress>>> call(String params) {
    return repository.getAddresses(params);
  }
}

class AddCustomerAddress implements UseCase<CustomerAddress, AddressInput> {
  AddCustomerAddress(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, CustomerAddress>> call(AddressInput params) {
    final error = validateAddressInput(params);
    if (error != null) {
      return Future.value(Left(InvalidCustomerDataFailure(error)));
    }
    return repository.addAddress(params);
  }
}

class UpdateCustomerAddress
    implements UseCase<CustomerAddress, UpdateAddressParams> {
  UpdateCustomerAddress(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, CustomerAddress>> call(UpdateAddressParams params) {
    final error = validateAddressInput(params.input);
    if (error != null) {
      return Future.value(Left(InvalidCustomerDataFailure(error)));
    }
    return repository.updateAddress(id: params.id, input: params.input);
  }
}

class UpdateAddressParams {
  const UpdateAddressParams({required this.id, required this.input});

  final String id;
  final AddressInput input;
}

class DeleteCustomerAddress implements UseCase<Unit, DeleteAddressParams> {
  DeleteCustomerAddress(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, Unit>> call(DeleteAddressParams params) {
    return repository.deleteAddress(
      customerId: params.customerId,
      addressId: params.addressId,
    );
  }
}

class DeleteAddressParams {
  const DeleteAddressParams({
    required this.customerId,
    required this.addressId,
  });

  final String customerId;
  final String addressId;
}

class SetPrimaryCustomerAddress
    implements UseCase<Unit, SetPrimaryAddressParams> {
  SetPrimaryCustomerAddress(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, Unit>> call(SetPrimaryAddressParams params) {
    return repository.setPrimaryAddress(
      customerId: params.customerId,
      addressId: params.addressId,
    );
  }
}

class SetPrimaryAddressParams {
  const SetPrimaryAddressParams({
    required this.customerId,
    required this.addressId,
  });

  final String customerId;
  final String addressId;
}
