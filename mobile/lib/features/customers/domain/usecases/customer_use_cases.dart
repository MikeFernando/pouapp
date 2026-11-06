import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/customer.dart';
import '../failures/customer_failures.dart';
import '../repositories/customer_repository.dart';
import '../validation/customer_validators.dart';

class GetCustomers implements UseCase<CustomerPage, CustomerQuery> {
  GetCustomers(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, CustomerPage>> call(CustomerQuery params) {
    final pageSize = params.pageSize <= 0 ? 20 : params.pageSize;
    final page = params.page < 0 ? 0 : params.page;
    return repository.getCustomers(
      CustomerQuery(
        search: params.search.trim(),
        status: params.status,
        page: page,
        pageSize: pageSize > 100 ? 100 : pageSize,
      ),
    );
  }
}

class GetCustomerById implements UseCase<Customer, String> {
  GetCustomerById(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, Customer>> call(String params) {
    return repository.getCustomerById(params);
  }
}

class CreateCustomer implements UseCase<Customer, CustomerInput> {
  CreateCustomer(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, Customer>> call(CustomerInput params) {
    final error = validateCustomerInput(params);
    if (error != null) {
      return Future.value(Left(InvalidCustomerDataFailure(error)));
    }
    return repository.createCustomer(params);
  }
}

class UpdateCustomer implements UseCase<Customer, UpdateCustomerParams> {
  UpdateCustomer(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, Customer>> call(UpdateCustomerParams params) {
    final error = validateCustomerInput(params.input);
    if (error != null) {
      return Future.value(Left(InvalidCustomerDataFailure(error)));
    }
    return repository.updateCustomer(id: params.id, input: params.input);
  }
}

class UpdateCustomerParams {
  const UpdateCustomerParams({required this.id, required this.input});

  final String id;
  final CustomerInput input;
}

class ChangeCustomerStatus
    implements UseCase<Customer, ChangeCustomerStatusParams> {
  ChangeCustomerStatus(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, Customer>> call(ChangeCustomerStatusParams params) {
    return repository.changeStatus(id: params.id, status: params.status);
  }
}

class ChangeCustomerStatusParams {
  const ChangeCustomerStatusParams({required this.id, required this.status});

  final String id;
  final CustomerStatus status;
}
